// GET /functions/v1/suppliers-history?supplierId=
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = getClient(req);
    const url = new URL(req.url);
    const supplierId = url.searchParams.get("supplierId");
    if (!supplierId) return jsonResponse(envelopeError("supplierId is required", "BAD_REQUEST"), 400, corsHeaders);

    const { data: receipts, error: receiptsError } = await supabase
      .from("purchase_receipts")
      .select("id, purchase_date, created_at, purchase_receipt_lines(id, raw_material_id, qty, cost, avg_cost_after)")
      .eq("supplier_id", supplierId)
      .order("purchase_date", { ascending: false });

    if (receiptsError) return jsonResponse(envelopeError(receiptsError.message, "DB_ERROR"), 500, corsHeaders);

    const { data: ledger, error: ledgerError } = await supabase
      .from("supplier_ledger_entries")
      .select("id, amount, type, reference_id, running_balance, note, entry_date, created_at")
      .eq("supplier_id", supplierId)
      .order("created_at", { ascending: false });

    if (ledgerError) return jsonResponse(envelopeError(ledgerError.message, "DB_ERROR"), 500, corsHeaders);

    const { data: balance, error: balanceError } = await supabase
      .rpc("fn_supplier_balance", { p_supplier_id: supplierId });

    if (balanceError) return jsonResponse(envelopeError(balanceError.message, "DB_ERROR"), 500, corsHeaders);

    return jsonResponse(envelopeSuccess({ receipts, ledger, balance }), 200, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
