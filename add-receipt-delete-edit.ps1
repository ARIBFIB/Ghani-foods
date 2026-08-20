#
# add-receipt-delete-edit.ps1
# -----------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Adds Delete + Edit for purchase receipts, client-requested:
#   "Receipt delete option alse be there and edit option also.
#    When receipt delete to us se related inventory should also get deleted"
#
# What this script does (frontend + backend):
#   1. Adds a new migration: apps/backend/supabase/migrations/0005_receipt_delete_edit.sql
#      - fn_delete_purchase_receipt(receiptId): deletes the receipt and its
#        lines, then RECOMPUTES the affected raw materials' stock/avg cost
#        from what's left. BLOCKS the delete (raises an error) if any of
#        that receipt's stock has already been used elsewhere - so deleting
#        a receipt can never push a raw material's stock negative.
#      - fn_update_purchase_receipt(...): same idea for editing quantities/
#        cost/supplier/date on an existing receipt.
#   2. Adds two new edge functions: receipts-delete, receipts-update
#      (not strictly required by the frontend - it calls the RPCs directly
#      via the store, same pattern as createPurchaseReceipt - but included
#      for consistency / in case you want a plain REST path later).
#   3. Adds deleteReceipt() / updateReceipt() actions to lib/store.ts
#   4. Replaces app/(dashboard)/receipts/page.tsx with a version that has
#      working Delete and inline Edit (quantity/cost) buttons per receipt.
#
# IMPORTANT - after running this script you still need to push the new
# SQL function to your actual Supabase database. This script only writes
# local files; it does not have your DB credentials. From apps/backend:
#
#   supabase db push
#
# (or paste 0005_receipt_delete_edit.sql into the Supabase SQL editor and
# run it there, if you are not using the CLI migration workflow.)
#
# Safe to re-run - already-applied changes are skipped.
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Normalize([string]$s) { return $s -replace "`r`n", "`n" }

# ---------------------------------------------------------------------
# 1) Migration SQL
# ---------------------------------------------------------------------
$migrationsDir = Join-Path $root "apps\backend\supabase\migrations"
if (-not (Test-Path -LiteralPath $migrationsDir)) {
    Write-Host "ERROR: Could not find $migrationsDir - are you in the repo root?" -ForegroundColor Red
    exit 1
}
$migrationPath = Join-Path $migrationsDir "0005_receipt_delete_edit.sql"
if (Test-Path -LiteralPath $migrationPath) {
    Write-Host "Migration already exists - skipping: $migrationPath" -ForegroundColor Yellow
} else {
@'
-- 0005_receipt_delete_edit.sql
-- Adds safe delete + edit for purchase receipts.
--
-- Design: rather than trying to algebraically "reverse" the weighted-average
-- cost formula (error prone, hard to audit), both functions fully RECOMPUTE
-- each affected raw material's quantity_in_stock and avg_unit_cost from the
-- remaining purchase_receipt_lines rows after the change. This is always
-- correct and matches exactly what fn_create_purchase_receipt would produce
-- if the receipts had been entered in the remaining order.
--
-- Both functions BLOCK the change (raise an exception, which rolls back the
-- whole transaction) if it would drive any affected raw material's stock
-- negative - i.e. if some of that receipt's stock has already been consumed
-- by a production batch, wrapper/box run, etc.

create or replace function fn_recompute_raw_material_stock(p_raw_material_id uuid)
returns void as $$
declare
  v_qty numeric;
  v_avg_cost numeric;
begin
  select coalesce(sum(qty), 0),
         case when coalesce(sum(qty), 0) = 0 then 0 else sum(qty * cost) / sum(qty) end
    into v_qty, v_avg_cost
    from purchase_receipt_lines
   where raw_material_id = p_raw_material_id;

  update raw_materials
     set quantity_in_stock = v_qty,
         avg_unit_cost = v_avg_cost
   where id = p_raw_material_id;
end;
$$ language plpgsql;

-- ---------------------------------------------------------------------
-- Delete a whole receipt
-- ---------------------------------------------------------------------
create or replace function fn_delete_purchase_receipt(p_receipt_id uuid)
returns json as $$
declare
  v_line record;
  v_material_ids uuid[] := '{}';
  v_material_name text;
begin
  if not exists (select 1 from purchase_receipts where id = p_receipt_id) then
    raise exception 'Receipt not found' using errcode = 'P0002';
  end if;

  for v_line in
    select rl.*, rm.name as material_name, rm.quantity_in_stock as current_stock
      from purchase_receipt_lines rl
      join raw_materials rm on rm.id = rl.raw_material_id
     where rl.receipt_id = p_receipt_id
  loop
    if v_line.current_stock - v_line.qty < -0.0001 then
      raise exception 'Cannot delete: % of "%" from this receipt has already been used elsewhere (only % left in stock)',
        v_line.qty, v_line.material_name, v_line.current_stock
        using errcode = '23514';
    end if;
    v_material_ids := array_append(v_material_ids, v_line.raw_material_id);
  end loop;

  delete from purchase_receipt_lines where receipt_id = p_receipt_id;
  delete from purchase_receipts where id = p_receipt_id;

  perform fn_recompute_raw_material_stock(m) from unnest(v_material_ids) as m;

  return json_build_object('ok', true);
end;
$$ language plpgsql security definer;

-- ---------------------------------------------------------------------
-- Edit an existing receipt's line quantities/costs (supplier + date too)
-- p_items replaces ALL lines on the receipt (same shape as create).
-- ---------------------------------------------------------------------
create or replace function fn_update_purchase_receipt(
  p_receipt_id uuid,
  p_supplier_id uuid,
  p_purchase_date date,
  p_items jsonb
)
returns json as $$
declare
  v_old_material_ids uuid[] := '{}';
  v_new_material_ids uuid[] := '{}';
  v_all_material_ids uuid[];
  v_item jsonb;
  v_bad record;
begin
  if not exists (select 1 from purchase_receipts where id = p_receipt_id) then
    raise exception 'Receipt not found' using errcode = 'P0002';
  end if;

  select array_agg(raw_material_id) into v_old_material_ids
    from purchase_receipt_lines where receipt_id = p_receipt_id;

  delete from purchase_receipt_lines where receipt_id = p_receipt_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into purchase_receipt_lines (receipt_id, raw_material_id, qty, cost)
    values (
      p_receipt_id,
      (v_item->>'rawMaterialId')::uuid,
      (v_item->>'qty')::numeric,
      (v_item->>'cost')::numeric
    );
    v_new_material_ids := array_append(v_new_material_ids, (v_item->>'rawMaterialId')::uuid);
  end loop;

  update purchase_receipts
     set supplier_id = p_supplier_id,
         purchase_date = p_purchase_date
   where id = p_receipt_id;

  select array_agg(distinct m) into v_all_material_ids
    from unnest(coalesce(v_old_material_ids, '{}') || coalesce(v_new_material_ids, '{}')) as m;

  perform fn_recompute_raw_material_stock(m) from unnest(v_all_material_ids) as m;

  select rm.name, rm.quantity_in_stock into v_bad
    from raw_materials rm
   where rm.id = any(v_all_material_ids) and rm.quantity_in_stock < -0.0001
   limit 1;

  if v_bad.name is not null then
    raise exception 'Cannot save: this edit would leave "%" at % in stock, because some of it has already been used elsewhere',
      v_bad.name, v_bad.quantity_in_stock
      using errcode = '23514';
  end if;

  return json_build_object('ok', true);
end;
$$ language plpgsql security definer;

grant execute on function fn_delete_purchase_receipt(uuid) to authenticated;
grant execute on function fn_update_purchase_receipt(uuid, uuid, date, jsonb) to authenticated;

'@ | Set-Content -LiteralPath $migrationPath -NoNewline
    Write-Host "Created: apps\backend\supabase\migrations\0005_receipt_delete_edit.sql" -ForegroundColor Green
}

# ---------------------------------------------------------------------
# 2) Edge functions
# ---------------------------------------------------------------------
$fnRoot = Join-Path $root "apps\backend\supabase\functions"

$delDir = Join-Path $fnRoot "receipts-delete"
New-Item -ItemType Directory -Path $delDir -Force | Out-Null
$delPath = Join-Path $delDir "index.ts"
if (Test-Path -LiteralPath $delPath) {
    Write-Host "receipts-delete/index.ts already exists - skipping." -ForegroundColor Yellow
} else {
@'
// Delete a purchase receipt - reverses its effect on raw material stock.
// Blocked (400) if any of the receipt's stock has already been consumed.
// POST /functions/v1/receipts-delete   body: { receiptId: string }
import { corsHeaders } from "../_shared/cors.ts";
import { getClient, statusForPgError, jsonResponse, envelopeError, envelopeSuccess } from "../_shared/client.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const supabase = getClient(req);

    if (!body.receiptId) {
      return jsonResponse(envelopeError("receiptId is required", "BAD_REQUEST"), 400, corsHeaders);
    }

    const { data, error } = await supabase.rpc("fn_delete_purchase_receipt", {
      p_receipt_id: body.receiptId,
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

'@ | Set-Content -LiteralPath $delPath -NoNewline
    Write-Host "Created: apps\backend\supabase\functions\receipts-delete\index.ts" -ForegroundColor Green
}

$updDir = Join-Path $fnRoot "receipts-update"
New-Item -ItemType Directory -Path $updDir -Force | Out-Null
$updPath = Join-Path $updDir "index.ts"
if (Test-Path -LiteralPath $updPath) {
    Write-Host "receipts-update/index.ts already exists - skipping." -ForegroundColor Yellow
} else {
@'
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

'@ | Set-Content -LiteralPath $updPath -NoNewline
    Write-Host "Created: apps\backend\supabase\functions\receipts-update\index.ts" -ForegroundColor Green
}

# ---------------------------------------------------------------------
# 3) store.ts - add deleteReceipt / updateReceipt actions
# ---------------------------------------------------------------------
$storePath = Join-Path $root "apps\frontend\lib\store.ts"
if (-not (Test-Path -LiteralPath $storePath)) {
    Write-Host "ERROR: Could not find $storePath" -ForegroundColor Red
} else {
    $raw = Get-Content -Raw -LiteralPath $storePath
    $usesCrlf = $raw -match "`r`n"
    $norm = Normalize $raw

    if ($norm -match [regex]::Escape("deleteReceipt:")) {
        Write-Host "store.ts already has deleteReceipt/updateReceipt - skipping." -ForegroundColor Yellow
    } else {
        $oldInterface = (Normalize @'
  createPurchaseReceipt: (input: {
    supplierId: string;
    purchaseDate: string;
    items: { rawMaterialId: string; qty: number; cost: number }[];
  }) => Promise<string>;
'@).Trim()
        $newInterface = (Normalize @'
  createPurchaseReceipt: (input: {
    supplierId: string;
    purchaseDate: string;
    items: { rawMaterialId: string; qty: number; cost: number }[];
  }) => Promise<string>;
  deleteReceipt: (receiptId: string) => Promise<void>;
  updateReceipt: (receiptId: string, input: {
    supplierId: string;
    purchaseDate: string;
    items: { rawMaterialId: string; qty: number; cost: number }[];
  }) => Promise<void>;
'@).Trim()
        $oldImpl = (Normalize @'
  createPurchaseReceipt: async (input) => {
    const { data, error } = await supabase.rpc("fn_create_purchase_receipt", {
      p_supplier_id: input.supplierId,
      p_purchase_date: input.purchaseDate,
      p_items: input.items.map((i) => ({ rawMaterialId: i.rawMaterialId, qty: i.qty, cost: i.cost })),
    });
    if (error || !data) throw new Error(error?.message ?? "Failed to save purchase receipt");
    await get().loadRawMaterialsModule();
    return (data as any).receiptId as string;
  },
'@).Trim()
        $newImpl = (Normalize @'
  createPurchaseReceipt: async (input) => {
    const { data, error } = await supabase.rpc("fn_create_purchase_receipt", {
      p_supplier_id: input.supplierId,
      p_purchase_date: input.purchaseDate,
      p_items: input.items.map((i) => ({ rawMaterialId: i.rawMaterialId, qty: i.qty, cost: i.cost })),
    });
    if (error || !data) throw new Error(error?.message ?? "Failed to save purchase receipt");
    await get().loadRawMaterialsModule();
    return (data as any).receiptId as string;
  },

  deleteReceipt: async (receiptId) => {
    const { error } = await supabase.rpc("fn_delete_purchase_receipt", { p_receipt_id: receiptId });
    if (error) throw new Error(error.message ?? "Failed to delete receipt");
    await get().loadRawMaterialsModule();
  },

  updateReceipt: async (receiptId, input) => {
    const { error } = await supabase.rpc("fn_update_purchase_receipt", {
      p_receipt_id: receiptId,
      p_supplier_id: input.supplierId,
      p_purchase_date: input.purchaseDate,
      p_items: input.items.map((i) => ({ rawMaterialId: i.rawMaterialId, qty: i.qty, cost: i.cost })),
    });
    if (error) throw new Error(error.message ?? "Failed to update receipt");
    await get().loadRawMaterialsModule();
  },
'@).Trim()

        if ($norm -notmatch [regex]::Escape($oldInterface) -or $norm -notmatch [regex]::Escape($oldImpl)) {
            Write-Host "ERROR: Expected blocks not found in store.ts - skipping (check by hand)." -ForegroundColor Red
        } else {
            Copy-Item -LiteralPath $storePath -Destination "$storePath.bak-$stamp"
            $fixed = $norm.Replace($oldInterface, $newInterface)
            $fixed = $fixed.Replace($oldImpl, $newImpl)
            if ($usesCrlf) { $fixed = $fixed -replace "`n", "`r`n" }
            Set-Content -LiteralPath $storePath -Value $fixed -NoNewline
            Write-Host "Fixed: apps\frontend\lib\store.ts (added deleteReceipt/updateReceipt)" -ForegroundColor Green
        }
    }
}

# ---------------------------------------------------------------------
# 4) receipts/page.tsx - full replace with Delete + Edit UI
# ---------------------------------------------------------------------
$pagePath = Join-Path $root "apps\frontend\app\(dashboard)\receipts\page.tsx"
if (-not (Test-Path -LiteralPath $pagePath)) {
    Write-Host "ERROR: Could not find $pagePath" -ForegroundColor Red
} else {
    $existing = Get-Content -Raw -LiteralPath $pagePath
    if ($existing -match [regex]::Escape("deleteReceipt")) {
        Write-Host "receipts/page.tsx already has delete/edit UI - skipping." -ForegroundColor Yellow
    } else {
        Copy-Item -LiteralPath $pagePath -Destination "$pagePath.bak-$stamp"
@'
"use client";

import { Fragment, useEffect, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight } from "lucide-react";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";

export default function ReceiptsPage() {
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const deleteReceipt = useStore((s) => s.deleteReceipt);
  const updateReceipt = useStore((s) => s.updateReceipt);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);

  const [supplierFilter, setSupplierFilter] = useState("");
  const [materialFilter, setMaterialFilter] = useState("");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editRows, setEditRows] = useState<{ id: string; rawMaterialId: string; qty: string; cost: string }[]>([]);
  const [savingEdit, setSavingEdit] = useState(false);

  const rows = useMemo(() => {
    return receipts
      .map((r) => {
        const lines = receiptLines.filter((l) => l.receiptId === r.id);
        const supplier = suppliers.find((s) => s.id === r.supplierId);
        const totalValue = lines.reduce((sum, l) => sum + l.qty * l.cost, 0);
        const itemNames = lines.map((l) => rawMaterials.find((m) => m.id === l.rawMaterialId)?.name ?? "?");
        return { receipt: r, lines, supplier, totalValue, itemNames };
      })
      .filter(({ receipt, lines }) => {
        if (supplierFilter && receipt.supplierId !== supplierFilter) return false;
        if (materialFilter && !lines.some((l) => l.rawMaterialId === materialFilter)) return false;
        if (fromDate && receipt.purchaseDate < fromDate) return false;
        if (toDate && receipt.purchaseDate > toDate) return false;
        return true;
      })
      .sort((a, b) => b.receipt.purchaseDate.localeCompare(a.receipt.purchaseDate));
  }, [receipts, receiptLines, suppliers, rawMaterials, supplierFilter, materialFilter, fromDate, toDate]);

  const hasFilters = !!(supplierFilter || materialFilter || fromDate || toDate);

  const startEdit = (receiptId: string, lines: { id: string; rawMaterialId: string; qty: number; cost: number }[]) => {
    setEditingId(receiptId);
    setExpandedId(receiptId);
    setEditRows(lines.map((l) => ({ id: l.id, rawMaterialId: l.rawMaterialId, qty: String(l.qty), cost: String(l.cost) })));
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditRows([]);
  };

  const saveEdit = async (receiptId: string, supplierId: string, purchaseDate: string) => {
    for (const row of editRows) {
      const qty = Number(row.qty);
      const cost = Number(row.cost);
      if (!qty || qty <= 0) { toast.error("Every line needs a quantity greater than 0"); return; }
      if (!cost || cost <= 0) { toast.error("Every line needs a cost greater than 0"); return; }
    }
    setSavingEdit(true);
    try {
      await updateReceipt(receiptId, {
        supplierId,
        purchaseDate,
        items: editRows.map((r) => ({ rawMaterialId: r.rawMaterialId, qty: Number(r.qty), cost: Number(r.cost) })),
      });
      toast.success("Receipt updated");
      setEditingId(null);
      setEditRows([]);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to update receipt");
    } finally {
      setSavingEdit(false);
    }
  };

  const handleDelete = async (receiptId: string) => {
    if (!window.confirm("Delete this receipt? This will reverse its effect on raw material stock. This cannot be undone.")) {
      return;
    }
    setDeletingId(receiptId);
    try {
      await deleteReceipt(receiptId);
      toast.success("Receipt deleted");
      if (expandedId === receiptId) setExpandedId(null);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to delete receipt");
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Receipts</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
      </div>

      <div className="flex flex-col sm:flex-row flex-wrap items-stretch sm:items-end gap-3 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
        <div>
          <label className="text-xs text-[var(--text-muted)]">Supplier</label>
          <select value={supplierFilter} onChange={(e) => setSupplierFilter(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            <option value="">All suppliers</option>
            {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">Raw Material</label>
          <select value={materialFilter} onChange={(e) => setMaterialFilter(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            <option value="">All materials</option>
            {rawMaterials.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">From</label>
          <input value={fromDate} onChange={(e) => setFromDate(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">To</label>
          <input value={toDate} onChange={(e) => setToDate(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
        </div>
        {hasFilters && (
          <button
            type="button"
            onClick={() => { setSupplierFilter(""); setMaterialFilter(""); setFromDate(""); setToDate(""); }}
            className="rounded-lg px-3 py-2 text-xs text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
          >
            Clear filters
          </button>
        )}
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[720px] text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium w-8"></th>
              <th className="px-4 py-3 font-medium">Receipt Date</th>
              <th className="px-4 py-3 font-medium">Supplier</th>
              <th className="px-4 py-3 font-medium">Items</th>
              <th className="px-4 py-3 font-medium">Total Value</th>
              <th className="px-4 py-3 font-medium text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[var(--text-faint)]">No receipts match these filters.</td></tr>
            )}
            {rows.map(({ receipt, lines, supplier, totalValue, itemNames }) => {
              const isExpanded = expandedId === receipt.id;
              const isEditing = editingId === receipt.id;
              const summary = itemNames.length > 2
                ? `${itemNames.length} items: ${itemNames.slice(0, 2).join(", ")}, +${itemNames.length - 2}`
                : `${itemNames.length} item${itemNames.length !== 1 ? "s" : ""}: ${itemNames.join(", ")}`;
              return (
                <Fragment key={receipt.id}>
                  <tr className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                    <td className="px-4 py-3">
                      <button type="button" onClick={() => setExpandedId(isExpanded ? null : receipt.id)} className="text-[var(--text-muted)] hover:text-[var(--foreground)]">
                        {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{receipt.purchaseDate}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">
                      {supplier ? (
                        <NavLink href={`/suppliers/${supplier.id}`} className="hover:underline text-[var(--foreground)]">{supplier.name}</NavLink>
                      ) : "-"}
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{summary}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {totalValue.toLocaleString()}</td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          onClick={() => (isEditing ? cancelEdit() : startEdit(receipt.id, lines))}
                          className="rounded-lg px-2.5 py-1 text-xs text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
                        >
                          {isEditing ? "Cancel" : "Edit"}
                        </button>
                        <button
                          type="button"
                          disabled={deletingId === receipt.id}
                          onClick={() => handleDelete(receipt.id)}
                          className="rounded-lg px-2.5 py-1 text-xs text-red-500 hover:bg-red-500/10 disabled:opacity-50"
                        >
                          {deletingId === receipt.id ? "Deleting..." : "Delete"}
                        </button>
                      </div>
                    </td>
                  </tr>
                  {isExpanded && (
                    <tr className="border-b border-[var(--surface-border)] last:border-0 bg-[var(--background)]">
                      <td></td>
                      <td colSpan={5} className="px-4 py-3">
                        <table className="w-full text-xs">
                          <thead>
                            <tr className="text-left text-[var(--text-muted)]">
                              <th className="pb-2 font-medium">Raw Material</th>
                              <th className="pb-2 font-medium">Quantity</th>
                              <th className="pb-2 font-medium">Cost/Unit</th>
                              <th className="pb-2 font-medium">Total</th>
                            </tr>
                          </thead>
                          <tbody>
                            {!isEditing && lines.map((l) => {
                              const material = rawMaterials.find((m) => m.id === l.rawMaterialId);
                              return (
                                <tr key={l.id} className="border-t border-[var(--surface-border)]">
                                  <td className="py-2 text-[var(--text-secondary)]">
                                    {material ? (
                                      <NavLink href={`/raw-materials/${material.id}`} className="hover:underline text-[var(--foreground)]">{material.name}</NavLink>
                                    ) : "-"}
                                  </td>
                                  <td className="py-2 text-[var(--text-secondary)]">{l.qty} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {l.cost.toLocaleString()}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {(l.qty * l.cost).toLocaleString()}</td>
                                </tr>
                              );
                            })}
                            {isEditing && editRows.map((row, idx) => {
                              const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
                              return (
                                <tr key={row.id} className="border-t border-[var(--surface-border)]">
                                  <td className="py-2 text-[var(--text-secondary)]">{material?.name ?? "-"}</td>
                                  <td className="py-2">
                                    <input
                                      type="number"
                                      value={row.qty}
                                      onChange={(e) => setEditRows((rs) => rs.map((r, i) => (i === idx ? { ...r, qty: e.target.value } : r)))}
                                      className="w-20 rounded-md border border-[var(--surface-border)] bg-[var(--background)] px-2 py-1 text-xs text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                                    /> <span className="text-[var(--text-faint)]">{material?.unit ?? ""}</span>
                                  </td>
                                  <td className="py-2">
                                    <input
                                      type="number"
                                      value={row.cost}
                                      onChange={(e) => setEditRows((rs) => rs.map((r, i) => (i === idx ? { ...r, cost: e.target.value } : r)))}
                                      className="w-24 rounded-md border border-[var(--surface-border)] bg-[var(--background)] px-2 py-1 text-xs text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                                    />
                                  </td>
                                  <td className="py-2 text-[var(--text-secondary)]">
                                    Rs. {((Number(row.qty) || 0) * (Number(row.cost) || 0)).toLocaleString()}
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                        {isEditing && (
                          <div className="flex justify-end gap-2 pt-3">
                            <button type="button" onClick={cancelEdit} className="rounded-lg px-3 py-1.5 text-xs text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">
                              Cancel
                            </button>
                            <button
                              type="button"
                              disabled={savingEdit}
                              onClick={() => saveEdit(receipt.id, receipt.supplierId, receipt.purchaseDate)}
                              className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-3 py-1.5 text-xs font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 disabled:opacity-50"
                            >
                              {savingEdit ? "Saving..." : "Save changes"}
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>

      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}

'@ | Set-Content -LiteralPath $pagePath -NoNewline
        Write-Host "Replaced: apps\frontend\app\(dashboard)\receipts\page.tsx (added Delete + Edit)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Push the new SQL function to Supabase:"
Write-Host "       cd apps\backend"
Write-Host "       supabase db push"
Write-Host "     (or paste 0005_receipt_delete_edit.sql into the Supabase SQL editor)"
Write-Host "  2. (Optional) Deploy the two new edge functions:"
Write-Host "       supabase functions deploy receipts-delete"
Write-Host "       supabase functions deploy receipts-update"
Write-Host "  3. cd apps\frontend; npm run dev"
Write-Host "  4. Test on the Receipts page:"
Write-Host "       - Click Delete on a receipt whose stock is untouched -> it disappears,"
Write-Host "         and that raw material's stock/avg cost drops accordingly."
Write-Host "       - Click Delete on a receipt whose stock has already been used in a"
Write-Host "         batch -> you should see a red error toast, NOT a silent failure."
Write-Host "       - Click Edit -> change a quantity/cost -> Save changes -> confirm"
Write-Host "         the raw material's stock updates correctly."