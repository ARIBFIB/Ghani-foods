// GET /functions/v1/invoices-pdf?id=
// Returns invoice + line items + business settings needed to render a PDF.
// TODO: generate actual PDF bytes and upload to the `invoices` Storage bucket,
// then persist the signed URL onto invoices.pdf_url. For now this returns the
// structured payload the frontend can render (or pass to a PDF library) and,
// if pdf_url is already set from a previous generation, includes it directly.
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const id = url.searchParams.get("id");
    if (!id) return jsonResponse(envelopeError("id is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data: invoice, error: invErr } = await supabase
      .from("invoices")
      .select("id, invoice_number, invoice_date, total_amount, pdf_url, customers(name, phone), invoice_items(item_name, qty, unit_price, subtotal, price_source_note)")
      .eq("id", id)
      .maybeSingle();

    if (invErr) return jsonResponse(envelopeError(invErr.message, "DB_ERROR"), 500, corsHeaders);
    if (!invoice) return jsonResponse(envelopeError("invoice not found", "NOT_FOUND"), 404, corsHeaders);

    const { data: settings } = await supabase
      .from("app_settings")
      .select("business_name, address, invoice_footer_text")
      .eq("id", 1)
      .maybeSingle();

    return jsonResponse(envelopeSuccess({ invoice, settings, pdfReady: Boolean(invoice.pdf_url) }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
