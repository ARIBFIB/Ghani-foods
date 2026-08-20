// Edit an existing purchase receipt (supplier, date, line items) - fully
// recomputes affected raw materials' stock/avg cost. Blocked (400) if the
// edit would leave a raw material with negative stock.
// POST /functions/v1/receipts-update
// body: { receiptId, supplierId, purchaseDate, items: [{rawMaterialId, qty, cost}] }
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.receiptId || !body.supplierId || !body.items) {
      return jsonResponse(envelopeError("receiptId, supplierId and items are required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase.rpc("fn_update_purchase_receipt", {
      p_receipt_id: body.receiptId,
      p_supplier_id: body.supplierId,
      p_purchase_date: body.purchaseDate ?? new Date().toISOString().slice(0, 10),
      p_items: body.items,
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
