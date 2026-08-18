# Phase2-Suppliers-RawMaterials.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\Phase2-Suppliers-RawMaterials.ps1
#
# PHASE 2 of 5 - Suppliers module + Raw Materials update + Sidebar nav
#
# Adds:
#   - app/(dashboard)/suppliers/page.tsx           (NEW)
#   - app/(dashboard)/suppliers/[id]/page.tsx      (NEW)
# Updates:
#   - app/(dashboard)/raw-materials/page.tsx       (Add dialog: Supplier combobox + date picker)
#   - app/(dashboard)/raw-materials/[id]/page.tsx  (Supplier column + Record Purchase dialog)
#   - components/ui/sidebar-component.tsx          (adds "suppliers" section + nav item)
#
# Still pending after this: packaging pages, finished-cartons packing run,
# dashboard/topbar/reports packagingMaterials references (Phase 3-5).

$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$AppDash = Join-Path $ProjectRoot "apps\frontend\app\(dashboard)"
$Components = Join-Path $ProjectRoot "apps\frontend\components\ui"

if (-not (Test-Path $AppDash)) {
    Write-Host "ERROR: apps\frontend\app\(dashboard) not found. Run this script from the GhaniFoods root." -ForegroundColor Red
    exit 1
}

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Host "=== Phase 2: Suppliers module + Raw Materials update ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. app/(dashboard)/suppliers/page.tsx  (NEW)
# ---------------------------------------------------------------------------
$suppliersListContent = @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Supplier } from "@/lib/store";
import { supplierSchema, type SupplierFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function AddSupplierDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addSupplier = useStore((s) => s.addSupplier);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<SupplierFormValues>({
    resolver: zodResolver(supplierSchema),
    defaultValues: { name: "", phone: "", address: "" },
  });
  if (!open) return null;
  const onSubmit = async (values: SupplierFormValues) => {
    addSupplier(values);
    toast.success(`Supplier "${values.name}" added`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Supplier</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Phone</label>
            <input {...register("phone")} placeholder="0300-1234567"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.phone && <p className="text-xs text-red-400 mt-1">{errors.phone.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Address (optional)</label>
            <input {...register("address")}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function SuppliersPage() {
  const suppliers = useStore((s) => s.suppliers);
  const receipts = useStore((s) => s.receipts);
  const [dialogOpen, setDialogOpen] = useState(false);

  type Row = Supplier & { totalPurchases: number; lastPurchaseDate: string };

  const rows = useMemo<Row[]>(() => {
    return suppliers.map((sup) => {
      const supReceipts = receipts.filter((r) => r.supplierId === sup.id);
      const lastPurchaseDate = supReceipts.length > 0
        ? supReceipts.map((r) => r.purchaseDate).sort().reverse()[0]
        : "-";
      return { ...sup, totalPurchases: supReceipts.length, lastPurchaseDate };
    });
  }, [suppliers, receipts]);

  const columns = useMemo<ColumnDef<Row, unknown>[]>(() => [
    {
      accessorKey: "name", header: "Name",
      cell: ({ row }) => <Link href={`/suppliers/${row.original.id}`} className="text-[var(--foreground)] hover:underline">{row.original.name}</Link>,
    },
    { accessorKey: "phone", header: "Phone" },
    { accessorKey: "totalPurchases", header: "Total Purchases" },
    { accessorKey: "lastPurchaseDate", header: "Last Purchase Date" },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Suppliers</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Add Supplier
        </button>
      </div>
      <SortableTable data={rows} columns={columns} globalFilterPlaceholder="Search suppliers..." />
      <AddSupplierDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

$suppliersListPath = Join-Path $AppDash "suppliers\page.tsx"
Write-Utf8NoBom -Path $suppliersListPath -Content $suppliersListContent
Write-Host "  [1/5] Wrote app\(dashboard)\suppliers\page.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. app/(dashboard)/suppliers/[id]/page.tsx  (NEW)
# ---------------------------------------------------------------------------
$supplierDetailContent = @'
"use client";

import { use, useMemo } from "react";
import Link from "next/link";
import { useStore } from "@/lib/store";

export default function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const rawMaterials = useStore((s) => s.rawMaterials);

  const receipts = useMemo(
    () => allReceipts.filter((r) => r.supplierId === id).sort((a, b) => b.purchaseDate.localeCompare(a.purchaseDate)),
    [allReceipts, id]
  );

  const totalLifetimeValue = useMemo(
    () => receipts.reduce((sum, r) => sum + r.qty * r.cost, 0),
    [receipts]
  );

  if (!supplier) {
    return (
      <div className="space-y-4">
        <Link href="/suppliers" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Suppliers</Link>
        <p className="text-[var(--text-muted)]">Supplier not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <Link href="/suppliers" className="hover:underline text-[var(--text-secondary)]">Suppliers</Link>{" "}
        / <span className="text-[var(--foreground)]">{supplier.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">{supplier.name}</h1>
        <p className="text-sm text-[var(--text-muted)] mt-1">{supplier.phone}</p>
        {supplier.address && <p className="text-sm text-[var(--text-muted)]">{supplier.address}</p>}

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Receipts</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{receipts.length}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Lifetime Value</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {totalLifetimeValue.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Raw Material</th>
              <th className="px-4 py-3 font-medium">Quantity</th>
              <th className="px-4 py-3 font-medium">Cost / Unit</th>
              <th className="px-4 py-3 font-medium">Total</th>
            </tr>
          </thead>
          <tbody>
            {receipts.map((r) => {
              const material = rawMaterials.find((m) => m.id === r.rawMaterialId);
              return (
                <tr key={r.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{r.purchaseDate}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">
                    {material ? (
                      <Link href={`/raw-materials/${material.id}`} className="hover:underline text-[var(--foreground)]">{material.name}</Link>
                    ) : "-"}
                  </td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{r.qty} {material?.unit ?? ""}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {r.cost.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {(r.qty * r.cost).toLocaleString()}</td>
                </tr>
              );
            })}
            {receipts.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-[var(--text-faint)]">No purchases recorded yet for this supplier.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
'@

$supplierDetailPath = Join-Path $AppDash "suppliers\[id]\page.tsx"
Write-Utf8NoBom -Path $supplierDetailPath -Content $supplierDetailContent
Write-Host "  [2/5] Wrote app\(dashboard)\suppliers\[id]\page.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. app/(dashboard)/raw-materials/page.tsx  (UPDATE)
# ---------------------------------------------------------------------------
$rawMaterialsListContent = @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { z } from "zod";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type RawMaterial } from "@/lib/store";
import { SortableTable } from "@/components/ui/sortable-table";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

// Purchase-receipt style form: raw material name + unit (new material only),
// supplier (existing or inline "+ Add Supplier"), purchase date, qty, cost.
const addFlowSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  unit: z.string().trim().min(1, "Unit is required"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
  supplierId: z.string().min(1, "Select or add a supplier"),
  purchaseDate: z.string().min(1, "Purchase date is required"),
  qty: z.coerce.number().positive("Quantity must be greater than 0"),
  cost: z.coerce.number().positive("Cost must be greater than 0"),
});
type AddFlowValues = z.infer<typeof addFlowSchema>;

function AddRawMaterialDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const recordPurchase = useStore((s) => s.recordPurchase);
  const suppliers = useStore((s) => s.suppliers);
  const addSupplier = useStore((s) => s.addSupplier);
  const rawMaterials = useStore((s) => s.rawMaterials);

  const [showAddSupplier, setShowAddSupplier] = useState(false);
  const [newSupplierName, setNewSupplierName] = useState("");
  const [newSupplierPhone, setNewSupplierPhone] = useState("");

  const today = new Date().toISOString().slice(0, 10);

  const { register, handleSubmit, control, reset, setValue, formState: { errors, isSubmitting } } = useForm<AddFlowValues>({
    resolver: zodResolver(addFlowSchema),
    defaultValues: { name: "", unit: "kg", lowStockThreshold: 50, supplierId: suppliers[0]?.id ?? "", purchaseDate: today, qty: 0, cost: 0 },
  });

  if (!open) return null;

  const handleInlineAddSupplier = () => {
    if (!newSupplierName.trim() || !newSupplierPhone.trim()) return;
    const id = addSupplier({ name: newSupplierName.trim(), phone: newSupplierPhone.trim() });
    setValue("supplierId", id);
    setNewSupplierName("");
    setNewSupplierPhone("");
    setShowAddSupplier(false);
    toast.success(`Supplier "${newSupplierName.trim()}" added`);
  };

  const onSubmit = async (values: AddFlowValues) => {
    let materialId = rawMaterials.find((m) => m.name.toLowerCase() === values.name.trim().toLowerCase())?.id;
    if (!materialId) {
      addRawMaterial({ name: values.name.trim(), unit: values.unit, lowStockThreshold: values.lowStockThreshold });
      materialId = useStore.getState().rawMaterials.find((m) => m.name.toLowerCase() === values.name.trim().toLowerCase())?.id;
    }
    if (materialId) {
      recordPurchase(materialId, values.qty, values.cost, values.supplierId, values.purchaseDate);
    }
    toast.success(`Raw material "${values.name.trim()}" - purchase recorded`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Raw Material (Purchase Receipt)</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Unit (only used if this is a new material)</label>
            <input {...register("unit")} placeholder="kg, litre, etc."
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.unit && <p className="text-xs text-red-400 mt-1">{errors.unit.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Low Stock Threshold (new material only)</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>

          <div className="border-t border-[var(--surface-border)] pt-3">
            <label className="text-sm text-[var(--text-muted)]">Supplier</label>
            <Controller
              control={control}
              name="supplierId"
              render={({ field }) => (
                <select {...field}
                  className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                  <option value="">Select supplier...</option>
                  {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              )}
            />
            {errors.supplierId && <p className="text-xs text-red-400 mt-1">{errors.supplierId.message}</p>}
            <button type="button" onClick={() => setShowAddSupplier((v) => !v)} className="text-xs text-[var(--text-muted)] hover:text-[var(--foreground)] hover:underline mt-1">
              + Add Supplier
            </button>
            {showAddSupplier && (
              <div className="mt-2 space-y-2 rounded-lg border border-[var(--surface-border)] p-3">
                <input value={newSupplierName} onChange={(e) => setNewSupplierName(e.target.value)} placeholder="Supplier name"
                  className="w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                <input value={newSupplierPhone} onChange={(e) => setNewSupplierPhone(e.target.value)} placeholder="Phone"
                  className="w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                <button type="button" onClick={handleInlineAddSupplier} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
                  Save Supplier
                </button>
              </div>
            )}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Purchase Date</label>
            <input {...register("purchaseDate")} type="date"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.purchaseDate && <p className="text-xs text-red-400 mt-1">{errors.purchaseDate.message}</p>}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm text-[var(--text-muted)]">Quantity</label>
              <input {...register("qty")} type="number" step="any"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
            </div>
            <div>
              <label className="text-sm text-[var(--text-muted)]">Cost per unit</label>
              <input {...register("cost")} type="number" step="any"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.cost && <p className="text-xs text-red-400 mt-1">{errors.cost.message}</p>}
            </div>
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function RawMaterialsPage() {
  const items = useStore((s) => s.rawMaterials);
  const [dialogOpen, setDialogOpen] = useState(false);

  const columns = useMemo<ColumnDef<RawMaterial, unknown>[]>(() => [
    {
      accessorKey: "name",
      header: "Name",
      cell: ({ row }) => (
        <Link href={`/raw-materials/${row.original.id}`} className="text-[var(--foreground)] hover:underline">
          {row.original.name}
        </Link>
      ),
    },
    { accessorKey: "unit", header: "Unit" },
    {
      accessorKey: "quantityInStock",
      header: "Qty in Stock",
      cell: ({ getValue }) => <span>{getValue() as number}</span>,
    },
    {
      accessorKey: "avgUnitCost",
      header: "Avg Unit Cost",
      cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}`,
    },
    { accessorKey: "lowStockThreshold", header: "Threshold" },
    {
      id: "status",
      header: "Status",
      cell: ({ row }) => <StatusBadge isLow={row.original.quantityInStock < row.original.lowStockThreshold} />,
      enableSorting: false,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Raw Materials</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Add Raw Material
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search raw materials..." />
      <AddRawMaterialDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

$rawMaterialsListPath = Join-Path $AppDash "raw-materials\page.tsx"
Write-Utf8NoBom -Path $rawMaterialsListPath -Content $rawMaterialsListContent
Write-Host "  [3/5] Wrote app\(dashboard)\raw-materials\page.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. app/(dashboard)/raw-materials/[id]/page.tsx  (UPDATE)
# ---------------------------------------------------------------------------
$rawMaterialDetailContent = @'
"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { purchaseSchema, type PurchaseFormValues } from "@/lib/schemas";

function RecordPurchaseDialog({ open, onClose, materialId }: { open: boolean; onClose: () => void; materialId: string }) {
  const recordPurchase = useStore((s) => s.recordPurchase);
  const suppliers = useStore((s) => s.suppliers);
  const today = new Date().toISOString().slice(0, 10);

  const {
    register,
    handleSubmit,
    control,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PurchaseFormValues>({
    resolver: zodResolver(purchaseSchema),
    defaultValues: { supplierId: suppliers[0]?.id ?? "", purchaseDate: today, qty: 0, cost: 0 },
  });

  if (!open) return null;

  const onSubmit = async (values: PurchaseFormValues) => {
    recordPurchase(materialId, values.qty, values.cost, values.supplierId, values.purchaseDate);
    toast.success("Purchase recorded - average cost updated");
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Purchase</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Supplier</label>
            <Controller
              control={control}
              name="supplierId"
              render={({ field }) => (
                <select {...field}
                  className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                  <option value="">Select supplier...</option>
                  {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              )}
            />
            {errors.supplierId && <p className="text-xs text-red-400 mt-1">{errors.supplierId.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Purchase Date</label>
            <input {...register("purchaseDate")} type="date"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.purchaseDate && <p className="text-xs text-red-400 mt-1">{errors.purchaseDate.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Quantity</label>
            <input {...register("qty")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Purchase Cost (per unit)</label>
            <input {...register("cost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.cost && <p className="text-xs text-red-400 mt-1">{errors.cost.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function RawMaterialDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const suppliers = useStore((s) => s.suppliers);
  const [dialogOpen, setDialogOpen] = useState(false);

  const receipts = useMemo(() => allReceipts.filter((r) => r.rawMaterialId === id), [allReceipts, id]);

  if (!material) {
    return (
      <div className="space-y-4">
        <Link href="/raw-materials" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Raw Materials</Link>
        <p className="text-[var(--text-muted)]">Raw material not found.</p>
      </div>
    );
  }

  const isLow = material.quantityInStock < material.lowStockThreshold;

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <Link href="/raw-materials" className="hover:underline text-[var(--text-secondary)]">Raw Materials</Link>{" "}
        / <span className="text-[var(--foreground)]">{material.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-[var(--foreground)]">{material.name}</h1>
            <p className="text-sm text-[var(--text-muted)] mt-1">Unit: {material.unit}</p>
          </div>
          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
            isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
          }`}>
            {isLow ? "Low Stock" : "OK"}
          </span>
        </div>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Current Stock</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{material.quantityInStock} {material.unit}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Avg Unit Cost</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {material.avgUnitCost.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Low Stock Threshold</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{material.lowStockThreshold}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Stock Value</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {(material.quantityInStock * material.avgUnitCost).toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Supplier</th>
              <th className="px-4 py-3 font-medium">Quantity</th>
              <th className="px-4 py-3 font-medium">Cost / Unit</th>
              <th className="px-4 py-3 font-medium">Total</th>
            </tr>
          </thead>
          <tbody>
            {receipts.map((r) => {
              const supplier = suppliers.find((s) => s.id === r.supplierId);
              return (
                <tr key={r.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{r.purchaseDate}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">
                    {supplier ? (
                      <Link href={`/suppliers/${supplier.id}`} className="hover:underline text-[var(--foreground)]">{supplier.name}</Link>
                    ) : "-"}
                  </td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{r.qty} {material.unit}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {r.cost.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {(r.qty * r.cost).toLocaleString()}</td>
                </tr>
              );
            })}
            {receipts.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-[var(--text-faint)]">No purchases recorded yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPurchaseDialog open={dialogOpen} onClose={() => setDialogOpen(false)} materialId={material.id} />
    </div>
  );
}
'@

$rawMaterialDetailPath = Join-Path $AppDash "raw-materials\[id]\page.tsx"
Write-Utf8NoBom -Path $rawMaterialDetailPath -Content $rawMaterialDetailContent
Write-Host "  [4/5] Wrote app\(dashboard)\raw-materials\[id]\page.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. components/ui/sidebar-component.tsx  (UPDATE - add suppliers nav)
# ---------------------------------------------------------------------------
$sidebarPath = Join-Path $Components "sidebar-component.tsx"
if (Test-Path $sidebarPath) {
    $sidebarText = [System.IO.File]::ReadAllText($sidebarPath)

    $sidebarText = $sidebarText -replace '(type SectionId =\s*\r?\n\s*\| "dashboard")', '$1' + "`r`n  | `"suppliers`""

    $sidebarText = $sidebarText -replace '(const SECTION_DEFAULT_ROUTE: Record<SectionId, string> = \{\r?\n\s*dashboard: "/",)', '$1' + "`r`n  suppliers: `"/suppliers`","

    $sidebarText = $sidebarText -replace '(const ROUTE_PREFIXES: Array<\[string, SectionId\]> = \[\r?\n)', '$1  ["/suppliers", "suppliers"],' + "`r`n"

    $suppliersContentBlock = @'
    suppliers: {
      title: "Suppliers",
      sections: [
        { title: "Suppliers", items: [{ icon: <UserMultiple size={16} className="text-[var(--foreground)]" />, label: "All Suppliers", href: "/suppliers" }] },
      ],
    },

'@
    $sidebarText = $sidebarText -replace '(\s*batches: \{\r?\n\s*title: "Production Batches",)', ("`r`n" + $suppliersContentBlock + '$1')

    $sidebarText = $sidebarText -replace '(\{ id: "raw-materials", icon: <Folder size=\{16\} />, label: "Raw Materials" \},)', '$1' + "`r`n    { id: `"suppliers`", icon: <UserMultiple size={16} />, label: `"Suppliers`" },"

    $sidebarText = $sidebarText -replace '(\{ id: "raw-materials", icon: <Folder size=\{18\} />, label: "Raw Materials" \},)', '$1' + "`r`n    { id: `"suppliers`", icon: <UserMultiple size={18} />, label: `"Suppliers`" },"

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($sidebarPath, $sidebarText, $utf8NoBom)
    Write-Host "  [5/5] Updated components\ui\sidebar-component.tsx (added Suppliers nav)" -ForegroundColor Green
} else {
    Write-Host "  [5/5] WARNING: sidebar-component.tsx not found, skipped" -ForegroundColor Yellow
}

Write-Host "`n=== Phase 2 complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "DONE in this script:" -ForegroundColor Yellow
Write-Host "  - suppliers/page.tsx        : NEW - list + Add Supplier dialog" -ForegroundColor Gray
Write-Host "  - suppliers/[id]/page.tsx   : NEW - detail + purchase history (links to raw material)" -ForegroundColor Gray
Write-Host "  - raw-materials/page.tsx    : Add dialog now records a full purchase receipt" -ForegroundColor Gray
Write-Host "                                 (name/unit/threshold + Supplier combobox + inline add + date picker + qty/cost)" -ForegroundColor Gray
Write-Host "  - raw-materials/[id]/page.tsx : Purchase history table now shows Supplier column (links to supplier)," -ForegroundColor Gray
Write-Host "                                 Record Purchase dialog now requires Supplier + date" -ForegroundColor Gray
Write-Host "  - sidebar-component.tsx     : Added 'Suppliers' nav item (desktop icon rail, mobile section nav, detail sidebar)" -ForegroundColor Gray
Write-Host ""
Write-Host "NOT done yet (Phase 3-5):" -ForegroundColor Yellow
Write-Host "  - packaging/page.tsx                (still uses old packagingMaterials - REWRITE needed)" -ForegroundColor Gray
Write-Host "  - packaging/carton-config/page.tsx  (NEW - not created yet)" -ForegroundColor Gray
Write-Host "  - finished-cartons/page.tsx         (still uses old createPackingRun shape - REWRITE needed)" -ForegroundColor Gray
Write-Host "  - dashboard page.tsx, topbar.tsx, reports/page.tsx (still reference packagingMaterials)" -ForegroundColor Gray
Write-Host ""
Write-Host "WARNING: project STILL will not build cleanly - packaging/finished-cartons/dashboard/" -ForegroundColor Red
Write-Host "topbar/reports pages reference the removed 'packagingMaterials'. Phase 3 fixes packaging + carton-config." -ForegroundColor Red