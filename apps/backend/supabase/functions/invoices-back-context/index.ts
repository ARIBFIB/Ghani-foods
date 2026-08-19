// GET /functions/v1/invoices-back-context?id=
// Extra context for the invoice print-back (e.g. running customer balance at
// time of this invoice, footer text) so the frontend does not need extra calls.
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
      .select("id, invoice_number, customer_id, invoice_date, total_amount")
      .eq("id", id)
      .maybeSingle();

    if (invErr) return jsonResponse(envelopeError(invErr.message, "DB_ERROR"), 500, corsHeaders);
    if (!invoice) return jsonResponse(envelopeError("invoice not found", "NOT_FOUND"), 404, corsHeaders);

    const { data: ledgerEntry } = await supabase
      .from("customer_ledger_entries")
      .select("running_balance, entry_date")
      .eq("reference_id", invoice.id)
      .eq("type", "invoice")
      .maybeSingle();

    const { data: settings } = await supabase
      .from("app_settings")
      .select("invoice_footer_text, business_name, address")
      .eq("id", 1)
      .maybeSingle();

    return jsonResponse(envelopeSuccess({
      invoiceId: invoice.id,
      invoiceNumber: invoice.invoice_number,
      balanceAfterThisInvoice: ledgerEntry?.running_balance ?? null,
      footerText: settings?.invoice_footer_text ?? null,
      businessName: settings?.business_name ?? null,
      address: settings?.address ?? null,
    }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
