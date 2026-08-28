<#
    step-a-backend-edge-functions.ps1
    --------------------------------------------------------------------
    STEP A - Backend Edge Functions fix + new endpoints (matches
    migration 0009_contra_returns_supplier_ledger.sql)

    What this script does:
      1. Fixes payments/index.ts            -> adds required p_method
      2. Fixes purchase-receipts/index.ts    -> switches to
                                                 fn_create_purchase_receipt_from_po
                                                 (PO is now mandatory)
      3. Creates supplier-payments/index.ts  -> fn_record_supplier_payment
      4. Creates credit-notes/index.ts       -> fn_create_credit_note
      5. Creates debit-notes/index.ts        -> fn_create_debit_note
      6. Creates contra-vouchers/index.ts    -> fn_create_contra_transfer

    Usage:
      1. Copy this script into your project root:
         D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods\
      2. Run it:
         PS D:\...\GhaniFoods> .\step-a-backend-edge-functions.ps1
      3. It will back up any file it overwrites (adds .bak-<timestamp>)
      4. Then deploy the changed/new functions with Supabase CLI, e.g.:
         supabase functions deploy payments
         supabase functions deploy purchase-receipts
         supabase functions deploy supplier-payments
         supabase functions deploy credit-notes
         supabase functions deploy debit-notes
         supabase functions deploy contra-vouchers
#>

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$root = "apps\backend\supabase\functions"

function Write-FunctionFile {
    param(
        [string]$RelativeDir,   # e.g. "payments"
        [string]$Content
    )

    $dir = Join-Path $root $RelativeDir
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir"
    }

    $filePath = Join-Path $dir "index.ts"

    if (Test-Path $filePath) {
        $backupPath = "$filePath.bak-$timestamp"
        Copy-Item -Path $filePath -Destination $backupPath -Force
        Write-Host "Backed up existing file -> $backupPath"
    }

    Set-Content -Path $filePath -Value $Content -Encoding UTF8
    Write-Host "Wrote: $filePath"
}

# ============================================================
# 1. payments/index.ts  (FIX: add p_method, required bank/cash)
# ============================================================
$paymentsContent = @'
// Record a customer payment/adjustment (FR-42/43) - direction AND method
// are both mandatory. method must be "bank" or "cash" and determines
// which treasury account (Bank or Cash) is moved by fn_record_payment.
// POST /functions/v1/payments
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.method || (body.method !== "bank" && body.method !== "cash")) {
      return jsonResponse(envelopeError("method is required and must be 'bank' or 'cash'", "BAD_REQUEST"), 400, corsHeaders);
    }

    const rpcParams = {
      p_customer_id: body.customerId,
      p_amount: body.amount,
      p_direction: body.direction,
      p_method: body.method,
      p_note: body.note ?? null,
    };

    const { data, error } = await supabase.rpc("fn_record_payment", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

Write-FunctionFile -RelativeDir "payments" -Content $paymentsContent

# ============================================================
# 2. purchase-receipts/index.ts (FIX: PO now mandatory)
# ============================================================
$purchaseReceiptsContent = @'
// Record a purchase receipt AGAINST A PURCHASE ORDER (FR-11/12).
// As of migration 0009, fn_create_purchase_receipt (the old PO-less
// function) is deprecated. poId is now REQUIRED - nothing can be
// received into stock without a valid, still-open Purchase Order.
// POST /functions/v1/purchase-receipts
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.poId) {
      return jsonResponse(envelopeError("poId is required - a receipt cannot be created without a valid Purchase Order", "BAD_REQUEST"), 400, corsHeaders);
    }

    const rpcParams = {
      p_po_id: body.poId,
      p_purchase_date: body.purchaseDate ?? new Date().toISOString().slice(0, 10),
      p_items: body.items,
    };

    const { data, error } = await supabase.rpc("fn_create_purchase_receipt_from_po", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

Write-FunctionFile -RelativeDir "purchase-receipts" -Content $purchaseReceiptsContent

# ============================================================
# 3. supplier-payments/index.ts (NEW)
# ============================================================
$supplierPaymentsContent = @'
// Record a supplier payment (paying down what we owe a supplier).
// Reduces supplier.current_balance and moves money OUT of the chosen
// treasury account (Bank or Cash). Wraps fn_record_supplier_payment.
// POST /functions/v1/supplier-payments
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
    if (!body.method || (body.method !== "bank" && body.method !== "cash")) {
      return jsonResponse(envelopeError("method is required and must be 'bank' or 'cash'", "BAD_REQUEST"), 400, corsHeaders);
    }

    const rpcParams = {
      p_supplier_id: body.supplierId,
      p_amount: body.amount,
      p_method: body.method,
      p_note: body.note ?? null,
    };

    const { data, error } = await supabase.rpc("fn_record_supplier_payment", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
  } catch (err) {
    return jsonResponse(envelopeError(err instanceof Error ? err.message : "Unknown error", "BAD_REQUEST"), 400, corsHeaders);
  }
});
'@

Write-FunctionFile -RelativeDir "supplier-payments" -Content $supplierPaymentsContent

# ============================================================
# 4. credit-notes/index.ts (NEW) - Sales Return
# ============================================================
$creditNotesContent = @'
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
'@

Write-FunctionFile -RelativeDir "credit-notes" -Content $creditNotesContent

# ============================================================
# 5. debit-notes/index.ts (NEW) - Purchase Return
# ============================================================
$debitNotesContent = @'
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
'@

Write-FunctionFile -RelativeDir "debit-notes" -Content $debitNotesContent

# ============================================================
# 6. contra-vouchers/index.ts (NEW) - Bank <-> Cash transfer
# ============================================================
$contraVouchersContent = @'
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
'@

Write-FunctionFile -RelativeDir "contra-vouchers" -Content $contraVouchersContent

Write-Host ""
Write-Host "===================================================================="
Write-Host "STEP A COMPLETE"
Write-Host "===================================================================="
Write-Host "Fixed:"
Write-Host "  - payments/index.ts            (p_method now required)"
Write-Host "  - purchase-receipts/index.ts   (now requires poId, uses fn_create_purchase_receipt_from_po)"
Write-Host ""
Write-Host "Created:"
Write-Host "  - supplier-payments/index.ts"
Write-Host "  - credit-notes/index.ts"
Write-Host "  - debit-notes/index.ts"
Write-Host "  - contra-vouchers/index.ts"
Write-Host ""
Write-Host "NEXT: deploy these functions, e.g.:"
Write-Host "  supabase functions deploy payments"
Write-Host "  supabase functions deploy purchase-receipts"
Write-Host "  supabase functions deploy supplier-payments"
Write-Host "  supabase functions deploy credit-notes"
Write-Host "  supabase functions deploy debit-notes"
Write-Host "  supabase functions deploy contra-vouchers"
Write-Host ""
Write-Host "NOTE: purchase-receipts now REQUIRES poId in the request body."
Write-Host "The frontend (purchase-receipt-dialog.tsx, lib/api.ts, lib/store.ts)"
Write-Host "still calls the old shape - that is STEP B/C/D, coming next."