import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
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

function serviceKey(): string | null {
  const direct = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}") as Record<string, string>;
    return Object.values(keys).find((value) => typeof value === "string") ?? null;
  } catch {
    return null;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  if (!supabaseUrl || !key) {
    console.error("Spot registration is missing Supabase server configuration.");
    return json({ success: false, error: "Registration service unavailable" }, 503);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) return json({ success: false, error: "Authentication required" }, 401);

  const admin = createClient(supabaseUrl, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(tokenMatch[1]);
  const user = userData.user;
  if (userError || !user) return json({ success: false, error: "Authentication required" }, 401);

  let body: Record<string, unknown>;
  try {
    const raw = await req.text();
    if (raw.length > 64_000) return json({ success: false, error: "Request is too large" }, 413);
    body = JSON.parse(raw);
  } catch {
    return json({ success: false, error: "Invalid request body" }, 400);
  }

  const participant = body.participant;
  const payment = body.payment;
  const teamMembers = body.team_members;
  const eventId = typeof body.event_id === "string" ? body.event_id : "";
  if (!eventId || !participant || typeof participant !== "object" || Array.isArray(participant)) {
    return json({ success: false, error: "Event and participant details are required" }, 400);
  }
  if (!payment || typeof payment !== "object" || Array.isArray(payment)) {
    return json({ success: false, error: "Payment details are required" }, 400);
  }

  const person = participant as Record<string, unknown>;
  const pay = payment as Record<string, unknown>;
  const requiredText = ["name", "phone", "college"] as const;
  for (const field of requiredText) {
    if (typeof person[field] !== "string" || !person[field].trim()) {
      return json({ success: false, error: `${field} is required` }, 400);
    }
  }
  if (teamMembers !== undefined && !Array.isArray(teamMembers)) {
    return json({ success: false, error: "team_members must be an array" }, 400);
  }
  if (pay.verified !== true || typeof pay.amount !== "number" || !Number.isFinite(pay.amount)) {
    return json({ success: false, error: "Payment must be verified and include a valid amount" }, 400);
  }

  // The database procedure rechecks active role, event state, team size, official fee,
  // duplicates, and payment fields within one transaction.
  const { data, error } = await admin.rpc("fn_create_spot_registration", {
    p_coordinator_auth_id: user.id,
    p_event_id: eventId,
    p_participant_name: (person.name as string).trim(),
    p_participant_phone: (person.phone as string).trim(),
    p_participant_email: typeof person.email === "string" ? person.email.trim() : "",
    p_participant_college: (person.college as string).trim(),
    p_participant_department: typeof person.department === "string" ? person.department.trim() : "General",
    p_participant_year: typeof person.year === "string" ? person.year.trim() : "1st Year",
    p_team_members: teamMembers ?? [],
    p_payment_method: typeof pay.method === "string" ? pay.method : "upi",
    p_payment_amount: pay.amount,
    p_payment_reference: typeof pay.reference === "string" ? pay.reference : null,
  });

  if (error) {
    const message = error.message ?? "Registration could not be completed";
    if (message.includes("DUPLICATE_REGISTRATION") || error.code === "23505") {
      return json({ success: false, is_duplicate: true, error: "DUPLICATE_REGISTRATION" }, 409);
    }
    if (message.includes("UNAUTHORIZED") || message.includes("FORBIDDEN")) {
      return json({ success: false, error: "Only active registration coordinators and admins can register on the spot" }, 403);
    }
    if (message.includes("EVENT_NOT_FOUND")) return json({ success: false, error: "Event not found" }, 404);
    if (message.includes("PAYMENT_MISMATCH")) return json({ success: false, error: "Payment amount does not match the event fee" }, 400);
    if (/^(22|P0002)/.test(error.code ?? "")) return json({ success: false, error: message.split(":").slice(1).join(":").trim() || "Invalid registration details" }, 400);
    console.error("Spot registration RPC failed:", error.code, message);
    return json({ success: false, error: "Registration could not be completed" }, 500);
  }

  return json(data);
});
