// Create a Credit Note (Sales Return) against an existing invoice.
// Validates returned qty against original invoice_items, reverses
// finished_carton stock (adds back), and reduces the customer's balance.
// Wraps fn_create_credit_note.
// POST /functions/v1/credit-notes
// body: { invoiceId: string, lines: [{ invoiceItemId: string, qty: number }], note?: string }
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.invoiceId) {
      return jsonResponse(envelopeError("invoiceId is required", "BAD_REQUEST"), 400, corsHeaders);
    }
    if (!body.lines || !Array.isArray(body.lines) || body.lines.length < 1) {
      return jsonResponse(envelopeError("at least one line item is required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const rpcParams = {
      p_invoice_id: body.invoiceId,
      p_lines: body.lines,
      p_note: body.note ?? null,
    };

    const { data, error } = await supabase.rpc("fn_create_credit_note", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
