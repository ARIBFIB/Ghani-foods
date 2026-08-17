# step1-wire-dummy-data-store.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\step1-wire-dummy-data-store.ps1
#
# STEP 1 of the frontend completion plan — "Real dummy-data wiring"
#
# What this does (frontend-only, dummy data only, NO backend calls):
#   1. Installs zustand + sonner into apps/frontend
#   2. Adds lib/store.ts — a single shared in-memory (localStorage-persisted)
#      store that replaces the disconnected lib/mock-data/*.ts reads across
#      pages. All the real business rules now actually run:
#        - Recording a raw material purchase recalculates weighted avg cost
#        - Creating a batch deducts raw material stock + computes batch cost
#        - Allocating overhead permanently updates the batch's effective cost
#        - A packing run deducts batch leftover + packaging stock, adds
#          finished cartons
#        - Creating an invoice deducts finished carton stock, posts a debit
#          to the customer ledger, updates the customer's running balance,
#          AND updates CustomerItemPrice (so next invoice auto-fills price)
#        - Recording a payment posts a credit to the ledger + payments list
#   3. Adds a global <Toaster /> (sonner) and replaces alert()/fake "Saved."
#      text with real toast notifications across the app.
#   4. Rewires: dashboard, raw-materials (list+detail), packaging, batches
#      (list+new+detail), finished-cartons, customers (list+detail),
#      invoices (list+new+detail), payments — to read/write the store
#      instead of static mock-data imports.
#
# Still NOT done in this step (next steps): shadcn Dialog/Table components,
# react-hook-form + Zod validation, Recharts, TanStack Table sorting,
# CSV export, PDF generation, auth/middleware route protection.

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

Write-Host "=== Step 1: Wiring dummy-data store + toasts ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Install deps
# ---------------------------------------------------------------------------
Write-Host "`n--- Installing zustand + sonner in apps/frontend ---" -ForegroundColor Cyan
Push-Location $Frontend
npm install zustand sonner
Pop-Location

# ---------------------------------------------------------------------------
# lib/store.ts — the shared dummy-data source of truth
# ---------------------------------------------------------------------------
Write-CodeFile "lib\store.ts" @'
"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export type RawMaterial = {
  id: string;
  name: string;
  unit: string;
  quantityInStock: number;
  avgUnitCost: number;
  lowStockThreshold: number;
};

export type RawMaterialReceipt = {
  id: string;
  rawMaterialId: string;
  date: string;
  qty: number;
  cost: number;
};

export type PackagingMaterial = {
  id: string;
  name: string;
  unitCost: number;
  stockQty: number;
  lowStockThreshold: number;
};

export type ProductionBatch = {
  id: string;
  batchDate: string;
  outputYieldKg: number;
  wastageKg: number;
  leftoverQtyKg: number;
  bulkCostPerKg: number;
  overheadTotal: number;
  status: "in_progress" | "completed";
};

export type FinishedCarton = {
  id: string;
  name: string;
  sourceBatchId: string;
  packetsPerCarton: number;
  costPerCarton: number;
  stockQty: number;
};

export type Customer = {
  id: string;
  name: string;
  phone: string;
  currentBalance: number;
};

export type CustomerItemPrice = {
  customerId: string;
  itemId: string;
  lastSoldPrice: number;
};

export type InvoiceLineRecord = {
  itemId: string;
  itemName: string;
  qty: number;
  unitPrice: number;
  subtotal: number;
};

export type Invoice = {
  id: string;
  customerId: string;
  customerName: string;
  invoiceDate: string;
  totalAmount: number;
  status: "unpaid" | "partial" | "paid";
  items: InvoiceLineRecord[];
};

export type LedgerEntry = {
  id: string;
  customerId: string;
  type: "invoice" | "payment" | "adjustment";
  amount: number; // positive = debit (customer owes more), negative = credit
  runningBalance: number;
  date: string;
  note?: string;
};

export type Payment = {
  id: string;
  customerId: string;
  customerName: string;
  amount: number;
  note: string;
  paidAt: string;
};

// ---------------------------------------------------------------------------
// Initial dummy data (same shape/values as the original mock-data files)
// ---------------------------------------------------------------------------
const initialRawMaterials: RawMaterial[] = [
  { id: "rm-1", name: "Atta (Flour)", unit: "kg", quantityInStock: 420, avgUnitCost: 145.5, lowStockThreshold: 100 },
  { id: "rm-2", name: "Ghee", unit: "kg", quantityInStock: 65, avgUnitCost: 780, lowStockThreshold: 80 },
  { id: "rm-3", name: "Salt", unit: "kg", quantityInStock: 210, avgUnitCost: 28, lowStockThreshold: 50 },
  { id: "rm-4", name: "Spice Mix", unit: "kg", quantityInStock: 34, avgUnitCost: 620, lowStockThreshold: 40 },
];

const initialReceipts: RawMaterialReceipt[] = [
  { id: "r-1", rawMaterialId: "rm-1", date: "2026-08-12", qty: 200, cost: 142.0 },
  { id: "r-2", rawMaterialId: "rm-1", date: "2026-08-01", qty: 150, cost: 148.5 },
  { id: "r-3", rawMaterialId: "rm-1", date: "2026-07-20", qty: 100, cost: 146.0 },
];

const initialPackaging: PackagingMaterial[] = [
  { id: "pm-1", name: "Carton Box (Large)", unitCost: 45, stockQty: 320, lowStockThreshold: 100 },
  { id: "pm-2", name: "Shopper Bag", unitCost: 3.5, stockQty: 2400, lowStockThreshold: 500 },
  { id: "pm-3", name: "Dabbe (Tin)", unitCost: 22, stockQty: 150, lowStockThreshold: 60 },
];

const initialBatches: ProductionBatch[] = [
  { id: "batch-1", batchDate: "2026-08-10", outputYieldKg: 500, wastageKg: 8, leftoverQtyKg: 40, bulkCostPerKg: 210.75, overheadTotal: 0, status: "completed" },
  { id: "batch-2", batchDate: "2026-08-13", outputYieldKg: 480, wastageKg: 5, leftoverQtyKg: 480, bulkCostPerKg: 205.3, overheadTotal: 0, status: "completed" },
  { id: "batch-3", batchDate: "2026-08-16", outputYieldKg: 300, wastageKg: 0, leftoverQtyKg: 300, bulkCostPerKg: 0, overheadTotal: 0, status: "in_progress" },
];

const initialCartons: FinishedCarton[] = [
  { id: "fc-1", name: "Nimko Carton - 24pk", sourceBatchId: "batch-1", packetsPerCarton: 24, costPerCarton: 610, stockQty: 85 },
  { id: "fc-2", name: "Nimko Carton - 48pk", sourceBatchId: "batch-2", packetsPerCarton: 48, costPerCarton: 1150, stockQty: 42 },
];

const initialCustomers: Customer[] = [
  { id: "cust-1", name: "Al-Madina General Store", phone: "0300-1234567", currentBalance: 12500 },
  { id: "cust-2", name: "Bilal Traders", phone: "0333-9988776", currentBalance: -2000 },
  { id: "cust-3", name: "Rehman Wholesale", phone: "0345-1122334", currentBalance: 0 },
];

const initialItemPrices: CustomerItemPrice[] = [
  { customerId: "cust-1", itemId: "fc-1", lastSoldPrice: 640 },
  { customerId: "cust-2", itemId: "fc-2", lastSoldPrice: 1180 },
];

const initialInvoices: Invoice[] = [
  { id: "inv-1001", customerId: "cust-1", customerName: "Al-Madina General Store", invoiceDate: "2026-08-15", totalAmount: 18300, status: "partial", items: [] },
  { id: "inv-1002", customerId: "cust-2", customerName: "Bilal Traders", invoiceDate: "2026-08-14", totalAmount: 9200, status: "paid", items: [] },
  { id: "inv-1003", customerId: "cust-3", customerName: "Rehman Wholesale", invoiceDate: "2026-08-12", totalAmount: 4600, status: "unpaid", items: [] },
];

const initialLedger: LedgerEntry[] = [
  { id: "led-1", customerId: "cust-1", type: "adjustment", amount: 4000, runningBalance: 4000, date: "2026-07-01", note: "Opening balance" },
  { id: "led-2", customerId: "cust-1", type: "invoice", amount: 8700, runningBalance: 12700, date: "2026-08-05", note: "inv-1000" },
  { id: "led-3", customerId: "cust-1", type: "payment", amount: -5800, runningBalance: 6900, date: "2026-08-10", note: "Partial payment" },
  { id: "led-4", customerId: "cust-1", type: "invoice", amount: 18300, runningBalance: 25200, date: "2026-08-15", note: "inv-1001" },
  { id: "led-5", customerId: "cust-1", type: "payment", amount: -12700, runningBalance: 12500, date: "2026-08-16", note: "Partial payment" },
  { id: "led-6", customerId: "cust-2", type: "invoice", amount: 9200, runningBalance: 9200, date: "2026-08-14", note: "inv-1002" },
  { id: "led-7", customerId: "cust-2", type: "payment", amount: -9200, runningBalance: 0, date: "2026-08-15", note: "Full settlement" },
  { id: "led-8", customerId: "cust-2", type: "adjustment", amount: -2000, runningBalance: -2000, date: "2026-08-16", note: "Credit note" },
  { id: "led-9", customerId: "cust-3", type: "invoice", amount: 4600, runningBalance: 4600, date: "2026-08-12", note: "inv-1003" },
];

const initialPayments: Payment[] = [
  { id: "pay-1", customerId: "cust-2", customerName: "Bilal Traders", amount: 9200, note: "Full settlement inv-1002", paidAt: "2026-08-15" },
  { id: "pay-2", customerId: "cust-1", customerName: "Al-Madina General Store", amount: 5800, note: "Partial payment", paidAt: "2026-08-16" },
];

const today = () => new Date().toISOString().slice(0, 10);

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------
type State = {
  rawMaterials: RawMaterial[];
  receipts: RawMaterialReceipt[];
  packagingMaterials: PackagingMaterial[];
  productionBatches: ProductionBatch[];
  finishedCartons: FinishedCarton[];
  customers: Customer[];
  customerItemPrices: CustomerItemPrice[];
  invoices: Invoice[];
  ledgerEntries: LedgerEntry[];
  payments: Payment[];

  addRawMaterial: (item: { name: string; unit: string; lowStockThreshold: number }) => void;
  recordPurchase: (rawMaterialId: string, qty: number, cost: number) => void;

  addPackagingMaterial: (item: { name: string; unitCost: number; lowStockThreshold: number }) => void;
  restockPackaging: (materialId: string, qty: number, cost: number) => void;

  createBatch: (input: {
    consumptions: { rawMaterialId: string; qty: number }[];
    outputYieldKg: number;
    wastageKg: number;
  }) => string;
  allocateOverhead: (batchId: string, electricity: number, gas: number, rent: number) => void;

  createPackingRun: (input: {
    batchId: string;
    packagingMaterialId: string;
    packetsPerCarton: number;
    cartonQty: number;
    bulkKgUsed: number;
  }) => void;

  addCustomer: (item: { name: string; phone: string; openingBalance: number }) => string;
  recordPayment: (customerId: string, amount: number, note: string) => void;

  lastSoldPrice: (customerId: string, itemId: string) => number | undefined;
  createInvoice: (input: {
    customerId: string;
    lines: { itemId: string; qty: number; unitPrice: number }[];
  }) => string;
};

export const useStore = create<State>()(
  persist(
    (set, get) => ({
      rawMaterials: initialRawMaterials,
      receipts: initialReceipts,
      packagingMaterials: initialPackaging,
      productionBatches: initialBatches,
      finishedCartons: initialCartons,
      customers: initialCustomers,
      customerItemPrices: initialItemPrices,
      invoices: initialInvoices,
      ledgerEntries: initialLedger,
      payments: initialPayments,

      addRawMaterial: (item) =>
        set((s) => ({
          rawMaterials: [
            ...s.rawMaterials,
            {
              id: `rm-${Date.now()}`,
              name: item.name,
              unit: item.unit,
              quantityInStock: 0,
              avgUnitCost: 0,
              lowStockThreshold: item.lowStockThreshold,
            },
          ],
        })),

      recordPurchase: (rawMaterialId, qty, cost) =>
        set((s) => {
          const rawMaterials = s.rawMaterials.map((m) => {
            if (m.id !== rawMaterialId) return m;
            const newQty = m.quantityInStock + qty;
            // Weighted Average Cost formula (FR-2)
            const newAvgCost =
              newQty > 0 ? (m.quantityInStock * m.avgUnitCost + qty * cost) / newQty : m.avgUnitCost;
            return { ...m, quantityInStock: newQty, avgUnitCost: Number(newAvgCost.toFixed(2)) };
          });
          const receipts: RawMaterialReceipt[] = [
            { id: `r-${Date.now()}`, rawMaterialId, date: today(), qty, cost },
            ...s.receipts,
          ];
          return { rawMaterials, receipts };
        }),

      addPackagingMaterial: (item) =>
        set((s) => ({
          packagingMaterials: [
            ...s.packagingMaterials,
            {
              id: `pm-${Date.now()}`,
              name: item.name,
              unitCost: item.unitCost,
              stockQty: 0,
              lowStockThreshold: item.lowStockThreshold,
            },
          ],
        })),

      restockPackaging: (materialId, qty, cost) =>
        set((s) => ({
          packagingMaterials: s.packagingMaterials.map((m) => {
            if (m.id !== materialId) return m;
            const newQty = m.stockQty + qty;
            const newCost = cost > 0 ? (m.stockQty * m.unitCost + qty * cost) / newQty : m.unitCost;
            return { ...m, stockQty: newQty, unitCost: Number(newCost.toFixed(2)) };
          }),
        })),

      createBatch: (input) => {
        const id = `batch-${Date.now()}`;
        set((s) => {
          // Deduct raw material stock, compute total input cost (FR-6, FR-7)
          let totalCost = 0;
          const rawMaterials = s.rawMaterials.map((m) => {
            const line = input.consumptions.find((c) => c.rawMaterialId === m.id);
            if (!line) return m;
            totalCost += line.qty * m.avgUnitCost;
            return { ...m, quantityInStock: Math.max(0, m.quantityInStock - line.qty) };
          });

          const bulkCostPerKg = input.outputYieldKg > 0 ? totalCost / input.outputYieldKg : 0;

          const newBatch: ProductionBatch = {
            id,
            batchDate: today(),
            outputYieldKg: input.outputYieldKg,
            wastageKg: input.wastageKg,
            leftoverQtyKg: input.outputYieldKg, // all output starts as leftover until packed
            bulkCostPerKg: Number(bulkCostPerKg.toFixed(2)),
            overheadTotal: 0,
            status: "in_progress",
          };

          return { rawMaterials, productionBatches: [newBatch, ...s.productionBatches] };
        });
        return id;
      },

      allocateOverhead: (batchId, electricity, gas, rent) =>
        set((s) => ({
          productionBatches: s.productionBatches.map((b) => {
            if (b.id !== batchId) return b;
            const overheadTotal = electricity + gas + rent;
            const perKg = b.outputYieldKg > 0 ? overheadTotal / b.outputYieldKg : 0;
            return {
              ...b,
              overheadTotal,
              bulkCostPerKg: Number((b.bulkCostPerKg + perKg).toFixed(2)),
            };
          }),
        })),

      createPackingRun: (input) =>
        set((s) => {
          const batch = s.productionBatches.find((b) => b.id === input.batchId);
          const packaging = s.packagingMaterials.find((p) => p.id === input.packagingMaterialId);
          if (!batch) return {};

          const bulkCostShare = batch.bulkCostPerKg * input.bulkKgUsed;
          const packagingCostShare = (packaging?.unitCost ?? 0) * input.cartonQty;
          const costPerCarton = input.cartonQty > 0 ? (bulkCostShare + packagingCostShare) / input.cartonQty : 0;

          const productionBatches = s.productionBatches.map((b) =>
            b.id === input.batchId
              ? { ...b, leftoverQtyKg: Math.max(0, b.leftoverQtyKg - input.bulkKgUsed), status: "completed" as const }
              : b
          );

          const packagingMaterials = s.packagingMaterials.map((p) =>
            p.id === input.packagingMaterialId
              ? { ...p, stockQty: Math.max(0, p.stockQty - input.cartonQty) }
              : p
          );

          const newCarton: FinishedCarton = {
            id: `fc-${Date.now()}`,
            name: `${batch.id} Carton - ${input.packetsPerCarton}pk`,
            sourceBatchId: batch.id,
            packetsPerCarton: input.packetsPerCarton,
            costPerCarton: Number(costPerCarton.toFixed(2)),
            stockQty: input.cartonQty,
          };

          return {
            productionBatches,
            packagingMaterials,
            finishedCartons: [...s.finishedCartons, newCarton],
          };
        }),

      addCustomer: (item) => {
        const id = `cust-${Date.now()}`;
        set((s) => ({
          customers: [...s.customers, { id, name: item.name, phone: item.phone, currentBalance: item.openingBalance }],
        }));
        return id;
      },

      recordPayment: (customerId, amount, note) =>
        set((s) => {
          const customer = s.customers.find((c) => c.id === customerId);
          if (!customer) return {};
          const newBalance = customer.currentBalance - amount;

          const customers = s.customers.map((c) => (c.id === customerId ? { ...c, currentBalance: newBalance } : c));

          const ledgerEntries: LedgerEntry[] = [
            ...s.ledgerEntries,
            {
              id: `led-${Date.now()}`,
              customerId,
              type: "payment",
              amount: -amount,
              runningBalance: newBalance,
              date: today(),
              note: note || "Payment received",
            },
          ];

          const payments: Payment[] = [
            {
              id: `pay-${Date.now()}`,
              customerId,
              customerName: customer.name,
              amount,
              note: note || "Payment received",
              paidAt: today(),
            },
            ...s.payments,
          ];

          return { customers, ledgerEntries, payments };
        }),

      lastSoldPrice: (customerId, itemId) =>
        get().customerItemPrices.find((p) => p.customerId === customerId && p.itemId === itemId)?.lastSoldPrice,

      createInvoice: (input) => {
        const id = `inv-${1000 + get().invoices.length + 1}`;
        set((s) => {
          const customer = s.customers.find((c) => c.id === input.customerId);
          if (!customer) return {};

          // Build line items + deduct finished carton stock (FR-21)
          const items: InvoiceLineRecord[] = [];
          const finishedCartons = s.finishedCartons.map((c) => {
            const line = input.lines.find((l) => l.itemId === c.id);
            if (!line) return c;
            items.push({
              itemId: c.id,
              itemName: c.name,
              qty: line.qty,
              unitPrice: line.unitPrice,
              subtotal: line.qty * line.unitPrice,
            });
            return { ...c, stockQty: Math.max(0, c.stockQty - line.qty) };
          });

          const totalAmount = items.reduce((sum, l) => sum + l.subtotal, 0);

          // Update CustomerItemPrice memory (FR-20)
          const customerItemPrices = [...s.customerItemPrices];
          for (const line of input.lines) {
            const idx = customerItemPrices.findIndex(
              (p) => p.customerId === input.customerId && p.itemId === line.itemId
            );
            if (idx >= 0) customerItemPrices[idx] = { ...customerItemPrices[idx], lastSoldPrice: line.unitPrice };
            else customerItemPrices.push({ customerId: input.customerId, itemId: line.itemId, lastSoldPrice: line.unitPrice });
          }

          // Post debit to ledger + update running balance (FR-23)
          const newBalance = customer.currentBalance + totalAmount;
          const customers = s.customers.map((c) => (c.id === input.customerId ? { ...c, currentBalance: newBalance } : c));
          const ledgerEntries: LedgerEntry[] = [
            ...s.ledgerEntries,
            {
              id: `led-${Date.now()}`,
              customerId: input.customerId,
              type: "invoice",
              amount: totalAmount,
              runningBalance: newBalance,
              date: today(),
              note: id,
            },
          ];

          const newInvoice: Invoice = {
            id,
            customerId: input.customerId,
            customerName: customer.name,
            invoiceDate: today(),
            totalAmount,
            status: "unpaid",
            items,
          };

          return {
            finishedCartons,
            customerItemPrices,
            customers,
            ledgerEntries,
            invoices: [newInvoice, ...s.invoices],
          };
        });
        return id;
      },
    }),
    { name: "ghanifoods-dummy-data" }
  )
);
'@

# ---------------------------------------------------------------------------
# app/layout.tsx — add global <Toaster />
# ---------------------------------------------------------------------------
Write-CodeFile "app\layout.tsx" @'
import type { Metadata } from "next";
import "./globals.css";
import { Toaster } from "sonner";

export const metadata: Metadata = {
  title: "GhaniFoods",
  description: "Nimko / Snack Foods Production & Distribution System",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        {children}
        <Toaster theme="dark" position="top-right" richColors />
      </body>
    </html>
  );
}
'@

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-4">
      <div className="text-neutral-400 text-sm">{label}</div>
      <div className="text-2xl font-semibold text-neutral-50 mt-1">{value}</div>
    </div>
  );
}

function StatusBadge({ status }: { status: "unpaid" | "partial" | "paid" }) {
  const styles: Record<string, string> = {
    paid: "bg-green-950 text-green-400 border border-green-900",
    partial: "bg-amber-950 text-amber-400 border border-amber-900",
    unpaid: "bg-red-950 text-red-400 border border-red-900",
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${styles[status]}`}>
      {status[0].toUpperCase() + status.slice(1)}
    </span>
  );
}

function AddRawMaterialDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const [name, setName] = useState("");
  const [unit, setUnit] = useState("kg");
  const [threshold, setThreshold] = useState("50");

  if (!open) return null;

  const handleSave = () => {
    if (!name.trim()) return;
    addRawMaterial({ name: name.trim(), unit, lowStockThreshold: Number(threshold) || 0 });
    toast.success(`Raw material "${name.trim()}" added`);
    setName("");
    setUnit("kg");
    setThreshold("50");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Raw Material</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Unit of Purchase</label>
            <input value={unit} onChange={(e) => setUnit(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Low Stock Threshold</label>
            <input value={threshold} onChange={(e) => setThreshold(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const rawMaterials = useStore((s) => s.rawMaterials);
  const packagingMaterials = useStore((s) => s.packagingMaterials);
  const invoices = useStore((s) => s.invoices);
  const finishedCartons = useStore((s) => s.finishedCartons);
  const customers = useStore((s) => s.customers);
  const [dialogOpen, setDialogOpen] = useState(false);

  const lowStockItems = useMemo(() => {
    const rawAlerts = rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold }));
    const packagingAlerts = packagingMaterials
      .filter((p) => p.stockQty < p.lowStockThreshold)
      .map((p) => ({ id: p.id, name: p.name, href: `/packaging`, qty: p.stockQty, threshold: p.lowStockThreshold }));
    return [...rawAlerts, ...packagingAlerts];
  }, [rawMaterials, packagingMaterials]);

  const kpis = useMemo(() => {
    const totalRawMaterialValue = rawMaterials.reduce((sum, m) => sum + m.quantityInStock * m.avgUnitCost, 0);
    const finishedCartonsReady = finishedCartons.reduce((sum, c) => sum + c.stockQty, 0);
    const totalReceivables = customers.reduce((sum, c) => sum + Math.max(0, c.currentBalance), 0);
    return { totalRawMaterialValue, finishedCartonsReady, totalReceivables };
  }, [rawMaterials, finishedCartons, customers]);

  const recentInvoices = invoices.slice(0, 5);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Dashboard</h1>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Total Raw Material Value" value={`Rs. ${kpis.totalRawMaterialValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}`} />
        <KpiCard label="Batches This Month" value={6} />
        <KpiCard label="Finished Cartons Ready" value={kpis.finishedCartonsReady} />
        <KpiCard label="Total Receivables" value={`Rs. ${kpis.totalReceivables.toLocaleString()}`} />
      </div>

      <div className="flex flex-wrap gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          + Add Raw Material
        </button>
        <button onClick={() => router.push("/batches/new")} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          + New Batch
        </button>
        <button onClick={() => router.push("/invoices/new")} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + New Invoice
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="rounded-xl border border-neutral-800 bg-neutral-900 overflow-hidden">
          <div className="px-4 py-3 border-b border-neutral-800">
            <h2 className="text-sm font-semibold text-neutral-200">Low Stock Alerts</h2>
          </div>
          <div className="divide-y divide-neutral-900">
            {lowStockItems.length === 0 && (
              <div className="px-4 py-6 text-center text-sm text-neutral-500">All stock levels are healthy.</div>
            )}
            {lowStockItems.map((item) => (
              <Link key={item.id} href={item.href} className="flex items-center justify-between px-4 py-3 hover:bg-neutral-800/60">
                <span className="text-sm text-neutral-50">{item.name}</span>
                <span className="text-xs text-red-400">{item.qty} / {item.threshold}</span>
              </Link>
            ))}
          </div>
        </div>

        <div className="rounded-xl border border-neutral-800 bg-neutral-900 overflow-hidden">
          <div className="px-4 py-3 border-b border-neutral-800 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-neutral-200">Recent Invoices</h2>
            <Link href="/invoices" className="text-xs text-neutral-400 hover:text-neutral-200 hover:underline">View all</Link>
          </div>
          <table className="w-full text-sm">
            <tbody>
              {recentInvoices.map((inv) => (
                <tr key={inv.id} className="border-b border-neutral-900 last:border-0">
                  <td className="px-4 py-3">
                    <Link href={`/invoices/${inv.id}`} className="text-neutral-50 hover:underline">{inv.id}</Link>
                  </td>
                  <td className="px-4 py-3 text-neutral-300">{inv.customerName}</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {inv.totalAmount.toLocaleString()}</td>
                  <td className="px-4 py-3"><StatusBadge status={inv.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <AddRawMaterialDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

Write-Host "`n=== Dashboard + store + toaster wired ===" -ForegroundColor Cyan
Write-Host "Run part 2 next: .\step1b-wire-remaining-pages.ps1" -ForegroundColor Yellow