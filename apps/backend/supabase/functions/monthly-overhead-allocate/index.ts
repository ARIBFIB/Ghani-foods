// Allocates a month's accumulative expenses across that month's batches.
// POST /functions/v1/monthly-overhead-allocate
// body: { month: "2026-08-01", method?: "equal" | "proportional_kg" }
// If method is omitted, uses app_settings.overhead_allocation_method.
// Safe to re-run for the same month - replaces the previous allocation.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.month) {
      return jsonResponse(envelopeError("month is required (YYYY-MM-DD)", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase.rpc("fn_allocate_monthly_overhead", {
      p_month: body.month,
      p_method: body.method ?? null,
    });

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});