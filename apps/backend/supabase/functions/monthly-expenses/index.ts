// CRUD for accumulative monthly expenses (e.g. "August Electricity: 45000").
// GET    /functions/v1/monthly-expenses?month=2026-08-01   -> list for that month
// POST   /functions/v1/monthly-expenses   body: { month, name, amount } -> create
// DELETE /functions/v1/monthly-expenses   body: { id } -> delete
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

function firstOfMonth(dateStr: string) {
  const d = new Date(dateStr);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const supabase = getClient(req);

  try {
    if (req.method === "GET") {
      const url = new URL(req.url);
      const month = url.searchParams.get("month");
      if (!month) {
        return jsonResponse(envelopeError("month query param required (YYYY-MM-DD)", "BAD_REQUEST"), 400, corsHeaders);
      }
      const { data, error } = await supabase
        .from("monthly_expenses")
        .select("*")
        .eq("month", firstOfMonth(month))
        .order("created_at", { ascending: true });

      if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 400, corsHeaders);
      return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
    }

    if (req.method === "POST") {
      const body = await req.json();
      if (!body.month || !body.name || body.amount == null) {
        return jsonResponse(envelopeError("month, name and amount are required", "BAD_REQUEST"), 400, corsHeaders);
      }
      const { data, error } = await supabase
        .from("monthly_expenses")
        .insert({ month: firstOfMonth(body.month), name: body.name, amount: body.amount })
        .select()
        .single();

      if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 400, corsHeaders);
      return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
    }

    if (req.method === "DELETE") {
      const body = await req.json();
      if (!body.id) {
        return jsonResponse(envelopeError("id required", "BAD_REQUEST"), 400, corsHeaders);
      }
      const { error } = await supabase.from("monthly_expenses").delete().eq("id", body.id);
      if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 400, corsHeaders);
      return jsonResponse(envelopeSuccess({ deleted: true }), 200, corsHeaders);
    }

    return jsonResponse(envelopeError("Method not allowed", "METHOD_NOT_ALLOWED"), 405, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});