# ============================================================================
# GhaniFoods Frontend - Wire Raw Materials + Suppliers + Receipts to Supabase
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>
#   PS D:\...\GhaniFoods> .\wire-raw-materials-module.ps1
# Patches existing files in-place (no files overwritten wholesale) - your
# styling/UI stays exactly the same, only data-source wiring changes.
# ============================================================================

$ErrorActionPreference = "Stop"
$Root     = Get-Location
$Frontend = Join-Path $Root "apps\frontend"

function Patch-File {
    param(
        [string]$RelativePath,
        [string]$OldText,
        [string]$NewText,
        [string]$Label
    )
    $Path = Join-Path $Frontend $RelativePath
    if (-not (Test-Path $Path)) {
        Write-Host "==> SKIP ($Label): file not found -> $RelativePath" -ForegroundColor Red
        return
    }
    $raw = Get-Content -Path $Path -Raw
    $normalized = $raw -replace "`r`n", "`n"
    $oldNorm = $OldText -replace "`r`n", "`n"
    $newNorm = $NewText -replace "`r`n", "`n"

    if ($normalized.Contains($oldNorm)) {
        $patched = $normalized.Replace($oldNorm, $newNorm)
        Set-Content -Path $Path -Value $patched -Encoding UTF8 -NoNewline
        Write-Host "==> Patched: $Label" -ForegroundColor Green
    } else {
        Write-Host "==> SKIP ($Label): anchor text not found (already patched or file changed) -> $RelativePath" -ForegroundColor Yellow
    }
}

# ============================================================================
# 1. lib/store.ts - back Suppliers/RawMaterials/Receipts with real Supabase
# ============================================================================

Patch-File -RelativePath "lib\store.ts" -Label "store.ts: import supabase client + row mappers" `
  -OldText @'
import { persist } from "zustand/middleware";
'@ `
  -NewText @'
import { persist } from "zustand/middleware";
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

function mapSupplierRow(row: any): Supplier {
  return { id: row.id, name: row.name, phone: row.phone, address: row.address ?? undefined };
}
function mapRawMaterialRow(row: any): RawMaterial {
  return {
    id: row.id,
    name: row.name,
    unit: row.unit,
    quantityInStock: Number(row.quantity_in_stock),
    avgUnitCost: Number(row.avg_unit_cost),
    lowStockThreshold: Number(row.low_stock_threshold),
  };
}
function mapReceiptRow(row: any): PurchaseReceipt {
  return { id: row.id, supplierId: row.supplier_id, purchaseDate: row.purchase_date };
}
function mapReceiptLineRow(row: any): PurchaseReceiptLine {
  return { id: row.id, receiptId: row.receipt_id, rawMaterialId: row.raw_material_id, qty: Number(row.qty), cost: Number(row.cost) };
}
'@

Patch-File -RelativePath "lib\store.ts" -Label "store.ts: State type - async signatures + loadRawMaterialsModule" `
  -OldText @'
  addSupplier: (item: { name: string; phone: string; address?: string }) => string;

  // Raw materials + multi-item Purchase Receipts (FR-4 - FR-10)
  addRawMaterial: (item: { name: string; unit: string; lowStockThreshold: number }) => string;
  createPurchaseReceipt: (input: {
    supplierId: string;
    purchaseDate: string;
    items: { rawMaterialId: string; qty: number; cost: number }[];
  }) => string;
'@ `
  -NewText @'
  addSupplier: (item: { name: string; phone: string; address?: string }) => Promise<string>;

  // Raw materials + multi-item Purchase Receipts (FR-4 - FR-10)
  addRawMaterial: (item: { name: string; unit: string; lowStockThreshold: number }) => Promise<string>;
  createPurchaseReceipt: (input: {
    supplierId: string;
    purchaseDate: string;
    items: { rawMaterialId: string; qty: number; cost: number }[];
  }) => Promise<string>;
  loadRawMaterialsModule: () => Promise<void>;
'@

Patch-File -RelativePath "lib\store.ts" -Label "store.ts: real implementations (Supabase-backed)" `
  -OldText @'
      addSupplier: (item) => {
        const id = `sup-${Date.now()}`;
        set((s) => ({
          suppliers: [...s.suppliers, { id, name: item.name, phone: item.phone, address: item.address }],
        }));
        return id;
      },

      addRawMaterial: (item) => {
        const id = `rm-${Date.now()}`;
        set((s) => ({
          rawMaterials: [
            ...s.rawMaterials,
            { id, name: item.name, unit: item.unit, quantityInStock: 0, avgUnitCost: 0, lowStockThreshold: item.lowStockThreshold },
          ],
        }));
        return id;
      },

      // FR-5/FR-6/FR-7: one receipt header (Supplier, Purchase Date) with
      // one or more line items. Each line independently recalculates its
      // raw material's weighted-average cost:
      //   New Avg Cost = ((ExistingQty * ExistingAvg) + (NewQty * NewCost)) / (ExistingQty + NewQty)
      createPurchaseReceipt: (input) => {
        const id = `rcpt-${Date.now()}`;
        set((s) => {
          let rawMaterials = s.rawMaterials;
          const newLines: PurchaseReceiptLine[] = input.items.map((item, idx) => {
            rawMaterials = rawMaterials.map((m) => {
              if (m.id !== item.rawMaterialId) return m;
              const newQty = m.quantityInStock + item.qty;
              const newAvgCost = newQty > 0 ? (m.quantityInStock * m.avgUnitCost + item.qty * item.cost) / newQty : m.avgUnitCost;
              return { ...m, quantityInStock: newQty, avgUnitCost: Number(newAvgCost.toFixed(2)) };
            });
            return {
              id: `rline-${Date.now()}-${idx}`,
              receiptId: id,
              rawMaterialId: item.rawMaterialId,
              qty: item.qty,
              cost: item.cost,
            };
          });

          const receipt: PurchaseReceipt = { id, supplierId: input.supplierId, purchaseDate: input.purchaseDate };

          return {
            rawMaterials,
            receipts: [receipt, ...s.receipts],
            receiptLines: [...newLines, ...s.receiptLines],
          };
        });
        return id;
      },
'@ `
  -NewText @'
      addSupplier: async (item) => {
        const { data, error } = await supabase
          .from("suppliers")
          .insert({ name: item.name, phone: item.phone, address: item.address ?? null })
          .select()
          .single();
        if (error || !data) throw new Error(error?.message ?? "Failed to add supplier");
        const supplier = mapSupplierRow(data);
        set((s) => ({ suppliers: [...s.suppliers, supplier] }));
        return supplier.id;
      },

      addRawMaterial: async (item) => {
        const { data, error } = await supabase
          .from("raw_materials")
          .insert({ name: item.name, unit: item.unit, low_stock_threshold: item.lowStockThreshold })
          .select()
          .single();
        if (error || !data) throw new Error(error?.message ?? "Failed to add raw material");
        const material = mapRawMaterialRow(data);
        set((s) => ({ rawMaterials: [...s.rawMaterials, material] }));
        return material.id;
      },

      // FR-5/FR-6/FR-7: server-side RPC (fn_create_purchase_receipt) recalculates
      // each affected raw material's weighted-average cost atomically.
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

      loadRawMaterialsModule: async () => {
        const [suppliersRes, rawMaterialsRes, receiptsRes, receiptLinesRes] = await Promise.all([
          supabase.from("suppliers").select("*"),
          supabase.from("raw_materials").select("*"),
          supabase.from("purchase_receipts").select("*"),
          supabase.from("purchase_receipt_lines").select("*"),
        ]);
        set({
          suppliers: (suppliersRes.data ?? []).map(mapSupplierRow),
          rawMaterials: (rawMaterialsRes.data ?? []).map(mapRawMaterialRow),
          receipts: (receiptsRes.data ?? []).map(mapReceiptRow),
          receiptLines: (receiptLinesRes.data ?? []).map(mapReceiptLineRow),
        });
      },
'@

# ============================================================================
# 2. components/ui/purchase-receipt-dialog.tsx - await the async store calls
# ============================================================================

Patch-File -RelativePath "components\ui\purchase-receipt-dialog.tsx" -Label "purchase-receipt-dialog.tsx: inline add supplier -> await" `
  -OldText @'
  const handleInlineAddSupplier = () => {
    if (!newSupplierName.trim() || !newSupplierPhone.trim()) return;
    const id = addSupplier({ name: newSupplierName.trim(), phone: newSupplierPhone.trim() });
    setSupplierId(id);
    setNewSupplierName("");
    setNewSupplierPhone("");
    setShowAddSupplier(false);
    toast.success(`Supplier "${newSupplierName.trim()}" added`);
  };
'@ `
  -NewText @'
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
'@

Patch-File -RelativePath "components\ui\purchase-receipt-dialog.tsx" -Label "purchase-receipt-dialog.tsx: inline new raw material -> await" `
  -OldText @'
        let newId = existing?.id;
        if (!newId) {
          addRawMaterial({
            name: row.newName.trim(),
            unit: row.newUnit.trim(),
            lowStockThreshold: Number(row.newThreshold) || 0,
          });
          newId = useStore
            .getState()
            .rawMaterials.find((m) => m.name.toLowerCase() === row.newName.trim().toLowerCase())?.id;
        }
'@ `
  -NewText @'
        let newId = existing?.id;
        if (!newId) {
          try {
            newId = await addRawMaterial({
              name: row.newName.trim(),
              unit: row.newUnit.trim(),
              lowStockThreshold: Number(row.newThreshold) || 0,
            });
          } catch (err) {
            setFormError(err instanceof Error ? err.message : "Could not create the new raw material");
            return;
          }
        }
'@

Patch-File -RelativePath "components\ui\purchase-receipt-dialog.tsx" -Label "purchase-receipt-dialog.tsx: final submit -> await + error handling" `
  -OldText @'
    setSubmitting(true);
    createPurchaseReceipt({ supplierId, purchaseDate, items: parsedItems });
    const supplierName = suppliers.find((s) => s.id === supplierId)?.name ?? "supplier";
    toast.success(
      `Purchase receipt saved - ${parsedItems.length} item${parsedItems.length > 1 ? "s" : ""} from ${supplierName}`
    );
    setSubmitting(false);
    resetAndClose();
  };
'@ `
  -NewText @'
    setSubmitting(true);
    try {
      await createPurchaseReceipt({ supplierId, purchaseDate, items: parsedItems });
      const supplierName = suppliers.find((s) => s.id === supplierId)?.name ?? "supplier";
      toast.success(
        `Purchase receipt saved - ${parsedItems.length} item${parsedItems.length > 1 ? "s" : ""} from ${supplierName}`
      );
      resetAndClose();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : "Failed to save purchase receipt");
    } finally {
      setSubmitting(false);
    }
  };
'@

# ============================================================================
# 3. app/(dashboard)/raw-materials/page.tsx
# ============================================================================

Patch-File -RelativePath "app\(dashboard)\raw-materials\page.tsx" -Label "raw-materials/page.tsx: import useEffect" `
  -OldText 'import { Fragment, useMemo, useState } from "react";' `
  -NewText 'import { Fragment, useEffect, useMemo, useState } from "react";'

Patch-File -RelativePath "app\(dashboard)\raw-materials\page.tsx" -Label "raw-materials/page.tsx: add dialog await" `
  -OldText @'
  const onSubmit = async (values: RawMaterialMasterFormValues) => {
    addRawMaterial(values);
    toast.success(`Raw material "${values.name}" added - record a purchase to add stock`);
    reset();
    onClose();
  };
'@ `
  -NewText @'
  const onSubmit = async (values: RawMaterialMasterFormValues) => {
    try {
      await addRawMaterial(values);
      toast.success(`Raw material "${values.name}" added - record a purchase to add stock`);
      reset();
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to add raw material");
    }
  };
'@

Patch-File -RelativePath "app\(dashboard)\raw-materials\page.tsx" -Label "raw-materials/page.tsx: hydrate on mount" `
  -OldText @'
export default function RawMaterialsPage() {
  const rawMaterials = useStore((s) => s.rawMaterials);
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);

  const [search, setSearch] = useState("");
'@ `
  -NewText @'
export default function RawMaterialsPage() {
  const rawMaterials = useStore((s) => s.rawMaterials);
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);

  const [search, setSearch] = useState("");
'@

# ============================================================================
# 4. app/(dashboard)/raw-materials/[id]/page.tsx
# ============================================================================

Patch-File -RelativePath "app\(dashboard)\raw-materials\[id]\page.tsx" -Label "raw-materials/[id]: import useEffect" `
  -OldText 'import { use, useMemo, useState } from "react";' `
  -NewText 'import { use, useEffect, useMemo, useState } from "react";'

Patch-File -RelativePath "app\(dashboard)\raw-materials\[id]\page.tsx" -Label "raw-materials/[id]: hydrate on mount" `
  -OldText @'
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const [dialogOpen, setDialogOpen] = useState(false);
'@ `
  -NewText @'
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);
'@

# ============================================================================
# 5. app/(dashboard)/suppliers/page.tsx
# ============================================================================

Patch-File -RelativePath "app\(dashboard)\suppliers\page.tsx" -Label "suppliers/page.tsx: import useEffect" `
  -OldText 'import { useMemo, useState } from "react";' `
  -NewText 'import { useEffect, useMemo, useState } from "react";'

Patch-File -RelativePath "app\(dashboard)\suppliers\page.tsx" -Label "suppliers/page.tsx: add dialog await" `
  -OldText @'
  const onSubmit = async (values: SupplierFormValues) => {
    addSupplier(values);
    toast.success(`Supplier "${values.name}" added`);
    reset(); onClose();
  };
'@ `
  -NewText @'
  const onSubmit = async (values: SupplierFormValues) => {
    try {
      await addSupplier(values);
      toast.success(`Supplier "${values.name}" added`);
      reset(); onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to add supplier");
    }
  };
'@

Patch-File -RelativePath "app\(dashboard)\suppliers\page.tsx" -Label "suppliers/page.tsx: hydrate on mount" `
  -OldText @'
export default function SuppliersPage() {
  const suppliers = useStore((s) => s.suppliers);
  const receipts = useStore((s) => s.receipts);
  const [dialogOpen, setDialogOpen] = useState(false);
'@ `
  -NewText @'
export default function SuppliersPage() {
  const suppliers = useStore((s) => s.suppliers);
  const receipts = useStore((s) => s.receipts);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);
'@

# ============================================================================
# 6. app/(dashboard)/suppliers/[id]/page.tsx
# ============================================================================

Patch-File -RelativePath "app\(dashboard)\suppliers\[id]\page.tsx" -Label "suppliers/[id]: import useEffect" `
  -OldText 'import { Fragment, use, useMemo, useState } from "react";' `
  -NewText 'import { Fragment, use, useEffect, useMemo, useState } from "react";'

Patch-File -RelativePath "app\(dashboard)\suppliers\[id]\page.tsx" -Label "suppliers/[id]: hydrate on mount" `
  -OldText @'
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
'@ `
  -NewText @'
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const [expandedReceiptId, setExpandedReceiptId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);
'@

# ============================================================================
# 7. app/(dashboard)/receipts/page.tsx
# ============================================================================

Patch-File -RelativePath "app\(dashboard)\receipts\page.tsx" -Label "receipts/page.tsx: import useEffect" `
  -OldText 'import { Fragment, useMemo, useState } from "react";' `
  -NewText 'import { Fragment, useEffect, useMemo, useState } from "react";'

Patch-File -RelativePath "app\(dashboard)\receipts\page.tsx" -Label "receipts/page.tsx: hydrate on mount" `
  -OldText @'
export default function ReceiptsPage() {
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);

  const [supplierFilter, setSupplierFilter] = useState("");
'@ `
  -NewText @'
export default function ReceiptsPage() {
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);

  const [supplierFilter, setSupplierFilter] = useState("");
'@

Write-Host ""
Write-Host "==> DONE. Raw Materials + Suppliers + Receipts now read/write real Supabase data." -ForegroundColor Green
Write-Host "==> Any SKIP lines above mean that anchor text didn't match exactly - paste that output back and I'll adjust." -ForegroundColor Yellow
Write-Host "==> Test: cd apps\frontend; npm run dev -> log in -> /raw-materials, /suppliers, /receipts should show your seeded data." -ForegroundColor Cyan