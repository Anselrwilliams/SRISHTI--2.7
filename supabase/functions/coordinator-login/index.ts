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

function firstConfiguredKey(name: string, dictionaryName: string): string | null {
  const direct = Deno.env.get(name);
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get(dictionaryName) ?? "{}") as Record<string, string>;
    return Object.values(keys).find((value) => typeof value === "string") ?? null;
  } catch {
    return null;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = firstConfiguredKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS");
  const publishableKey = firstConfiguredKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS");
  if (!supabaseUrl || !serviceKey || !publishableKey) {
    console.error("Coordinator login is missing Supabase server configuration.");
    return json({ success: false, error: "Login service unavailable" }, 503);
  }

  let body: { username?: unknown; password?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ success: false, error: "Username and password are required" }, 400);
  }

  // The mobile UI currently labels this field "Username", but operators may
  // enter either their volunteer username or the email on their volunteer profile.
  const identifier = typeof body.username === "string" ? body.username.trim().toLowerCase() : "";
  const password = typeof body.password === "string" ? body.password : "";
  if (!identifier || !password || identifier.length > 254 || password.length > 1024) {
    return json({ success: false, error: "Username and password are required" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let volunteerQuery = admin
    .from("volunteers")
    .select("email, role, status");
  if (identifier.includes("@")) {
    // Escape PostgREST ilike wildcards so the address is always matched exactly.
    volunteerQuery = volunteerQuery.ilike("email", identifier.replace(/[\\%_]/g, "\\$&"));
  } else {
    volunteerQuery = volunteerQuery.ilike("username", identifier.replace(/[\\%_]/g, "\\$&"));
  }
  const { data: volunteer, error: volunteerError } = await volunteerQuery.maybeSingle();

  const allowedRoles = new Set(["admin", "registration", "event_staff", "volunteer"]);
  if (
    volunteerError || !volunteer?.email || volunteer.status !== "active" ||
    !allowedRoles.has(String(volunteer.role).toLowerCase())
  ) {
    // Keep unknown, inactive, and unauthorized accounts indistinguishable from bad credentials.
    return json({ success: false, error: "Invalid username or password" }, 401);
  }

  const authClient = createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await authClient.auth.signInWithPassword({
    email: volunteer.email,
    password,
  });

  if (error || !data.session?.refresh_token) {
    return json({ success: false, error: "Invalid username or password" }, 401);
  }

  // The Flutter client exchanges this refresh token for its normal Supabase session.
  return json({ success: true, session: { refresh_token: data.session.refresh_token } });
});
