<#
  add-purchase-orders-b2a-frontend.ps1
  GhaniFoods - Phase 2 / Batch B2a: Purchase Order create/view screens (frontend)

  This batch does NOT touch the database. It assumes migration
  0008_purchase_orders_and_treasury.sql (fn_create_purchase_order,
  purchase_orders, purchase_order_lines) is already applied - i.e. you
  already ran add-purchase-orders-and-treasury.ps1 and pushed that
  migration. This script only wires up the frontend so you can actually
  create and view Purchase Orders:

    1. apps/frontend/lib/store.ts
       - adds PurchaseOrder / PurchaseOrderLine types
       - adds purchaseOrders / purchaseOrderLines state
       - adds loadPurchaseOrders() (reads purchase_orders + purchase_order_lines)
       - adds createPurchaseOrder() (calls fn_create_purchase_order via RPC)
       - wires loadPurchaseOrders() into loadAll()

    2. apps/frontend/components/ui/purchase-order-dialog.tsx (NEW)
       - Supplier + PO Date + Notes + line items (raw material, qty ordered,
         expected unit cost), same visual pattern as purchase-receipt-dialog.tsx,
         with inline "+ New Supplier"

    3. apps/frontend/app/(dashboard)/purchase-orders/page.tsx (NEW)
       - list table: PO#, Supplier, Date, Status badge, Outstanding qty
       - expandable rows showing lines (ordered vs received)
       - "New PO" button opening the dialog

    4. apps/frontend/components/ui/sidebar-component.tsx
       - adds a "Purchase Orders" link under the existing Receipts section

  This script is IDEMPOTENT: if a step was already applied (new file
  already exists, or the store.ts/sidebar anchor text is missing because
  you already patched it), that step is skipped rather than failing.

  Run this from the repo root:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\add-purchase-orders-b2a-frontend.ps1
    .\add-purchase-orders-b2a-frontend.ps1 -WhatIf
#>

param(
    [switch]$WhatIf
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

function Write-FileUtf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

$frontendDir = Join-Path $root "apps\frontend"
if (-not (Test-Path -LiteralPath $frontendDir)) {
    Write-Fail "Not found: $frontendDir"
    Write-Fail "Make sure you're running this from the GhaniFoods repo root."
    exit 1
}

$storePath     = Join-Path $frontendDir "lib\store.ts"
$sidebarPath   = Join-Path $frontendDir "components\ui\sidebar-component.tsx"
$dialogPath    = Join-Path $frontendDir "components\ui\purchase-order-dialog.tsx"
$pageDir       = Join-Path $frontendDir "app\(dashboard)\purchase-orders"
$pagePath      = Join-Path $pageDir "page.tsx"

foreach ($p in @($storePath, $sidebarPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Fail "Not found: $p"
        Write-Fail "Expected file layout doesn't match - aborting so nothing gets half-applied."
        exit 1
    }
}

# =====================================================================
# [1/4] Patch apps/frontend/lib/store.ts
# =====================================================================
Write-Step "[1/4] Patching lib/store.ts (Purchase Order types + state + actions)..."

$storeContent = Get-Content -LiteralPath $storePath -Raw

$anchorTypesBefore = 'export type Wrapper = {'
$typesBlock = @'
export type PurchaseOrderStatus = "draft" | "sent" | "partially_received" | "received" | "closed";

export type PurchaseOrder = {
  id: string;
  poNumber: string;
  supplierId: string;
  poDate: string;
  status: PurchaseOrderStatus;
  notes?: string;
};

export type PurchaseOrderLine = {
  id: string;
  poId: string;
  rawMaterialId: string;
  qtyOrdered: number;
  qtyReceived: number;
  expectedUnitCost: number;
};

'@

if ($storeContent.Contains("export type PurchaseOrder = {")) {
    Write-Skip "PurchaseOrder types already present - skipping."
} elseif (-not $storeContent.Contains($anchorTypesBefore)) {
    Write-Fail "Anchor not found for types insert ('$anchorTypesBefore'). File may have changed - skipping this edit."
} else {
    $storeContent = $storeContent.Replace($anchorTypesBefore, $typesBlock + $anchorTypesBefore)
    Write-Ok "Added PurchaseOrder / PurchaseOrderLine types."
}

$anchorMapperBefore = 'function mapWrapperRow(row: Record<string, any>): Wrapper {'
$mapperBlock = @'
function mapPurchaseOrderRow(row: Record<string, any>): PurchaseOrder {
  return {
    id: row.id,
    poNumber: row.po_number,
    supplierId: row.supplier_id,
    poDate: row.po_date,
    status: row.status,
    notes: row.notes ?? undefined,
  };
}
function mapPurchaseOrderLineRow(row: Record<string, any>): PurchaseOrderLine {
  return {
    id: row.id,
    poId: row.po_id,
    rawMaterialId: row.raw_material_id,
    qtyOrdered: Number(row.qty_ordered),
    qtyReceived: Number(row.qty_received),
    expectedUnitCost: Number(row.expected_unit_cost),
  };
}

'@

if ($storeContent.Contains("function mapPurchaseOrderRow(")) {
    Write-Skip "mapPurchaseOrderRow already present - skipping."
} elseif (-not $storeContent.Contains($anchorMapperBefore)) {
    Write-Fail "Anchor not found for mapper insert ('$anchorMapperBefore'). Skipping this edit."
} else {
    $storeContent = $storeContent.Replace($anchorMapperBefore, $mapperBlock + $anchorMapperBefore)
    Write-Ok "Added mapPurchaseOrderRow / mapPurchaseOrderLineRow."
}

$anchorStateField = 'receiptLines: PurchaseReceiptLine[];'
$stateFieldBlock = @'
receiptLines: PurchaseReceiptLine[];
  purchaseOrders: PurchaseOrder[];
  purchaseOrderLines: PurchaseOrderLine[];
'@

if ($storeContent.Contains("purchaseOrders: PurchaseOrder[];")) {
    Write-Skip "purchaseOrders state field already present - skipping."
} elseif (-not $storeContent.Contains($anchorStateField)) {
    Write-Fail "Anchor not found for state field insert. Skipping this edit."
} else {
    $storeContent = $storeContent.Replace($anchorStateField, $stateFieldBlock)
    Write-Ok "Added purchaseOrders / purchaseOrderLines to State type."
}

$anchorActionSig = '  // Wrapper / Box'
$actionSigBlock = @'
  // Purchase Orders (Phase 2 / Batch B2a)
  loadPurchaseOrders: () => Promise<void>;
  createPurchaseOrder: (input: {
    supplierId: string;
    poDate: string;
    notes?: string;
    items: { rawMaterialId: string; qty: number; expectedUnitCost: number }[];
  }) => Promise<string>;

  // Wrapper / Box
'@

if ($storeContent.Contains("createPurchaseOrder: (input:")) {
    Write-Skip "createPurchaseOrder signature already present - skipping."
} elseif (-not $storeContent.Contains($anchorActionSig)) {
    Write-Fail "Anchor not found for action signature insert. Skipping this edit."
} else {
    $storeContent = $storeContent.Replace($anchorActionSig, $actionSigBlock)
    Write-Ok "Added loadPurchaseOrders / createPurchaseOrder signatures."
}

$anchorInitialState = '  receiptLines: [],'
$initialStateBlock = @'
  receiptLines: [],
  purchaseOrders: [],
  purchaseOrderLines: [],
'@

if ($storeContent.Contains("  purchaseOrders: [],")) {
    Write-Skip "purchaseOrders initial state already present - skipping."
} elseif (-not $storeContent.Contains($anchorInitialState)) {
    Write-Fail "Anchor not found for initial state insert. Skipping this edit."
} else {
    $storeContent = $storeContent.Replace($anchorInitialState, $initialStateBlock)
    Write-Ok "Added purchaseOrders / purchaseOrderLines initial state."
}

$anchorLoadAll = 'get().loadRawMaterialsModule(),'
$loadAllBlock = @'
get().loadRawMaterialsModule(),
      get().loadPurchaseOrders(),
'@

if ($storeContent.Contains("get().loadPurchaseOrders(),")) {
    Write-Skip "loadPurchaseOrders() already wired into loadAll() - skipping."
} elseif (-not $storeContent.Contains($anchorLoadAll)) {
    Write-Fail "Anchor not found for loadAll() wiring. Skipping this edit."
} else {
    $storeContent = $storeContent.Replace($anchorLoadAll, $loadAllBlock)
    Write-Ok "Wired loadPurchaseOrders() into loadAll()."
}

$anchorActionImpl = '  loadPackagingModule: async () => {'
$actionImplBlock = @'
  // ---------------------------------------------------------------------
  // Purchase Orders (Phase 2 / Batch B2a)
  // ---------------------------------------------------------------------

  loadPurchaseOrders: async () => {
    const [posRes, poLinesRes] = await Promise.all([
      supabase.from("purchase_orders").select("*").order("created_at", { ascending: false }),
      supabase.from("purchase_order_lines").select("*"),
    ]);
    set({
      purchaseOrders: (posRes.data ?? []).map(mapPurchaseOrderRow),
      purchaseOrderLines: (poLinesRes.data ?? []).map(mapPurchaseOrderLineRow),
    });
  },

  // "Without purchase order nothing should get added": fn_create_purchase_order
  // is the only way a PO (and its lines) gets created. Batch B2b will make
  // fn_create_purchase_receipt_from_po the only way a receipt can be recorded
  // against one of these.
  createPurchaseOrder: async (input) => {
    const { data, error } = await supabase.rpc("fn_create_purchase_order", {
      p_supplier_id: input.supplierId,
      p_po_date: input.poDate,
      p_notes: input.notes ?? null,
      p_items: input.items.map((i) => ({
        rawMaterialId: i.rawMaterialId,
        qty: i.qty,
        expectedUnitCost: i.expectedUnitCost,
      })),
    });
    if (error || !data) throw new Error(error?.message ?? "Failed to create purchase order");
    await get().loadPurchaseOrders();
    return (data as any).poNumber ?? (data as any).id;
  },

  loadPackagingModule: async () => {
'@

if ($storeContent.Contains("createPurchaseOrder: async (input) => {")) {
    Write-Skip "createPurchaseOrder implementation already present - skipping."
} elseif (-not $storeContent.Contains($anchorActionImpl)) {
    Write-Fail "Anchor not found for action implementation insert. Skipping this edit."
} else {
    $storeContent = $storeContent.Replace($anchorActionImpl, $actionImplBlock)
    Write-Ok "Added loadPurchaseOrders / createPurchaseOrder implementations."
}

if ($WhatIf) {
    Write-Skip "(WhatIf) Would write updated store.ts"
} else {
    Write-FileUtf8NoBom -Path $storePath -Content $storeContent
    Write-Ok "Saved store.ts"
}

# =====================================================================
# [2/4] New file: purchase-order-dialog.tsx
# =====================================================================
Write-Step "[2/4] Writing components/ui/purchase-order-dialog.tsx..."

if (Test-Path -LiteralPath $dialogPath) {
    Write-Skip "Already exists - $dialogPath"
    Write-Skip "Delete it first if you want this script to regenerate it."
} else {
    $dialogContent = @'
"use client";

import { useState } from "react";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";

type ItemRow = {
  id: string;
  rawMaterialId: string;
  qty: string;
  expectedUnitCost: string;
};

function emptyRow(defaultRawMaterialId: string): ItemRow {
  return {
    id: crypto.randomUUID(),
    rawMaterialId: defaultRawMaterialId,
    qty: "",
    expectedUnitCost: "",
  };
}

// Purchase Order create dialog (Phase 2 / Batch B2a): one Supplier + one
// PO Date + optional notes, one or more line items (raw material, qty
// ordered, expected unit cost). Creating a PO does NOT touch stock - it
// only reserves what's expected to arrive. Batch B2b will make this PO
// the only way to record an actual goods-received Purchase Receipt.
export function PurchaseOrderDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const addSupplier = useStore((s) => s.addSupplier);
  const createPurchaseOrder = useStore((s) => s.createPurchaseOrder);

  const today = new Date().toISOString().slice(0, 10);

  const [supplierId, setSupplierId] = useState(suppliers[0]?.id ?? "");
  const [poDate, setPoDate] = useState(today);
  const [notes, setNotes] = useState("");
  const [rows, setRows] = useState<ItemRow[]>([emptyRow(rawMaterials[0]?.id ?? "")]);
  const [showAddSupplier, setShowAddSupplier] = useState(false);
  const [newSupplierName, setNewSupplierName] = useState("");
  const [newSupplierPhone, setNewSupplierPhone] = useState("");
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (!open) return null;

  const resetAndClose = () => {
    setSupplierId(suppliers[0]?.id ?? "");
    setPoDate(today);
    setNotes("");
    setRows([emptyRow(rawMaterials[0]?.id ?? "")]);
    setShowAddSupplier(false);
    setNewSupplierName("");
    setNewSupplierPhone("");
    setFormError("");
    onClose();
  };

  const addRow = () => setRows((prev) => [...prev, emptyRow(rawMaterials[0]?.id ?? "")]);
  const removeRow = (id: string) =>
    setRows((prev) => (prev.length > 1 ? prev.filter((r) => r.id !== id) : prev));
  const updateRow = (id: string, patch: Partial<ItemRow>) =>
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  const handleInlineAddSupplier = async () => {
    if (!newSupplierName.trim() || !newSupplierPhone.trim()) return;
    try {
      const id = await addSupplier({ name: newSupplierName.trim(), phone: newSupplierPhone.trim() });
      setSupplierId(id);
      setNewSupplierName("");
      setNewSupplierPhone("");
      setShowAddSupplier(false);
      toast.success(`Supplier "${newSupplierName.trim()}" added`);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to add supplier");
    }
  };

  const runningTotal = rows.reduce(
    (sum, r) => sum + (Number(r.qty) || 0) * (Number(r.expectedUnitCost) || 0),
    0
  );

  const handleSubmit = async () => {
    setFormError("");

    if (!supplierId) {
      setFormError("Select or add a supplier");
      return;
    }
    if (!poDate) {
      setFormError("PO date is required");
      return;
    }

    const parsedItems: { rawMaterialId: string; qty: number; expectedUnitCost: number }[] = [];
    for (const row of rows) {
      const qty = Number(row.qty);
      const expectedUnitCost = Number(row.expectedUnitCost);
      if (!row.rawMaterialId) {
        setFormError("Select a raw material for every line");
        return;
      }
      if (!qty || qty <= 0) {
        setFormError("Every line needs a quantity greater than 0");
        return;
      }
      if (!expectedUnitCost || expectedUnitCost <= 0) {
        setFormError("Every line needs an expected unit cost greater than 0");
        return;
      }
      parsedItems.push({ rawMaterialId: row.rawMaterialId, qty, expectedUnitCost });
    }

    setSubmitting(true);
    try {
      const poNumber = await createPurchaseOrder({
        supplierId,
        poDate,
        notes: notes.trim() || undefined,
        items: parsedItems,
      });
      toast.success(`Purchase Order ${poNumber} created`);
      resetAndClose();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Failed to create purchase order");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-2xl rounded-2xl border border-[var(--surface-border)] bg-[var(--background)] p-6 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-[var(--foreground)]">New Purchase Order</h2>
          <button
            type="button"
            onClick={resetAndClose}
            className="rounded-lg px-2 py-1 text-sm text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
          >
            Close
          </button>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="text-xs text-[var(--text-muted)]">Supplier</label>
            <div className="mt-1 flex gap-2">
              <select
                value={supplierId}
                onChange={(e) => setSupplierId(e.target.value)}
                className="block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
              >
                <option value="">Select supplier</option>
                {suppliers.map((s) => (
                  <option key={s.id} value={s.id}>{s.name}</option>
                ))}
              </select>
              <button
                type="button"
                onClick={() => setShowAddSupplier((v) => !v)}
                className="shrink-0 rounded-lg border border-[var(--surface-border)] px-3 py-2 text-xs text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
              >
                + New
              </button>
            </div>
          </div>
          <div>
            <label className="text-xs text-[var(--text-muted)]">PO Date</label>
            <input
              value={poDate}
              onChange={(e) => setPoDate(e.target.value)}
              type="date"
              className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
          </div>
        </div>

        {showAddSupplier && (
          <div className="mt-3 flex flex-wrap items-end gap-2 rounded-lg border border-[var(--surface-border)] p-3">
            <div>
              <label className="text-xs text-[var(--text-muted)]">New supplier name</label>
              <input
                value={newSupplierName}
                onChange={(e) => setNewSupplierName(e.target.value)}
                className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
              />
            </div>
            <div>
              <label className="text-xs text-[var(--text-muted)]">Phone</label>
              <input
                value={newSupplierPhone}
                onChange={(e) => setNewSupplierPhone(e.target.value)}
                className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
              />
            </div>
            <button
              type="button"
              onClick={handleInlineAddSupplier}
              className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-3 py-2 text-xs font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90"
            >
              Add supplier
            </button>
          </div>
        )}

        <div className="mt-4">
          <label className="text-xs text-[var(--text-muted)]">Notes (optional)</label>
          <input
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="e.g. urgent, deliver by Friday"
            className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
        </div>

        <div className="mt-5">
          <div className="flex items-center justify-between">
            <label className="text-xs text-[var(--text-muted)]">Items</label>
            <button
              type="button"
              onClick={addRow}
              className="rounded-lg px-2 py-1 text-xs text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
            >
              + Add line
            </button>
          </div>

          <div className="mt-2 space-y-2">
            {rows.map((row) => (
              <div key={row.id} className="flex flex-wrap items-end gap-2 rounded-lg border border-[var(--surface-border)] p-3">
                <div className="min-w-[180px] flex-1">
                  <label className="text-xs text-[var(--text-muted)]">Raw material</label>
                  <select
                    value={row.rawMaterialId}
                    onChange={(e) => updateRow(row.id, { rawMaterialId: e.target.value })}
                    className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  >
                    <option value="">Select material</option>
                    {rawMaterials.map((m) => (
                      <option key={m.id} value={m.id}>{m.name} ({m.unit})</option>
                    ))}
                  </select>
                </div>
                <div className="w-28">
                  <label className="text-xs text-[var(--text-muted)]">Qty ordered</label>
                  <input
                    value={row.qty}
                    onChange={(e) => updateRow(row.id, { qty: e.target.value })}
                    type="number"
                    className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  />
                </div>
                <div className="w-32">
                  <label className="text-xs text-[var(--text-muted)]">Expected cost/unit</label>
                  <input
                    value={row.expectedUnitCost}
                    onChange={(e) => updateRow(row.id, { expectedUnitCost: e.target.value })}
                    type="number"
                    className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
                  />
                </div>
                <button
                  type="button"
                  onClick={() => removeRow(row.id)}
                  disabled={rows.length === 1}
                  className="rounded-lg px-2.5 py-2 text-xs text-red-500 hover:bg-red-500/10 disabled:opacity-40"
                >
                  Remove
                </button>
              </div>
            ))}
          </div>

          <div className="mt-2 text-right text-sm text-[var(--text-secondary)]">
            Estimated total: Rs. {runningTotal.toLocaleString()}
          </div>
        </div>

        {formError && <div className="mt-3 text-sm text-red-500">{formError}</div>}

        <div className="mt-5 flex justify-end gap-2">
          <button
            type="button"
            onClick={resetAndClose}
            className="rounded-lg px-3 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={submitting}
            onClick={handleSubmit}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 disabled:opacity-50"
          >
            {submitting ? "Creating..." : "Create Purchase Order"}
          </button>
        </div>
      </div>
    </div>
  );
}
'@
    if ($WhatIf) {
        Write-Skip "(WhatIf) Would write $dialogPath"
    } else {
        Write-FileUtf8NoBom -Path $dialogPath -Content $dialogContent
        Write-Ok "Created purchase-order-dialog.tsx"
    }
}

# =====================================================================
# [3/4] New file: purchase-orders/page.tsx
# =====================================================================
Write-Step "[3/4] Writing app/(dashboard)/purchase-orders/page.tsx..."

if (-not (Test-Path -LiteralPath $pageDir)) {
    if ($WhatIf) {
        Write-Skip "(WhatIf) Would create directory $pageDir"
    } else {
        New-Item -ItemType Directory -Path $pageDir -Force | Out-Null
    }
}

if (Test-Path -LiteralPath $pagePath) {
    Write-Skip "Already exists - $pagePath"
    Write-Skip "Delete it first if you want this script to regenerate it."
} else {
    $pageContent = @'
"use client";

import { Fragment, useEffect, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight, RefreshCw } from "lucide-react";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";
import { PurchaseOrderDialog } from "@/components/ui/purchase-order-dialog";
import type { PurchaseOrderStatus } from "@/lib/store";

const STATUS_STYLES: Record<PurchaseOrderStatus, string> = {
  draft: "bg-neutral-500/10 text-neutral-500",
  sent: "bg-blue-500/10 text-blue-500",
  partially_received: "bg-amber-500/10 text-amber-500",
  received: "bg-green-500/10 text-green-500",
  closed: "bg-neutral-500/10 text-neutral-400",
};

const STATUS_LABELS: Record<PurchaseOrderStatus, string> = {
  draft: "Draft",
  sent: "Sent",
  partially_received: "Partially Received",
  received: "Received",
  closed: "Closed",
};

export default function PurchaseOrdersPage() {
  const purchaseOrders = useStore((s) => s.purchaseOrders);
  const purchaseOrderLines = useStore((s) => s.purchaseOrderLines);
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const loadPurchaseOrders = useStore((s) => s.loadPurchaseOrders);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);

  useEffect(() => {
    loadPurchaseOrders();
    loadRawMaterialsModule();
  }, [loadPurchaseOrders, loadRawMaterialsModule]);

  const [search, setSearch] = useState("");
  const [supplierFilter, setSupplierFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState<PurchaseOrderStatus | "">("");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const handleRefresh = async () => {
    if (isRefreshing) return;
    setIsRefreshing(true);
    try {
      await loadPurchaseOrders();
      toast.success("Table refreshed");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to refresh");
    } finally {
      setIsRefreshing(false);
    }
  };

  const rows = useMemo(() => {
    return purchaseOrders
      .map((po) => {
        const lines = purchaseOrderLines.filter((l) => l.poId === po.id);
        const supplier = suppliers.find((s) => s.id === po.supplierId);
        const estimatedTotal = lines.reduce((sum, l) => sum + l.qtyOrdered * l.expectedUnitCost, 0);
        const outstandingQty = lines.reduce((sum, l) => sum + Math.max(0, l.qtyOrdered - l.qtyReceived), 0);
        const itemNames = lines.map((l) => rawMaterials.find((m) => m.id === l.rawMaterialId)?.name ?? "?");
        return { po, lines, supplier, estimatedTotal, outstandingQty, itemNames };
      })
      .filter(({ po, supplier, itemNames }) => {
        if (supplierFilter && po.supplierId !== supplierFilter) return false;
        if (statusFilter && po.status !== statusFilter) return false;
        if (search.trim()) {
          const q = search.trim().toLowerCase();
          const haystack = `${po.poNumber} ${supplier?.name ?? ""} ${itemNames.join(" ")}`.toLowerCase();
          if (!haystack.includes(q)) return false;
        }
        return true;
      })
      .sort((a, b) => b.po.poDate.localeCompare(a.po.poDate));
  }, [purchaseOrders, purchaseOrderLines, suppliers, rawMaterials, search, supplierFilter, statusFilter]);

  const hasFilters = !!(supplierFilter || statusFilter);

  return (
    <div className="p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold text-[var(--foreground)]">Purchase Orders</h1>
          <p className="text-sm text-[var(--text-muted)]">
            Nothing gets received into stock without a valid Purchase Order.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="rounded-lg border border-[var(--surface-border)] p-2 text-[var(--text-secondary)] hover:bg-[var(--surface-hover)] disabled:opacity-50"
            title="Refresh"
          >
            <RefreshCw size={16} className={isRefreshing ? "animate-spin" : ""} />
          </button>
          <button
            type="button"
            onClick={() => setDialogOpen(true)}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90"
          >
            New PO
          </button>
        </div>
      </div>

      <div className="mt-4 flex flex-wrap items-end gap-3">
        <div className="min-w-[200px] flex-1">
          <label className="text-xs text-[var(--text-muted)]">Search</label>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="PO number, supplier, item..."
            className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">Supplier</label>
          <select
            value={supplierFilter}
            onChange={(e) => setSupplierFilter(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          >
            <option value="">All suppliers</option>
            {suppliers.map((s) => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">Status</label>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as PurchaseOrderStatus | "")}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          >
            <option value="">All statuses</option>
            {(Object.keys(STATUS_LABELS) as PurchaseOrderStatus[]).map((s) => (
              <option key={s} value={s}>{STATUS_LABELS[s]}</option>
            ))}
          </select>
        </div>
        {hasFilters && (
          <button
            type="button"
            onClick={() => { setSupplierFilter(""); setStatusFilter(""); }}
            className="rounded-lg px-3 py-2 text-xs text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
          >
            Clear filters
          </button>
        )}
      </div>

      <div className="mt-4 overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[820px] text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium w-8"></th>
              <th className="px-4 py-3 font-medium">PO #</th>
              <th className="px-4 py-3 font-medium">Supplier</th>
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Outstanding Qty</th>
              <th className="px-4 py-3 font-medium">Estimated Total</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr><td colSpan={7} className="px-4 py-8 text-center text-[var(--text-faint)]">No purchase orders match these filters.</td></tr>
            )}
            {rows.map(({ po, lines, supplier, estimatedTotal, outstandingQty }) => {
              const isExpanded = expandedId === po.id;
              return (
                <Fragment key={po.id}>
                  <tr className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                    <td className="px-4 py-3">
                      <button type="button" onClick={() => setExpandedId(isExpanded ? null : po.id)} className="text-[var(--text-muted)] hover:text-[var(--foreground)]">
                        {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </td>
                    <td className="px-4 py-3 font-medium text-[var(--foreground)]">{po.poNumber}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">
                      {supplier ? (
                        <NavLink href={`/suppliers/${supplier.id}`} className="hover:underline text-[var(--foreground)]">{supplier.name}</NavLink>
                      ) : "-"}
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{po.poDate}</td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${STATUS_STYLES[po.status]}`}>
                        {STATUS_LABELS[po.status]}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{outstandingQty}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {estimatedTotal.toLocaleString()}</td>
                  </tr>
                  {isExpanded && (
                    <tr className="border-b border-[var(--surface-border)] last:border-0 bg-[var(--background)]">
                      <td></td>
                      <td colSpan={6} className="px-4 py-3">
                        {po.notes && (
                          <div className="mb-2 text-xs text-[var(--text-muted)]">Notes: {po.notes}</div>
                        )}
                        <table className="w-full text-xs">
                          <thead>
                            <tr className="text-left text-[var(--text-muted)]">
                              <th className="pb-2 font-medium">Raw Material</th>
                              <th className="pb-2 font-medium">Qty Ordered</th>
                              <th className="pb-2 font-medium">Qty Received</th>
                              <th className="pb-2 font-medium">Outstanding</th>
                              <th className="pb-2 font-medium">Expected Cost/Unit</th>
                            </tr>
                          </thead>
                          <tbody>
                            {lines.map((l) => {
                              const material = rawMaterials.find((m) => m.id === l.rawMaterialId);
                              return (
                                <tr key={l.id} className="border-t border-[var(--surface-border)]">
                                  <td className="py-2 text-[var(--text-secondary)]">
                                    {material ? (
                                      <NavLink href={`/raw-materials/${material.id}`} className="hover:underline text-[var(--foreground)]">{material.name}</NavLink>
                                    ) : "-"}
                                  </td>
                                  <td className="py-2 text-[var(--text-secondary)]">{l.qtyOrdered} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">{l.qtyReceived} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">{Math.max(0, l.qtyOrdered - l.qtyReceived)} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {l.expectedUnitCost.toLocaleString()}</td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>

      <PurchaseOrderDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@
    if ($WhatIf) {
        Write-Skip "(WhatIf) Would write $pagePath"
    } else {
        Write-FileUtf8NoBom -Path $pagePath -Content $pageContent
        Write-Ok "Created purchase-orders/page.tsx"
    }
}

# =====================================================================
# [4/4] Patch sidebar-component.tsx
# =====================================================================
Write-Step "[4/4] Patching components/ui/sidebar-component.tsx (add Purchase Orders link)..."

$sidebarContent = Get-Content -LiteralPath $sidebarPath -Raw

$anchorSidebar = '{ title: "Purchase Receipts", items: [{ icon: <FolderOpen size={16} className="text-[var(--foreground)]" />, label: "All Receipts", href: "/receipts" }] },'
$sidebarReplacement = '{ title: "Purchase Receipts", items: [{ icon: <FolderOpen size={16} className="text-[var(--foreground)]" />, label: "All Receipts", href: "/receipts" }] },
        { title: "Purchase Orders", items: [{ icon: <DocumentAdd size={16} className="text-[var(--foreground)]" />, label: "All Purchase Orders", href: "/purchase-orders" }] },'

if ($sidebarContent.Contains('href: "/purchase-orders"')) {
    Write-Skip "Purchase Orders sidebar link already present - skipping."
} elseif (-not $sidebarContent.Contains($anchorSidebar)) {
    Write-Fail "Anchor not found in sidebar-component.tsx. File may have changed - skipping this edit."
    Write-Fail "You can add the link manually next to the 'All Receipts' entry."
} else {
    $sidebarContent = $sidebarContent.Replace($anchorSidebar, $sidebarReplacement)
    if ($WhatIf) {
        Write-Skip "(WhatIf) Would write updated sidebar-component.tsx"
    } else {
        Write-FileUtf8NoBom -Path $sidebarPath -Content $sidebarContent
        Write-Ok "Added Purchase Orders link to sidebar (Receipts section)."
    }
}

Write-Host ""
Write-Host "Done. Batch B2a applied." -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd apps\frontend && npm run build   (sanity check - no TS errors)"
Write-Host "  2. Visit /purchase-orders in the app, create a test PO"
Write-Host "  3. Confirm with Supabase that a row landed in purchase_orders / purchase_order_lines"
Write-Host "  4. Once confirmed, ask for Batch B2b: make Purchase Receipt PO-required"