# step2-form-validation.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\step2-form-validation.ps1
#
# Run AFTER step1-wire-dummy-data-store.ps1 and step1b-wire-remaining-pages.ps1.
#
# STEP 2 of the frontend completion plan — "Real client-side validation"
#
# What this does (frontend-only, dummy data only, NO backend calls):
#   1. Adds lib/schemas.ts — Zod schemas for every form in the app (matches
#      spec section 7: "Har form react-hook-form + Zod schema use karta hai")
#   2. Rewires every dialog/form to react-hook-form + zodResolver:
#        - Required-field, min-value, and type checks
#        - Inline red error text under each field
#        - Submit button shows "Saving..." and disables while submitting
#          (mirrors the spec's useFormStatus-style double-submit protection)
#   3. Covers: Add Raw Material, Record Purchase, Add Packaging Material,
#      Restock, Add Customer, Record Payment (all 3 places it appears),
#      New Batch (output yield / consumption rows), New Invoice (customer +
#      line items with live stock-qty check).

$ErrorActionPreference = "Stop"
$Root = Get-Location
$Frontend = Join-Path $Root "apps\frontend"

function Write-CodeFile {
    param([string]$RelativePath, [string]$Content)
    $fullPath = Join-Path $Frontend $RelativePath
    $dir = Split-Path $fullPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "  wrote $RelativePath" -ForegroundColor Green
}

$storePath = Join-Path $Frontend "lib\store.ts"
if (-not (Test-Path $storePath)) {
    Write-Host "ERROR: lib\store.ts not found. Run step1 scripts first." -ForegroundColor Red
    exit 1
}

Write-Host "=== Step 2: Form validation (react-hook-form + Zod) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# lib/schemas.ts
# ---------------------------------------------------------------------------
Write-CodeFile "lib\schemas.ts" @'
import { z } from "zod";

export const rawMaterialSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  unit: z.string().trim().min(1, "Unit is required"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
});
export type RawMaterialFormValues = z.infer<typeof rawMaterialSchema>;

export const purchaseSchema = z.object({
  qty: z.coerce.number().positive("Quantity must be greater than 0"),
  cost: z.coerce.number().positive("Cost must be greater than 0"),
});
export type PurchaseFormValues = z.infer<typeof purchaseSchema>;

export const packagingMaterialSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  unitCost: z.coerce.number().min(0, "Unit cost cannot be negative"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
});
export type PackagingMaterialFormValues = z.infer<typeof packagingMaterialSchema>;

export const restockSchema = z.object({
  qty: z.coerce.number().positive("Quantity must be greater than 0"),
  cost: z.coerce.number().min(0, "Cost cannot be negative").optional(),
});
export type RestockFormValues = z.infer<typeof restockSchema>;

export const customerSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  phone: z
    .string()
    .trim()
    .min(7, "Enter a valid phone number")
    .regex(/^[0-9+\-()\s]+$/, "Phone can only contain digits, spaces, + - ( )"),
  openingBalance: z.coerce.number(),
});
export type CustomerFormValues = z.infer<typeof customerSchema>;

export const paymentSchema = z.object({
  customerId: z.string().min(1, "Select a customer"),
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  note: z.string().trim().optional(),
});
export type PaymentFormValues = z.infer<typeof paymentSchema>;

export const batchSchema = z.object({
  outputYieldKg: z.coerce.number().positive("Output yield must be greater than 0"),
  wastageKg: z.coerce.number().min(0, "Wastage cannot be negative"),
});
export type BatchFormValues = z.infer<typeof batchSchema>;

export const overheadSchema = z.object({
  electricity: z.coerce.number().min(0, "Cannot be negative"),
  gas: z.coerce.number().min(0, "Cannot be negative"),
  rent: z.coerce.number().min(0, "Cannot be negative"),
});
export type OverheadFormValues = z.infer<typeof overheadSchema>;

export const invoiceHeaderSchema = z.object({
  customerId: z.string().min(1, "Select a customer"),
  margin: z.coerce.number().min(0, "Margin cannot be negative"),
});
export type InvoiceHeaderFormValues = z.infer<typeof invoiceHeaderSchema>;
'@

# ---------------------------------------------------------------------------
# Small shared field-error component pattern is inlined per-file (keeps this
# step dependency-free beyond what's already in package.json).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Raw Materials — list (Add Raw Material dialog -> RHF + Zod)
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\raw-materials\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { rawMaterialSchema, type RawMaterialFormValues } from "@/lib/schemas";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddRawMaterialDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<RawMaterialFormValues>({
    resolver: zodResolver(rawMaterialSchema),
    defaultValues: { name: "", unit: "kg", lowStockThreshold: 50 },
  });

  if (!open) return null;

  const onSubmit = async (values: RawMaterialFormValues) => {
    addRawMaterial(values);
    toast.success(`Raw material "${values.name}" added`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Raw Material</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input {...register("name")} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Unit of Purchase</label>
            <input {...register("unit")} placeholder="kg, litre, etc."
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.unit && <p className="text-xs text-red-400 mt-1">{errors.unit.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Low Stock Threshold</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">
            Cancel
          </button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function RawMaterialsPage() {
  const items = useStore((s) => s.rawMaterials);
  const [search, setSearch] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((m) => m.name.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Raw Materials</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Raw Material
        </button>
      </div>

      <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search raw materials..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600" />

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Unit</th>
              <th className="px-4 py-3 font-medium">Qty in Stock</th>
              <th className="px-4 py-3 font-medium">Avg Unit Cost</th>
              <th className="px-4 py-3 font-medium">Threshold</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((m) => {
              const isLow = m.quantityInStock < m.lowStockThreshold;
              return (
                <tr key={m.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                  <td className="px-4 py-3">
                    <Link href={`/raw-materials/${m.id}`} className="text-neutral-50 hover:underline">{m.name}</Link>
                  </td>
                  <td className="px-4 py-3 text-neutral-300">{m.unit}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.quantityInStock}</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {m.avgUnitCost.toLocaleString()}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.lowStockThreshold}</td>
                  <td className="px-4 py-3"><StatusBadge isLow={isLow} /></td>
                </tr>
              );
            })}
            {filtered.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-neutral-500">No raw materials found.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <AddRawMaterialDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Raw Material detail (Record Purchase dialog -> RHF + Zod)
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\raw-materials\[id]\page.tsx" @'
"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { purchaseSchema, type PurchaseFormValues } from "@/lib/schemas";

function RecordPurchaseDialog({ open, onClose, materialId }: { open: boolean; onClose: () => void; materialId: string }) {
  const recordPurchase = useStore((s) => s.recordPurchase);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PurchaseFormValues>({ resolver: zodResolver(purchaseSchema) });

  if (!open) return null;

  const onSubmit = async (values: PurchaseFormValues) => {
    recordPurchase(materialId, values.qty, values.cost);
    toast.success("Purchase recorded — average cost updated");
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Purchase</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Quantity</label>
            <input {...register("qty")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Purchase Cost (per unit)</label>
            <input {...register("cost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.cost && <p className="text-xs text-red-400 mt-1">{errors.cost.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
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
  const [dialogOpen, setDialogOpen] = useState(false);

  const receipts = useMemo(() => allReceipts.filter((r) => r.rawMaterialId === id), [allReceipts, id]);

  if (!material) {
    return (
      <div className="space-y-4">
        <Link href="/raw-materials" className="text-sm text-neutral-400 hover:underline">&larr; Back to Raw Materials</Link>
        <p className="text-neutral-400">Raw material not found.</p>
      </div>
    );
  }

  const isLow = material.quantityInStock < material.lowStockThreshold;

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/raw-materials" className="hover:underline text-neutral-300">Raw Materials</Link>{" "}
        / <span className="text-neutral-50">{material.name}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-neutral-50">{material.name}</h1>
            <p className="text-sm text-neutral-400 mt-1">Unit: {material.unit}</p>
          </div>
          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
            isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
          }`}>
            {isLow ? "Low Stock" : "OK"}
          </span>
        </div>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Current Stock</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{material.quantityInStock} {material.unit}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Avg Unit Cost</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {material.avgUnitCost.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Low Stock Threshold</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{material.lowStockThreshold}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Stock Value</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {(material.quantityInStock * material.avgUnitCost).toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-neutral-50">Purchase History</h2>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Record Purchase
        </button>
      </div>

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Quantity</th>
              <th className="px-4 py-3 font-medium">Cost / Unit</th>
              <th className="px-4 py-3 font-medium">Total</th>
            </tr>
          </thead>
          <tbody>
            {receipts.map((r) => (
              <tr key={r.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3 text-neutral-300">{r.date}</td>
                <td className="px-4 py-3 text-neutral-300">{r.qty} {material.unit}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {r.cost.toLocaleString()}</td>
                <td className="px-4 py-3 text-neutral-300">Rs. {(r.qty * r.cost).toLocaleString()}</td>
              </tr>
            ))}
            {receipts.length === 0 && (
              <tr><td colSpan={4} className="px-4 py-8 text-center text-neutral-500">No purchases recorded yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPurchaseDialog open={dialogOpen} onClose={() => setDialogOpen(false)} materialId={material.id} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Packaging (Add + Restock dialogs -> RHF + Zod)
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\packaging\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore, type PackagingMaterial } from "@/lib/store";
import { packagingMaterialSchema, restockSchema, type PackagingMaterialFormValues, type RestockFormValues } from "@/lib/schemas";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddPackagingDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addPackagingMaterial = useStore((s) => s.addPackagingMaterial);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PackagingMaterialFormValues>({
    resolver: zodResolver(packagingMaterialSchema),
    defaultValues: { name: "", unitCost: 0, lowStockThreshold: 50 },
  });

  if (!open) return null;

  const onSubmit = async (values: PackagingMaterialFormValues) => {
    addPackagingMaterial(values);
    toast.success(`Packaging material "${values.name}" added`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Packaging Material</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input {...register("name")} placeholder="e.g. Carton Box (Large)"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Unit Cost</label>
            <input {...register("unitCost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.unitCost && <p className="text-xs text-red-400 mt-1">{errors.unitCost.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Low Stock Threshold</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

function RestockDialog({ open, onClose, item }: { open: boolean; onClose: () => void; item: PackagingMaterial | null }) {
  const restockPackaging = useStore((s) => s.restockPackaging);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<RestockFormValues>({ resolver: zodResolver(restockSchema) });

  if (!open || !item) return null;

  const onSubmit = async (values: RestockFormValues) => {
    restockPackaging(item.id, values.qty, values.cost ?? 0);
    toast.success(`Restocked ${item.name}`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Restock: {item.name}</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Quantity to Add</label>
            <input {...register("qty")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Cost (per unit, optional)</label>
            <input {...register("cost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.cost && <p className="text-xs text-red-400 mt-1">{errors.cost.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function PackagingPage() {
  const items = useStore((s) => s.packagingMaterials);
  const [search, setSearch] = useState("");
  const [addOpen, setAddOpen] = useState(false);
  const [restockTarget, setRestockTarget] = useState<PackagingMaterial | null>(null);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((m) => m.name.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Packaging Materials</h1>
        <button onClick={() => setAddOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Packaging Material
        </button>
      </div>

      <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search packaging materials..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600" />

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Unit Cost</th>
              <th className="px-4 py-3 font-medium">Stock Qty</th>
              <th className="px-4 py-3 font-medium">Threshold</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((m) => {
              const isLow = m.stockQty < m.lowStockThreshold;
              return (
                <tr key={m.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                  <td className="px-4 py-3 text-neutral-50">{m.name}</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {m.unitCost.toLocaleString()}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.stockQty.toLocaleString()}</td>
                  <td className="px-4 py-3 text-neutral-300">{m.lowStockThreshold.toLocaleString()}</td>
                  <td className="px-4 py-3"><StatusBadge isLow={isLow} /></td>
                  <td className="px-4 py-3 text-right">
                    <button onClick={() => setRestockTarget(m)} className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800">
                      Restock
                    </button>
                  </td>
                </tr>
              );
            })}
            {filtered.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-neutral-500">No packaging materials found.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <AddPackagingDialog open={addOpen} onClose={() => setAddOpen(false)} />
      <RestockDialog open={!!restockTarget} onClose={() => setRestockTarget(null)} item={restockTarget} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Customers list (Add Customer dialog -> RHF + Zod)
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\customers\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { customerSchema, type CustomerFormValues } from "@/lib/schemas";

function BalanceCell({ balance }: { balance: number }) {
  const owes = balance > 0;
  const isZero = balance === 0;
  return (
    <span className={isZero ? "text-neutral-400" : owes ? "text-red-400" : "text-green-400"}>
      Rs. {Math.abs(balance).toLocaleString()} {!isZero && (owes ? "(owes)" : "(credit)")}
    </span>
  );
}

function AddCustomerDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addCustomer = useStore((s) => s.addCustomer);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<CustomerFormValues>({
    resolver: zodResolver(customerSchema),
    defaultValues: { name: "", phone: "", openingBalance: 0 },
  });

  if (!open) return null;

  const onSubmit = async (values: CustomerFormValues) => {
    addCustomer(values);
    toast.success(`Customer "${values.name}" added`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Customer</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input {...register("name")}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Phone</label>
            <input {...register("phone")} placeholder="0300-1234567"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.phone && <p className="text-xs text-red-400 mt-1">{errors.phone.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Opening Balance</label>
            <input {...register("openingBalance")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.openingBalance && <p className="text-xs text-red-400 mt-1">{errors.openingBalance.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function CustomersPage() {
  const items = useStore((s) => s.customers);
  const [search, setSearch] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((c) => c.name.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Customers</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Customer
        </button>
      </div>

      <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search customers..."
        className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600" />

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Phone</th>
              <th className="px-4 py-3 font-medium">Current Balance</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((c) => (
              <tr key={c.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3">
                  <Link href={`/customers/${c.id}`} className="text-neutral-50 hover:underline">{c.name}</Link>
                </td>
                <td className="px-4 py-3 text-neutral-300">{c.phone}</td>
                <td className="px-4 py-3"><BalanceCell balance={c.currentBalance} /></td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr><td colSpan={3} className="px-4 py-8 text-center text-neutral-500">No customers found.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <AddCustomerDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Customer detail (Record Payment dialog -> RHF + Zod)
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\customers\[id]\page.tsx" @'
"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { z } from "zod";

const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  note: z.string().trim().optional(),
});
type PaymentAmountValues = z.infer<typeof paymentAmountSchema>;

function RecordPaymentDialog({ open, onClose, customerId }: { open: boolean; onClose: () => void; customerId: string }) {
  const recordPayment = useStore((s) => s.recordPayment);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PaymentAmountValues>({ resolver: zodResolver(paymentAmountSchema) });

  if (!open) return null;

  const onSubmit = async (values: PaymentAmountValues) => {
    recordPayment(customerId, values.amount, values.note ?? "");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Amount</label>
            <input {...register("amount")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Note</label>
            <input {...register("note")}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function CustomerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const customer = useStore((s) => s.customers.find((c) => c.id === id));
  const allLedger = useStore((s) => s.ledgerEntries);
  const [dialogOpen, setDialogOpen] = useState(false);

  const ledger = useMemo(() => allLedger.filter((l) => l.customerId === id), [allLedger, id]);

  if (!customer) {
    return (
      <div className="space-y-4">
        <Link href="/customers" className="text-sm text-neutral-400 hover:underline">&larr; Back to Customers</Link>
        <p className="text-neutral-400">Customer not found.</p>
      </div>
    );
  }

  const totalInvoiced = ledger.filter((l) => l.type === "invoice").reduce((sum, l) => sum + l.amount, 0);
  const totalPaid = ledger.filter((l) => l.type === "payment").reduce((sum, l) => sum + Math.abs(l.amount), 0);

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/customers" className="hover:underline text-neutral-300">Customers</Link>{" "}
        / <span className="text-neutral-50">{customer.name}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <h1 className="text-xl font-semibold text-neutral-50">{customer.name}</h1>
        <p className="text-sm text-neutral-400 mt-1">{customer.phone}</p>

        <div className="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Current Balance</div>
            <div className={`text-lg font-semibold mt-1 ${customer.currentBalance > 0 ? "text-red-400" : "text-green-400"}`}>
              Rs. {Math.abs(customer.currentBalance).toLocaleString()}
            </div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Total Invoiced</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {totalInvoiced.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Total Paid</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {totalPaid.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          + Record Payment
        </button>
        <button onClick={() => router.push(`/invoices/new?customerId=${customer.id}`)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          New Invoice for this Customer
        </button>
      </div>

      <h2 className="text-lg font-semibold text-neutral-50">Ledger History</h2>
      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Note</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Running Balance</th>
            </tr>
          </thead>
          <tbody>
            {ledger.map((l) => (
              <tr key={l.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3 text-neutral-300">{l.date}</td>
                <td className="px-4 py-3 text-neutral-300 capitalize">{l.type}</td>
                <td className="px-4 py-3 text-neutral-300">{l.note}</td>
                <td className={`px-4 py-3 ${l.amount >= 0 ? "text-red-400" : "text-green-400"}`}>
                  {l.amount >= 0 ? "+" : ""}Rs. {l.amount.toLocaleString()}
                </td>
                <td className="px-4 py-3 text-neutral-300">Rs. {l.runningBalance.toLocaleString()}</td>
              </tr>
            ))}
            {ledger.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-neutral-500">No ledger entries yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={customer.id} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Payments page (Record Payment dialog -> RHF + Zod, customer select validated)
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\payments\page.tsx" @'
"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { paymentSchema, type PaymentFormValues } from "@/lib/schemas";

function RecordPaymentDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const customers = useStore((s) => s.customers);
  const recordPayment = useStore((s) => s.recordPayment);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PaymentFormValues>({
    resolver: zodResolver(paymentSchema),
    defaultValues: { customerId: customers[0]?.id ?? "", amount: 0, note: "" },
  });

  if (!open) return null;

  const onSubmit = async (values: PaymentFormValues) => {
    recordPayment(values.customerId, values.amount, values.note ?? "");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Customer</label>
            <select {...register("customerId")}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
              {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            {errors.customerId && <p className="text-xs text-red-400 mt-1">{errors.customerId.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Amount</label>
            <input {...register("amount")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Note</label>
            <input {...register("note")}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function PaymentsPage() {
  const items = useStore((s) => s.payments);
  const [dialogOpen, setDialogOpen] = useState(false);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Payments</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Record Payment
        </button>
      </div>

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Customer</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Note</th>
            </tr>
          </thead>
          <tbody>
            {items.map((p) => (
              <tr key={p.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3 text-neutral-300">{p.paidAt}</td>
                <td className="px-4 py-3 text-neutral-50">{p.customerName}</td>
                <td className="px-4 py-3 text-green-400">Rs. {p.amount.toLocaleString()}</td>
                <td className="px-4 py-3 text-neutral-300">{p.note}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Batches — new (output yield / wastage validated via RHF + Zod;
# dynamic consumption rows stay as local state since they're a repeatable
# list, not a single schema field)
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\batches\new\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { batchSchema, type BatchFormValues } from "@/lib/schemas";

type ConsumptionRow = { id: string; rawMaterialId: string; qty: string };

export default function NewBatchPage() {
  const router = useRouter();
  const rawMaterials = useStore((s) => s.rawMaterials);
  const productionBatches = useStore((s) => s.productionBatches);
  const createBatch = useStore((s) => s.createBatch);

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<BatchFormValues>({
    resolver: zodResolver(batchSchema),
    defaultValues: { outputYieldKg: 0, wastageKg: 0 },
  });
  const outputYield = watch("outputYieldKg");

  const [rows, setRows] = useState<ConsumptionRow[]>([
    { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "" },
  ]);
  const [rowError, setRowError] = useState("");
  const [useLeftoverFirst, setUseLeftoverFirst] = useState(false);
  const [leftoverBatchId, setLeftoverBatchId] = useState("");

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);

  const addRow = () => setRows((prev) => [...prev, { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "" }]);
  const removeRow = (id: string) => setRows((prev) => (prev.length > 1 ? prev.filter((r) => r.id !== id) : prev));
  const updateRow = (id: string, patch: Partial<ConsumptionRow>) =>
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  const estimatedCost = useMemo(() => {
    return rows.reduce((total, row) => {
      const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
      const qty = Number(row.qty) || 0;
      if (!material) return total;
      return total + qty * material.avgUnitCost;
    }, 0);
  }, [rows, rawMaterials]);

  const estimatedCostPerKg = useMemo(() => {
    const yieldKg = Number(outputYield) || 0;
    if (yieldKg <= 0) return 0;
    return estimatedCost / yieldKg;
  }, [estimatedCost, outputYield]);

  const onSubmit = async (values: BatchFormValues) => {
    setRowError("");
    const consumptions = rows
      .filter((r) => r.rawMaterialId && Number(r.qty) > 0)
      .map((r) => ({ rawMaterialId: r.rawMaterialId, qty: Number(r.qty) }));

    if (consumptions.length === 0) {
      setRowError("Add at least one raw material row with a quantity greater than 0");
      return;
    }

    const insufficient = consumptions.find((c) => {
      const m = rawMaterials.find((rm) => rm.id === c.rawMaterialId);
      return m && c.qty > m.quantityInStock;
    });
    if (insufficient) {
      setRowError("Not enough stock for one of the selected raw materials");
      return;
    }

    const newId = createBatch({ consumptions, outputYieldKg: values.outputYieldKg, wastageKg: values.wastageKg });
    toast.success(`Batch ${newId} created — raw material stock deducted`);
    router.push(`/batches/${newId}`);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-neutral-50">New Production Batch</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-neutral-200">Raw Material Consumption</h2>
          <button type="button" onClick={addRow} className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800">
            + Add Material Row
          </button>
        </div>

        <div className="space-y-3">
          {rows.map((row) => {
            const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
            return (
              <div key={row.id} className="space-y-1">
                <div className="flex items-center gap-2">
                  <select value={row.rawMaterialId} onChange={(e) => updateRow(row.id, { rawMaterialId: e.target.value })}
                    className="flex-1 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
                    {rawMaterials.map((m) => (
                      <option key={m.id} value={m.id}>{m.name} ({m.unit}) — {m.quantityInStock} in stock</option>
                    ))}
                  </select>
                  <input value={row.qty} onChange={(e) => updateRow(row.id, { qty: e.target.value })} type="number" placeholder="Qty"
                    className="w-28 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
                  <button type="button" onClick={() => removeRow(row.id)} className="rounded-lg border border-neutral-800 px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800">-</button>
                </div>
                {material && Number(row.qty) > material.quantityInStock && (
                  <p className="text-xs text-red-400">Only {material.quantityInStock} {material.unit} available</p>
                )}
              </div>
            );
          })}
          {rowError && <p className="text-xs text-red-400">{rowError}</p>}
        </div>

        <div className="rounded-lg border border-neutral-800 bg-neutral-950 p-4">
          <div className="text-xs text-neutral-400">Estimated Batch Cost</div>
          <div className="text-lg font-semibold text-neutral-50 mt-1">
            Rs. {estimatedCost.toLocaleString(undefined, { maximumFractionDigits: 2 })}
          </div>
          {Number(outputYield) > 0 && (
            <div className="text-xs text-neutral-400 mt-1">
              Est. cost/kg: Rs. {estimatedCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
            </div>
          )}
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label className="text-sm text-neutral-400">Output Yield (kg)</label>
          <input {...register("outputYieldKg")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.outputYieldKg && <p className="text-xs text-red-400 mt-1">{errors.outputYieldKg.message}</p>}
        </div>
        <div>
          <label className="text-sm text-neutral-400">Wastage (kg)</label>
          <input {...register("wastageKg")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.wastageKg && <p className="text-xs text-red-400 mt-1">{errors.wastageKg.message}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-3">
        <label className="flex items-center gap-3 cursor-pointer">
          <input type="checkbox" checked={useLeftoverFirst} onChange={(e) => setUseLeftoverFirst(e.target.checked)}
            className="size-4 rounded border-neutral-700 bg-neutral-950" />
          <span className="text-sm text-neutral-200">Use Leftover From Previous Batch First</span>
        </label>

        {useLeftoverFirst && (
          <select value={leftoverBatchId} onChange={(e) => setLeftoverBatchId(e.target.value)}
            className="w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
            <option value="">Select leftover batch...</option>
            {leftoverBatches.map((b) => (
              <option key={b.id} value={b.id}>{b.id} — {b.leftoverQtyKg} kg leftover</option>
            ))}
          </select>
        )}
      </div>

      <div className="flex justify-end gap-2">
        <button type="button" onClick={() => router.push("/batches")} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
        <button type="submit" disabled={isSubmitting}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
          {isSubmitting ? "Saving..." : "Save Batch"}
        </button>
      </div>
    </form>
  );
}
'@

# ---------------------------------------------------------------------------
# Batch detail — Overhead dialog -> RHF + Zod
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\batches\[id]\page.tsx" @'
"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { overheadSchema, type OverheadFormValues } from "@/lib/schemas";

function OverheadDialog({ open, onClose, batchId }: { open: boolean; onClose: () => void; batchId: string }) {
  const allocateOverhead = useStore((s) => s.allocateOverhead);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<OverheadFormValues>({
    resolver: zodResolver(overheadSchema),
    defaultValues: { electricity: 0, gas: 0, rent: 0 },
  });

  if (!open) return null;

  const onSubmit = async (values: OverheadFormValues) => {
    allocateOverhead(batchId, values.electricity, values.gas, values.rent);
    toast.success(`Overhead of Rs. ${(values.electricity + values.gas + values.rent).toLocaleString()} allocated to ${batchId}`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Allocate Month-End Overhead</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Electricity</label>
            <input {...register("electricity")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.electricity && <p className="text-xs text-red-400 mt-1">{errors.electricity.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Gas</label>
            <input {...register("gas")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.gas && <p className="text-xs text-red-400 mt-1">{errors.gas.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Rent</label>
            <input {...register("rent")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.rent && <p className="text-xs text-red-400 mt-1">{errors.rent.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function BatchDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const batch = useStore((s) => s.productionBatches.find((b) => b.id === id));
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!batch) {
    return (
      <div className="space-y-4">
        <Link href="/batches" className="text-sm text-neutral-400 hover:underline">&larr; Back to Batches</Link>
        <p className="text-neutral-400">Batch not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/batches" className="hover:underline text-neutral-300">Batches</Link>{" "}
        / <span className="text-neutral-50">{batch.id}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <h1 className="text-xl font-semibold text-neutral-50">{batch.id}</h1>
        <p className="text-sm text-neutral-400 mt-1">Batch Date: {batch.batchDate}</p>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Output Yield</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{batch.outputYieldKg} kg</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Wastage</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{batch.wastageKg} kg</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Leftover Remaining</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">{batch.leftoverQtyKg} kg</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Effective Cost/Kg</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">
              Rs. {batch.bulkCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
            </div>
          </div>
        </div>

        {batch.overheadTotal > 0 && (
          <div className="mt-4 text-xs text-amber-400">
            Overhead of Rs. {batch.overheadTotal.toLocaleString()} allocated across this batch's output.
          </div>
        )}
      </div>

      <div className="flex gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          Allocate Month-End Overhead
        </button>
        <button onClick={() => router.push(`/finished-cartons?batchId=${batch.id}`)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          Send to Packaging
        </button>
      </div>

      <OverheadDialog open={dialogOpen} onClose={() => setDialogOpen(false)} batchId={batch.id} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# Invoices — new (header via RHF + Zod; line items keep live stock checks)
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\invoices\new\page.tsx" @'
"use client";

import { Suspense, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { invoiceHeaderSchema, type InvoiceHeaderFormValues } from "@/lib/schemas";

type InvoiceLine = { id: string; itemId: string; qty: string; unitPrice: string };

function NewInvoiceForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const preselectedCustomerId = searchParams.get("customerId") ?? "";

  const customers = useStore((s) => s.customers);
  const finishedCartons = useStore((s) => s.finishedCartons);
  const lastSoldPrice = useStore((s) => s.lastSoldPrice);
  const createInvoice = useStore((s) => s.createInvoice);

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<InvoiceHeaderFormValues>({
    resolver: zodResolver(invoiceHeaderSchema),
    defaultValues: { customerId: preselectedCustomerId || customers[0]?.id || "", margin: 20 },
  });
  const customerId = watch("customerId");
  const margin = watch("margin");

  const [lines, setLines] = useState<InvoiceLine[]>([
    { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" },
  ]);
  const [lineError, setLineError] = useState("");

  const addLine = () => setLines((prev) => [...prev, { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" }]);
  const removeLine = (id: string) => setLines((prev) => (prev.length > 1 ? prev.filter((l) => l.id !== id) : prev));
  const updateLine = (id: string, patch: Partial<InvoiceLine>) =>
    setLines((prev) => prev.map((l) => (l.id === id ? { ...l, ...patch } : l)));

  const handleItemChange = (id: string, itemId: string) => {
    const carton = finishedCartons.find((c) => c.id === itemId);
    const memorized = lastSoldPrice(customerId, itemId);
    const marginMultiplier = 1 + (Number(margin) || 0) / 100;
    const fallback = carton ? Math.round(carton.costPerCarton * marginMultiplier) : 0;
    updateLine(id, { itemId, unitPrice: String(memorized ?? fallback) });
  };

  const total = useMemo(() => lines.reduce((sum, l) => sum + (Number(l.qty) || 0) * (Number(l.unitPrice) || 0), 0), [lines]);

  const onSubmit = async (values: InvoiceHeaderFormValues) => {
    setLineError("");
    const parsedLines = lines
      .filter((l) => l.itemId && Number(l.qty) > 0)
      .map((l) => ({ itemId: l.itemId, qty: Number(l.qty), unitPrice: Number(l.unitPrice) || 0 }));

    if (parsedLines.length === 0) {
      setLineError("Add at least one invoice item with a quantity greater than 0");
      return;
    }
    const insufficient = parsedLines.find((l) => {
      const c = finishedCartons.find((fc) => fc.id === l.itemId);
      return c && l.qty > c.stockQty;
    });
    if (insufficient) {
      setLineError("Not enough finished carton stock for one of the items");
      return;
    }
    const invalidPrice = parsedLines.find((l) => l.unitPrice <= 0);
    if (invalidPrice) {
      setLineError("Every line needs a unit price greater than 0");
      return;
    }

    const newId = createInvoice({ customerId: values.customerId, lines: parsedLines });
    toast.success(`Invoice ${newId} created — stock deducted, ledger updated`);
    router.push(`/invoices/${newId}`);
  };

  const selectedCustomer = customers.find((c) => c.id === customerId);

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-neutral-50">New Invoice</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div>
          <label className="text-sm text-neutral-400">Customer</label>
          <select {...register("customerId")}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
            {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          {errors.customerId && <p className="text-xs text-red-400 mt-1">{errors.customerId.message}</p>}
          {selectedCustomer && (
            <p className="text-xs text-neutral-500 mt-1">
              Current balance: Rs. {Math.abs(selectedCustomer.currentBalance).toLocaleString()}{" "}
              {selectedCustomer.currentBalance > 0 ? "(owes)" : "(credit)"}
            </p>
          )}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Margin % (used for items with no price history)</label>
          <input {...register("margin")} type="number" step="any"
            className="mt-1 w-40 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.margin && <p className="text-xs text-red-400 mt-1">{errors.margin.message}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-neutral-200">Invoice Items</h2>
          <button type="button" onClick={addLine} className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800">+ Add Item</button>
        </div>

        <div className="space-y-3">
          {lines.map((line) => {
            const memorized = lastSoldPrice(customerId, line.itemId);
            const carton = finishedCartons.find((c) => c.id === line.itemId);
            return (
              <div key={line.id} className="space-y-1">
                <div className="flex items-center gap-2">
                  <select value={line.itemId} onChange={(e) => handleItemChange(line.id, e.target.value)}
                    className="flex-1 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
                    {finishedCartons.map((c) => <option key={c.id} value={c.id}>{c.name} — {c.stockQty} in stock</option>)}
                  </select>
                  <input value={line.qty} onChange={(e) => updateLine(line.id, { qty: e.target.value })} type="number" placeholder="Qty"
                    className="w-20 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
                  <input value={line.unitPrice} onChange={(e) => updateLine(line.id, { unitPrice: e.target.value })} type="number" placeholder="Unit Price"
                    className="w-28 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
                  <button type="button" onClick={() => removeLine(line.id)} className="rounded-lg border border-neutral-800 px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800">-</button>
                </div>
                <div className="flex gap-2">
                  {memorized !== undefined && (
                    <span className="inline-block rounded-full bg-neutral-800 px-2.5 py-0.5 text-xs text-neutral-300">
                      Last price: Rs. {memorized.toLocaleString()}
                    </span>
                  )}
                  {carton && Number(line.qty) > carton.stockQty && (
                    <span className="inline-block rounded-full bg-red-950 border border-red-900 px-2.5 py-0.5 text-xs text-red-400">
                      Only {carton.stockQty} in stock
                    </span>
                  )}
                </div>
              </div>
            );
          })}
          {lineError && <p className="text-xs text-red-400">{lineError}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 flex items-center justify-between">
        <span className="text-sm text-neutral-400">Total</span>
        <span className="text-2xl font-semibold text-neutral-50">Rs. {total.toLocaleString()}</span>
      </div>

      <div className="flex justify-end gap-2">
        <button type="button" onClick={() => router.push("/invoices")} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
        <button type="submit" disabled={isSubmitting}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
          {isSubmitting ? "Saving..." : "Save & Generate Invoice"}
        </button>
      </div>
    </form>
  );
}

export default function NewInvoicePage() {
  return (
    <Suspense fallback={<div className="text-neutral-400 text-sm">Loading...</div>}>
      <NewInvoiceForm />
    </Suspense>
  );
}
'@

# ---------------------------------------------------------------------------
# Invoice detail — Record Payment dialog -> RHF + Zod
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\invoices\[id]\page.tsx" @'
"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { z } from "zod";

const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
});
type PaymentAmountValues = z.infer<typeof paymentAmountSchema>;

function RecordPaymentDialog({ open, onClose, customerId, customerName }: { open: boolean; onClose: () => void; customerId: string; customerName: string }) {
  const recordPayment = useStore((s) => s.recordPayment);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PaymentAmountValues>({ resolver: zodResolver(paymentAmountSchema) });

  if (!open) return null;

  const onSubmit = async (values: PaymentAmountValues) => {
    recordPayment(customerId, values.amount, "Payment against invoice");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded for ${customerName}`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment — {customerName}</h2>
        <div>
          <label className="text-sm text-neutral-400">Amount</label>
          <input {...register("amount")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function InvoiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const invoice = useStore((s) => s.invoices.find((i) => i.id === id));
  const [dialogOpen, setDialogOpen] = useState(false);

  if (!invoice) {
    return (
      <div className="space-y-4">
        <Link href="/invoices" className="text-sm text-neutral-400 hover:underline">&larr; Back to Invoices</Link>
        <p className="text-neutral-400">Invoice not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/invoices" className="hover:underline text-neutral-300">Invoices</Link>{" "}
        / <span className="text-neutral-50">{invoice.id}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-6 print:border-0">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-neutral-50">Invoice {invoice.id}</h1>
            <p className="text-sm text-neutral-400 mt-1">{invoice.invoiceDate}</p>
          </div>
          <div className="text-right">
            <div className="text-neutral-400 text-xs">Billed To</div>
            <div className="text-neutral-50 font-medium">{invoice.customerName}</div>
          </div>
        </div>

        <div className="mt-6 rounded-lg border border-neutral-800 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-neutral-800 bg-neutral-950 text-left text-neutral-400">
                <th className="px-4 py-2 font-medium">Item</th>
                <th className="px-4 py-2 font-medium">Qty</th>
                <th className="px-4 py-2 font-medium">Unit Price</th>
                <th className="px-4 py-2 font-medium">Subtotal</th>
              </tr>
            </thead>
            <tbody>
              {invoice.items.length > 0 ? (
                invoice.items.map((line, idx) => (
                  <tr key={idx}>
                    <td className="px-4 py-2 text-neutral-300">{line.itemName}</td>
                    <td className="px-4 py-2 text-neutral-300">{line.qty}</td>
                    <td className="px-4 py-2 text-neutral-300">Rs. {line.unitPrice.toLocaleString()}</td>
                    <td className="px-4 py-2 text-neutral-300">Rs. {line.subtotal.toLocaleString()}</td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td className="px-4 py-2 text-neutral-300">Nimko Carton (legacy record)</td>
                  <td className="px-4 py-2 text-neutral-300">-</td>
                  <td className="px-4 py-2 text-neutral-300">-</td>
                  <td className="px-4 py-2 text-neutral-300">Rs. {invoice.totalAmount.toLocaleString()}</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex justify-end">
          <div className="text-lg font-semibold text-neutral-50">Total: Rs. {invoice.totalAmount.toLocaleString()}</div>
        </div>
      </div>

      <div className="flex gap-2 print:hidden">
        <button onClick={() => window.print()} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">Print</button>
        <button onClick={() => toast.info("PDF generation is planned for a later step (needs backend rendering).")}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          Download PDF
        </button>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          Record Payment
        </button>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={invoice.customerId} customerName={invoice.customerName} />
    </div>
  );
}
'@

Write-Host "`n=== Step 2 complete ===" -ForegroundColor Cyan
Write-Host "Every dialog/form now validates with Zod + react-hook-form:" -ForegroundColor Green
Write-Host "  - Inline red error messages under each field" -ForegroundColor Yellow
Write-Host "  - Submit buttons show 'Saving...' and disable during submit" -ForegroundColor Yellow
Write-Host "  - Empty/negative/invalid values are rejected before hitting the store" -ForegroundColor Yellow
Write-Host "`nTest: try saving Add Raw Material with an empty name, or a negative threshold." -ForegroundColor Yellow