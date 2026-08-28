// Create a Debit Note (Purchase Return) against a supplier.
// Blocks if returning more than is currently in stock (some may already
// be consumed in production). Reduces raw_materials stock and reduces
// the supplier's balance. Wraps fn_create_debit_note.
// POST /functions/v1/debit-notes
// body: { supplierId: string, lines: [{ rawMaterialId: string, qty: number, cost: number }], note?: string }
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.supplierId) {
      return jsonResponse(envelopeError("supplierId is required", "BAD_REQUEST"), 400, corsHeaders);
    }
    if (!body.lines || !Array.isArray(body.lines) || body.lines.length < 1) {
      return jsonResponse(envelopeError("at least one line item is required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const rpcParams = {
      p_supplier_id: body.supplierId,
      p_lines: body.lines,
      p_note: body.note ?? null,
    };

    const { data, error } = await supabase.rpc("fn_create_debit_note", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
