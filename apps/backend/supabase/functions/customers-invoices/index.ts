// GET /functions/v1/customers-invoices?customerId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const customerId = url.searchParams.get("customerId");
    if (!customerId) return jsonResponse(envelopeError("customerId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data, error } = await supabase
      .from("invoices")
      .select("id, invoice_number, invoice_date, total_amount, pdf_url")
      .eq("customer_id", customerId)
      .order("invoice_date", { ascending: false });

    if (error) return jsonResponse(envelopeError(error.message, "DB_ERROR"), 500, corsHeaders);
    return jsonResponse(envelopeSuccess(data), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
