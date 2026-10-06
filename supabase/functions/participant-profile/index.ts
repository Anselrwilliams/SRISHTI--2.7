import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getServiceKey(): string | null {
  const legacyKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacyKey) return legacyKey;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}") as Record<string, string>;
    return Object.values(keys).find((value) => typeof value === "string") ?? null;
  } catch {
    return null;
  }
}

function getOtpSalt(): string {
  return Deno.env.get("OTP_SALT") || "srishti27_secure_salt";
}

function getMailerSecret(): string {
  return Deno.env.get("SRISHTI_MAILER_SECRET") || "";
}

function getClientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) return forwarded.split(",")[0].trim();
  return req.headers.get("x-real-ip") || req.headers.get("cf-connecting-ip") || "unknown";
}

async function hashOtp(email: string, code: string): Promise<string> {
  const salt = getOtpSalt();
  const encoder = new TextEncoder();
  const data = encoder.encode(`${email.toLowerCase()}:${code.trim()}:${salt}`);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
}

async function dispatchEmail(to: string, subject: string, html: string, image?: string): Promise<{ ok: boolean; status: number; error?: string }> {
  const secret = getMailerSecret();
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (secret) {
    headers["Authorization"] = `Bearer ${secret}`;
    headers["X-Mailer-Secret"] = secret;
  }
  try {
    const res = await fetch("https://srishti2-7.vercel.app/api/send_email", {
      method: "POST",
      headers,
      body: JSON.stringify({ to, subject, html, image })
    });
    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      console.error("Vercel mailer error:", res.status, errText);
      return { ok: false, status: res.status, error: errText };
    }
    return { ok: true, status: res.status };
  } catch (err) {
    console.error("Vercel mailer network exception:", err);
    return { ok: false, status: 502, error: String(err) };
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "Method not allowed." }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = getServiceKey();
    if (!supabaseUrl || !serviceKey) {
      return json({ success: false, error: "Server configuration error." }, 500);
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch {
      return json({ success: false, error: "Invalid JSON request body." }, 400);
    }

    const action = body?.action;

    // -------------------------------------------------------------------------
    // ACTION: send-otp (Server-Side 6-Digit Numeric OTP Generation & Dispatch)
    // -------------------------------------------------------------------------
    if (action === "send-otp" || action === "prepare-otp") {
      const targetEmail = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!targetEmail || !emailRegex.test(targetEmail)) {
        return json({ success: false, error: "Please enter a valid email address." }, 400);
      }

      // 1. IP Abuse Protection (Rate limit across different emails from the same IP)
      const clientIp = getClientIp(req);
      if (clientIp !== "unknown") {
        const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
        const { count, error: countErr } = await admin
          .from("audit_logs")
          .select("id", { count: "exact", head: true })
          .eq("client_ip", clientIp)
          .eq("action", "OTP_REQUEST")
          .gte("created_at", tenMinutesAgo);

        if (!countErr && count && count >= 15) {
          return json({
            success: false,
            error: "Too many verification requests from your network. Please wait a few minutes before trying again."
          }, 429);
        }
      }

      // 2. Verify email belongs to an existing participant
      const { data: pMatch, error: pError } = await admin
        .from("participants")
        .select("id, participant_code, name, email")
        .ilike("email", targetEmail.replace(/[\\%_]/g, "\\$&"))
        .maybeSingle();

      if (pError) {
        console.error("Participant pre-check error:", pError);
        return json({ success: false, error: "Error verifying participant registration." }, 500);
      }

      // Safe Generic Response to prevent participant email enumeration
      if (!pMatch) {
        return json({
          success: true,
          message: "If this email is registered, a 6-digit verification code has been sent."
        });
      }

      // 3. Ensure auth account exists so Supabase Auth can establish sessions
      try {
        await admin.auth.admin.createUser({
          email: targetEmail,
          email_confirm: true,
          user_metadata: { name: pMatch.name }
        });
      } catch (_) {
        // User already exists in auth.users
      }

      // 4. Rate-limiting & Resend Cooldown Check per target email (60 seconds)
      const { data: existingOtp } = await admin
        .from("participant_otps")
        .select("last_sent_at, attempts")
        .eq("email", targetEmail)
        .maybeSingle();

      if (existingOtp?.last_sent_at) {
        const lastSent = new Date(existingOtp.last_sent_at).getTime();
        const diffSeconds = (Date.now() - lastSent) / 1000;
        if (diffSeconds < 60) {
          const waitTime = Math.ceil(60 - diffSeconds);
          return json({
            success: false,
            error: `Please wait ${waitTime} seconds before requesting another code.`,
            cooldown_remaining: waitTime
          }, 429);
        }
      }

      // 5. Generate Cryptographically Secure 6-digit numeric OTP
      const cryptoArray = new Uint32Array(1);
      crypto.getRandomValues(cryptoArray);
      const otpCode = String((cryptoArray[0] % 900000) + 100000); // 100000 - 999999

      // 6. Store ONLY SHA-256 Hash with salt in database (Never plaintext)
      const otpHash = await hashOtp(targetEmail, otpCode);
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

      const { error: upsertError } = await admin
        .from("participant_otps")
        .upsert({
          email: targetEmail,
          otp_hash: otpHash,
          attempts: 0,
          expires_at: expiresAt,
          last_sent_at: new Date().toISOString()
        });

      if (upsertError) {
        console.error("Error storing OTP hash:", upsertError);
        return json({ success: false, error: "Could not issue verification code. Please try again." }, 500);
      }

      // 7. Record IP in audit_logs for flood protection tracking
      try {
        await admin.from("audit_logs").insert({
          action: "OTP_REQUEST",
          status: "SUCCESS",
          user_email: targetEmail,
          client_ip: clientIp,
          metadata: { timestamp: new Date().toISOString() }
        });
      } catch (auditErr) {
        console.warn("Audit log insert notice:", auditErr);
      }

      // 8. Send Branded Email with Numeric OTP prominently displayed
      const emailHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SRISHTI 2.7 Verification Code</title>
</head>
<body style="margin: 0; padding: 0; background-color: #050508; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #ffffff;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #050508; padding: 40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 520px; background-color: #0c0d14; border: 1px solid #1e2238; border-radius: 20px; padding: 36px 28px; box-shadow: 0 20px 40px rgba(0,0,0,0.6);">
          <tr>
            <td align="center" style="padding-bottom: 24px;">
              <div style="font-size: 28px; font-weight: 900; letter-spacing: 4px; color: #ffffff; text-transform: uppercase;">
                SRISHTI <span style="color: #00f2fe;">2.7</span>
              </div>
              <div style="font-size: 11px; letter-spacing: 2.5px; color: #64748b; text-transform: uppercase; margin-top: 6px;">
                National Level Tech Fest • Participant Verification
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding: 24px 0; border-top: 1px solid #1a1e30; border-bottom: 1px solid #1a1e30; text-align: center;">
              <p style="margin: 0 0 12px 0; font-size: 15px; color: #94a3b8;">
                Your one-time verification code is:
              </p>
              <div style="background-color: #050508; border: 2px solid #00f2fe; border-radius: 14px; padding: 18px 24px; margin: 16px auto; display: inline-block;">
                <span style="font-size: 38px; font-weight: 900; letter-spacing: 10px; color: #00f2fe; font-family: 'Courier New', Courier, monospace; display: inline-block;">
                  ${otpCode}
                </span>
              </div>
              <p style="margin: 14px 0 0 0; font-size: 13px; color: #64748b; line-height: 1.5;">
                This code is valid for 10 minutes. Enter this numeric code on the website to access your FEST profile and digital entry pass.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-top: 24px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #475569;">
                Do not share this code with anyone. If you did not request this verification code, please ignore this email.
              </p>
              <p style="margin: 8px 0 0 0; font-size: 11px; color: #334155;">
                &copy; 2026 SRISHTI 2.7 • St. Thomas College (Autonomous), Thrissur
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

      const mailResult = await dispatchEmail(
        targetEmail,
        `SRISHTI 2.7 — Your Verification Code: ${otpCode}`,
        emailHtml
      );

      if (!mailResult.ok) {
        return json({ success: false, error: "Could not send verification email. Please try again later." }, 502);
      }

      return json({
        success: true,
        message: "If this email is registered, a 6-digit verification code has been sent."
      });
    }

    // -------------------------------------------------------------------------
    // ACTION: verify-otp (Verify 6-digit numeric OTP and issue auth tokens)
    // -------------------------------------------------------------------------
    if (action === "verify-otp") {
      const targetEmail = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
      const otpInput = typeof body?.otp === "string" ? body.otp.trim() : "";

      if (!targetEmail || !otpInput || otpInput.length !== 6) {
        return json({ success: false, error: "Please enter the complete 6-digit verification code." }, 400);
      }

      // 1. Fetch OTP record from database
      const { data: otpRecord, error: otpFetchErr } = await admin
        .from("participant_otps")
        .select("*")
        .eq("email", targetEmail)
        .maybeSingle();

      if (otpFetchErr || !otpRecord) {
        return json({ success: false, error: "No active verification code found. Please tap Send OTP." }, 404);
      }

      // 2. Check maximum verification attempts (Brute-force protection)
      if (otpRecord.attempts >= 5) {
        await admin.from("participant_otps").delete().eq("email", targetEmail);
        return json({ success: false, error: "Too many failed attempts. Please request a new verification code." }, 429);
      }

      // 3. Check expiration (10 minutes)
      const expiresAt = new Date(otpRecord.expires_at).getTime();
      if (Date.now() > expiresAt) {
        await admin.from("participant_otps").delete().eq("email", targetEmail);
        return json({ success: false, error: "Verification code has expired. Please tap Resend OTP." }, 400);
      }

      // 4. Verify cryptographic hash
      const inputHash = await hashOtp(targetEmail, otpInput);
      if (inputHash !== otpRecord.otp_hash) {
        // Increment attempts on incorrect code
        await admin
          .from("participant_otps")
          .update({ attempts: otpRecord.attempts + 1 })
          .eq("email", targetEmail);

        const remaining = 5 - (otpRecord.attempts + 1);
        return json({
          success: false,
          error: `Incorrect verification code. ${remaining > 0 ? `${remaining} attempts remaining.` : "Please request a new code."}`
        }, 400);
      }

      // 5. Successful verification: Single-use invalidation (DELETE record immediately)
      await admin.from("participant_otps").delete().eq("email", targetEmail);

      // 6. Generate official Supabase Auth token_hash for client session establishment
      const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
        type: "magiclink",
        email: targetEmail
      });

      if (linkErr || !linkData?.properties?.hashed_token) {
        console.error("Session token generation error:", linkErr);
        return json({ success: false, error: "Error authenticating session. Please try again." }, 500);
      }

      const tokenHash = linkData.properties.hashed_token;

      return json({
        success: true,
        message: "OTP verified successfully.",
        token_hash: tokenHash,
        email: targetEmail
      });
    }

    // -------------------------------------------------------------------------
    // ACTION: email-pass (Send digital entry pass for authenticated participant)
    // -------------------------------------------------------------------------
    if (action === "email-pass") {
      const token = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
      if (!token) {
        return json({ success: false, error: "Please verify your email to access your pass." }, 401);
      }

      const { data: authData, error: authError } = await admin.auth.getUser(token);
      const email = authData.user?.email?.trim().toLowerCase();
      if (authError || !authData.user || !email) {
        return json({ success: false, error: "Please verify your email to access your pass." }, 401);
      }

      const subject = typeof body?.subject === "string" ? body.subject : "Your SRISHTI 2.7 Digital Entry Pass";
      const html = typeof body?.html === "string" ? body.html : "";
      const image = typeof body?.image === "string" ? body.image : undefined;

      if (!html) {
        return json({ success: false, error: "Email content is required." }, 400);
      }

      // Only allows dispatching to the authenticated participant's own email address
      const mailResult = await dispatchEmail(email, subject, html, image);
      if (!mailResult.ok) {
        return json({ success: false, error: "Could not send entry pass email." }, 502);
      }

      return json({ success: true, message: "Digital entry pass sent to your email." });
    }

    // -------------------------------------------------------------------------
    // ACTION: send-registration-pass (Server-side registration pass delivery)
    // -------------------------------------------------------------------------
    if (action === "send-registration-pass") {
      const targetEmail = typeof body?.to === "string" ? body.to.trim().toLowerCase() : "";
      const subject = typeof body?.subject === "string" ? body.subject : "Your SRISHTI 2.7 Digital Entry Pass";
      const html = typeof body?.html === "string" ? body.html : "";
      const image = typeof body?.image === "string" ? body.image : undefined;

      if (!targetEmail || !html) {
        return json({ success: false, error: "Missing required email parameters." }, 400);
      }

      // Must belong to a registered participant
      const { data: pCheck } = await admin
        .from("participants")
        .select("id")
        .ilike("email", targetEmail.replace(/[\\%_]/g, "\\$&"))
        .maybeSingle();

      if (!pCheck) {
        return json({ success: false, error: "Recipient must be a registered participant." }, 403);
      }

      const mailResult = await dispatchEmail(targetEmail, subject, html, image);
      if (!mailResult.ok) {
        return json({ success: false, error: "Failed to dispatch pass email." }, 502);
      }

      return json({ success: true, message: "Registration pass emailed." });
    }

    // -------------------------------------------------------------------------
    // AUTHENTICATED ACTIONS: get / save (Requires valid Supabase Auth Bearer token)
    // -------------------------------------------------------------------------
    if (action !== "get" && action !== "save") {
      return json({ success: false, error: "Invalid profile action." }, 400);
    }

    const token = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) {
      return json({ success: false, error: "Please verify your email to access your profile." }, 401);
    }

    const { data: authData, error: authError } = await admin.auth.getUser(token);
    const email = authData.user?.email?.trim().toLowerCase();
    if (authError || !authData.user || !email || !authData.user.email_confirmed_at) {
      return json({ success: false, error: "Please verify your email to access your profile." }, 401);
    }

    let { data: participant, error: participantError } = await admin
      .from("participants")
      .select("id, participant_code, name, email, phone, college, department, year")
      .ilike("email", email.replace(/[\\%_]/g, "\\$&"))
      .maybeSingle();

    if (participantError) {
      console.error("Participant lookup failed:", participantError);
      return json({ success: false, error: "Could not load your participant profile." }, 503);
    }

    if (!participant) {
      return json({
        success: false,
        not_registered: true,
        error: "No registered participant profile found for this email. Please register for an event first."
      }, 404);
    }

    if (action === "save") {
      const profile = (body?.profile ?? {}) as Record<string, unknown>;
      const name = typeof profile.name === "string" ? profile.name.trim() : "";
      const phone = typeof profile.phone === "string" ? profile.phone.trim().slice(0, 20) : "";
      const college = typeof profile.college === "string" ? profile.college.trim().slice(0, 150) : "";
      const department = typeof profile.department === "string" && profile.department.trim() ? profile.department.trim().slice(0, 100) : "General";
      const year = typeof profile.year === "string" && profile.year.trim() ? profile.year.trim().slice(0, 50) : "1st Year";

      if (name.length < 2 || name.length > 100 || !phone || !college) {
        return json({ success: false, error: "Name, phone number, and college are required." }, 400);
      }

      const { data, error } = await admin
        .from("participants")
        .update({ name, phone, college, department, year })
        .eq("id", participant.id)
        .select("id, participant_code, name, email, phone, college, department, year")
        .single();

      if (error) {
        console.error("Participant profile update failed:", error);
        return json({ success: false, error: "Could not save your profile." }, 500);
      }
      participant = data;
    }

    let registrations: unknown[] = [];
    let arrivalCheckin: unknown = null;
    let attendanceLogs: unknown[] = [];

    const { data: regData, error: regError } = await admin
      .from("registrations")
      .select("*, events(*)")
      .eq("participant_id", participant.id)
      .order("registered_at", { ascending: false });
    if (!regError && regData) registrations = regData;

    const { data: arrData } = await admin
      .from("arrival_checkins")
      .select("id, checked_in_at, source, notes")
      .eq("participant_id", participant.id)
      .maybeSingle();
    if (arrData) arrivalCheckin = arrData;

    const { data: attData } = await admin
      .from("event_attendance")
      .select("id, event_id, marked_at, source, events(name, event_code)")
      .eq("participant_id", participant.id);
    if (attData) attendanceLogs = attData;

    return json({
      success: true,
      participant,
      registrations,
      arrival_checkin: arrivalCheckin,
      attendance_logs: attendanceLogs
    });
  } catch (error) {
    console.error("Unexpected participant-profile error:", error);
    return json({ success: false, error: "Could not process your profile request." }, 500);
  }
});
