import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface TeamMember {
  name: string;
  email?: string;
  phone?: string;
  college?: string;
}

interface WebRegisterPayload {
  name: string;
  email: string;
  phone?: string;
  college?: string;
  department?: string;
  year?: string;
  event_id?: string;
  event_code?: string;
  team_members?: TeamMember[];
  payment_method?: string;
  payment_reference?: string;
  otp?: string;
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

async function hashOtp(email: string, code: string): Promise<string> {
  const salt = getOtpSalt();
  const encoder = new TextEncoder();
  const data = encoder.encode(`${email.toLowerCase()}:${code.trim()}:${salt}`);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req: Request) => {
  // 1. Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 2. Only allow POST
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ success: false, error: "Method not allowed. Use POST." }),
        { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Initialize Supabase Admin Client using server-side service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRoleKey = getServiceKey();

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in Edge Function environment.");
      return new Response(
        JSON.stringify({ success: false, error: "Server configuration error." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    });
    const bearerToken = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
    const { data: callerData } = bearerToken
      ? await supabase.auth.getUser(bearerToken)
      : { data: { user: null } };
    const verifiedCallerEmail = callerData.user?.email_confirmed_at && callerData.user.email
      ? callerData.user.email.trim().toLowerCase()
      : null;

    // 4. Parse request body
    let body: WebRegisterPayload;
    try {
      const rawBody = await req.text();
      if (rawBody.length > 64_000) {
        return new Response(
          JSON.stringify({ success: false, error: "Registration request is too large." }),
          { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const parsed = JSON.parse(rawBody);
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        return new Response(
          JSON.stringify({ success: false, error: "A registration object is required." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      body = parsed as WebRegisterPayload;
    } catch {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid JSON body." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const {
      name,
      email,
      phone,
      college,
      department = "N/A",
      year = "N/A",
      event_id,
      event_code,
      team_members = [],
      payment_method = "upi",
      payment_reference,
      otp
    } = body;

    // 5. Strict Input Validation & Sanitization
    if (!name || typeof name !== "string" || name.trim().length < 2 || name.trim().length > 100) {
      return new Response(
        JSON.stringify({ success: false, error: "Valid participant name (2 to 100 characters) is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const cleanEmail = typeof email === "string" ? email.trim().toLowerCase() : "";
    if (!cleanEmail || cleanEmail.length > 120 || !emailRegex.test(cleanEmail)) {
      return new Response(
        JSON.stringify({ success: false, error: "A valid email address is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Verify Participant Identity (Session or OTP Verification)
    let isEmailVerified = false;
    if (verifiedCallerEmail && verifiedCallerEmail === cleanEmail) {
      isEmailVerified = true;
    } else if (otp && typeof otp === "string" && otp.trim().length === 6) {
      const otpInput = otp.trim();
      const { data: otpRecord } = await supabase
        .from("participant_otps")
        .select("*")
        .eq("email", cleanEmail)
        .maybeSingle();

      if (otpRecord && otpRecord.attempts < 5 && new Date(otpRecord.expires_at).getTime() > Date.now()) {
        const inputHash = await hashOtp(cleanEmail, otpInput);
        if (inputHash === otpRecord.otp_hash) {
          isEmailVerified = true;
          // Invalidate single-use OTP
          await supabase.from("participant_otps").delete().eq("email", cleanEmail);
        }
      }
    }

    if (!isEmailVerified) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Email verification required. Please verify your email with OTP before registering."
        }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const cleanPhone = phone ? String(phone).trim().replace(/[^\d+ -]/g, "").slice(0, 20) : null;
    const cleanCollege = college ? String(college).trim().slice(0, 150) : "N/A";
    const cleanDept = department ? String(department).trim().slice(0, 100) : "N/A";
    const cleanYear = year ? String(year).trim().slice(0, 50) : "N/A";
    const cleanPaymentRef = payment_reference ? String(payment_reference).trim().slice(0, 64) : "";

    if (!event_id && !event_code) {
      return new Response(
        JSON.stringify({ success: false, error: "Either event_id or event_code is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Verify Event Exists and is Open for Registration
    let eventQuery = supabase.from("events").select("*");
    if (event_id) {
      eventQuery = eventQuery.eq("id", event_id);
    } else {
      eventQuery = eventQuery.eq("event_code", event_code!.trim());
    }

    const { data: event, error: eventErr } = await eventQuery.maybeSingle();

    if (eventErr || !event) {
      return new Response(
        JSON.stringify({ success: false, error: "Event not found. Please verify the event code." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Event status validation: must be 'upcoming' or 'ongoing' (or 'scheduled'/'active')
    const openStatuses = ["upcoming", "ongoing", "scheduled", "active"];
    if (event.status && !openStatuses.includes(event.status.toLowerCase())) {
      return new Response(
        JSON.stringify({ success: false, error: `Registration is closed. Event is currently marked as ${event.status}.` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Team validation
    if (team_members !== undefined && !Array.isArray(team_members)) {
      return new Response(
        JSON.stringify({ success: false, error: "Team members must be provided as a list." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const teamArray = Array.isArray(team_members) ? team_members : [];
    const totalTeamSize = 1 + teamArray.length;

    if (event.registration_type === "individual" && teamArray.length > 0) {
      return new Response(
        JSON.stringify({ success: false, error: "This is an individual event. Team members cannot be registered." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (event.max_team_size && totalTeamSize > event.max_team_size) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `Team size (${totalTeamSize}) exceeds the maximum allowed size of ${event.max_team_size} for this event.`
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 7. Find or Create Participant Record
    let participantId: string;
    let participantCode: string;

    const { data: existingParticipant, error: pFindErr } = await supabase
      .from("participants")
      .select("id, participant_code, name, email, phone, college")
      .ilike("email", cleanEmail.replace(/[\\%_]/g, "\\$&"))
      .maybeSingle();

    if (pFindErr) {
      console.error("Participant lookup failed:", pFindErr);
      return new Response(
        JSON.stringify({ success: false, error: "Registration could not be completed. Please try again." }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (existingParticipant) {
      participantId = existingParticipant.id;
      participantCode = existingParticipant.participant_code;
      if (verifiedCallerEmail === cleanEmail) {
        const { data: updatedParticipant, error: pUpdateErr } = await supabase
          .from("participants")
          .update({
            name: name.trim(),
            phone: cleanPhone,
            college: cleanCollege,
            department: cleanDept,
            year: cleanYear
          })
          .eq("id", existingParticipant.id)
          .select("id, participant_code, name, email, phone, college, department, year")
          .single();
        if (pUpdateErr || !updatedParticipant) {
          console.error("Failed to update participant:", pUpdateErr);
          return new Response(
            JSON.stringify({ success: false, error: "Failed to save participant profile. Please try again." }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
        Object.assign(existingParticipant, updatedParticipant);
      }
    } else {
      // Use the database sequence so website codes match other SRISHTI clients.
      const { data: generatedCode, error: codeErr } = await supabase.rpc("fn_generate_participant_code");
      if (codeErr || typeof generatedCode !== "string" || !generatedCode) {
        console.error("Participant code generation failed:", codeErr);
        return new Response(
          JSON.stringify({ success: false, error: "Registration could not be completed. Please try again." }),
          { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      participantCode = generatedCode;

      const { data: newParticipant, error: pInsertErr } = await supabase
        .from("participants")
        .insert([{
          participant_code: participantCode,
          name: name.trim(),
          email: cleanEmail,
          phone: cleanPhone,
          college: cleanCollege,
          department: cleanDept,
          year: cleanYear
        }])
        .select("id, participant_code, name, email, phone, college, department, year")
        .single();

      if (pInsertErr || !newParticipant) {
        console.error("Failed to create participant:", pInsertErr);
        return new Response(
          JSON.stringify({ success: false, error: "Failed to create participant profile. Please try again." }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      participantId = newParticipant.id;
    }

    // Ensure participant account exists in auth.users so they can receive official OTPs with shouldCreateUser: false
    try {
      await supabase.auth.admin.createUser({
        email: cleanEmail,
        email_confirm: true,
        user_metadata: { name: name.trim() }
      });
    } catch (_) {
      // User may already exist in auth.users
    }

    // 8. Duplicate Registration Check
    const { data: existingReg, error: regCheckErr } = await supabase
      .from("registrations")
      .select("id, status, payment_status")
      .eq("participant_id", participantId)
      .eq("event_id", event.id)
      .maybeSingle();

    if (regCheckErr) {
      console.error("Registration duplicate check failed:", regCheckErr);
      return new Response(
        JSON.stringify({ success: false, error: "Registration could not be completed. Please try again." }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (existingReg) {
      if (existingReg.status === "registered") {
        return new Response(
          JSON.stringify({
            success: false,
            code: "DUPLICATE_REGISTRATION",
            error: `Participant is already registered for ${event.name}.`,
            data: {
              participant_code: participantCode,
              registration_id: existingReg.id,
              payment_status: existingReg.payment_status
            }
          }),
          { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 9. Payment Status Determination & UTR Validation (Enforced strictly server-side)
    // Security Rule:
    // The database event.registration_fee is the single source of truth.
    // Client-provided fee, payment_status, verified, paid, or amount are strictly ignored.
    const expectedFee = Math.max(0, Number(event.registration_fee || 0));

    // For paid events (registration_fee > 0):
    // 1. Payment reference (UTR) is MANDATORY and cannot be empty or whitespace.
    // 2. payment_status MUST remain 'pending' until authorized coordinator/admin verification.
    // For free events (registration_fee == 0):
    // payment_status is 'verified'.
    if (expectedFee > 0) {
      if (!cleanPaymentRef || cleanPaymentRef.trim().length === 0) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Payment reference / UTR is required for paid event registrations."
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    const finalPaymentStatus = expectedFee === 0 ? "verified" : "pending";
    const finalPaymentMethod = expectedFee === 0 ? "waived" : (payment_method || "upi");

    // 10. Insert Registration
    const registrationPayload = {
      participant_id: participantId,
      event_id: event.id,
      status: "registered",
      registration_source: "web",
      registered_by: null, // Null for self-service web registration
      payment_status: finalPaymentStatus,
      payment_method: finalPaymentMethod,
      payment_amount: expectedFee, // Strictly enforced from server database
      payment_reference: expectedFee > 0 ? cleanPaymentRef.trim() : null,
      team_members: teamArray
    };

    const { data: createdReg, error: regInsertErr } = await supabase
      .from("registrations")
      .insert([registrationPayload])
      .select("*")
      .single();

    if (regInsertErr || !createdReg) {
      console.error("Failed to insert registration:", regInsertErr);
      if (regInsertErr?.code === "23505") {
        return new Response(
          JSON.stringify({ success: false, code: "DUPLICATE_REGISTRATION", error: `Participant is already registered for ${event.name}.` }),
          { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      return new Response(
          JSON.stringify({ success: false, error: "Failed to record event registration. Please try again." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 11. Return Clean Success Response
    return new Response(
      JSON.stringify({
        success: true,
        message: finalPaymentStatus === "verified"
          ? "Registration completed successfully."
          : "Registration submitted successfully. Payment pending verification.",
        data: {
          registration_id: createdReg.id,
          status: createdReg.status,
          payment_status: createdReg.payment_status,
          payment_amount: createdReg.payment_amount,
          payment_reference: createdReg.payment_reference,
          participant: {
            id: participantId,
            participant_code: participantCode,
            name: existingParticipant?.name || name.trim(),
            email: cleanEmail,
            phone: existingParticipant?.phone || cleanPhone,
            college: existingParticipant?.college || cleanCollege,
            department: existingParticipant?.department || cleanDept,
            year: existingParticipant?.year || cleanYear
          },
          event: {
            id: event.id,
            event_code: event.event_code,
            name: event.name,
            category: event.category,
            venue: event.venue,
            date: event.date,
            start_time: event.start_time,
            registration_fee: expectedFee
          }
        }
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err: unknown) {
    console.error("Unexpected error in web-register:", err);
    return new Response(
      JSON.stringify({ success: false, error: "Registration could not be completed. Please try again." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
