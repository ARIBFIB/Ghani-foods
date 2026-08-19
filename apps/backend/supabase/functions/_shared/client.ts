import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Creates a Supabase client that forwards the caller's JWT, so RLS
// (authenticated-only policies) applies exactly as if the frontend
// called PostgREST directly. Never use the service role key here.
export function getClient(req: Request) {
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } }
  );
}

// Maps Postgres errcodes raised by fn_* functions to HTTP status codes
// per the response envelope convention in the backend spec.
export function statusForPgError(message: string): number {
  if (message.includes("insufficient")) return 409; // stock/balance conflicts
  if (message.includes("not found")) return 404;
  if (message.includes("required") || message.includes("must be")) return 400;
  return 500;
}

export function jsonResponse(body: unknown, status = 200, extraHeaders: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...extraHeaders },
  });
}

export function envelopeError(message: string, code = "ERROR", details: unknown = null) {
  return { data: null, error: { code, message, details } };
}

export function envelopeSuccess(data: unknown) {
  return { data, error: null };
}
