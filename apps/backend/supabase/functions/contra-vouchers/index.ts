// Create a Contra Voucher (internal Bank <-> Cash transfer).
// Moves money between the two treasury accounts. fromMethod and
// toMethod must differ. Wraps fn_create_contra_transfer.
// POST /functions/v1/contra-vouchers
// body: { fromMethod: "bank"|"cash", toMethod: "bank"|"cash", amount: number, note?: string }
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.fromMethod || (body.fromMethod !== "bank" && body.fromMethod !== "cash")) {
      return jsonResponse(envelopeError("fromMethod is required and must be 'bank' or 'cash'", "BAD_REQUEST"), 400, corsHeaders);
    }
    if (!body.toMethod || (body.toMethod !== "bank" && body.toMethod !== "cash")) {
      return jsonResponse(envelopeError("toMethod is required and must be 'bank' or 'cash'", "BAD_REQUEST"), 400, corsHeaders);
    }
    if (body.fromMethod === body.toMethod) {
      return jsonResponse(envelopeError("fromMethod and toMethod must be different", "BAD_REQUEST"), 400, corsHeaders);
    }

    const rpcParams = {
      p_from_method: body.fromMethod,
      p_to_method: body.toMethod,
      p_amount: body.amount,
      p_note: body.note ?? null,
    };

    const { data, error } = await supabase.rpc("fn_create_contra_transfer", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
