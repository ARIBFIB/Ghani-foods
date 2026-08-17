# step3-complete-frontend.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\step3-complete-frontend.ps1
#
# STEP 3 - Final frontend completion (dummy data only, no backend calls)

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
    Write-Host "ERROR: lib\store.ts not found. Run step1 + step2 scripts first." -ForegroundColor Red
    exit 1
}

Write-Host "=== Step 3: Final frontend completion ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. lib/store.ts
# ---------------------------------------------------------------------------
Write-Host "`n--- 1. Adding settings slice to store ---" -ForegroundColor Cyan

Write-CodeFile "lib\store.ts" @'
"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

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
  amount: number;
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

export type AppSettings = {
  businessName: string;
  address: string;
  invoiceFooterText: string;
  defaultProfitMarginPercent: number;
  lowStockThresholdDefault: number;
};

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

const initialSettings: AppSettings = {
  businessName: "GhaniFoods",
  address: "Mansehra, Khyber Pakhtunkhwa, Pakistan",
  invoiceFooterText: "Thank you for your business!",
  defaultProfitMarginPercent: 20,
  lowStockThresholdDefault: 50,
};

const today = () => new Date().toISOString().slice(0, 10);

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
  settings: AppSettings;

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

  updateSettings: (patch: Partial<AppSettings>) => void;
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
      settings: initialSettings,

      addRawMaterial: (item) =>
        set((s) => ({
          rawMaterials: [
            ...s.rawMaterials,
            { id: `rm-${Date.now()}`, name: item.name, unit: item.unit, quantityInStock: 0, avgUnitCost: 0, lowStockThreshold: item.lowStockThreshold },
          ],
        })),

      recordPurchase: (rawMaterialId, qty, cost) =>
        set((s) => {
          const rawMaterials = s.rawMaterials.map((m) => {
            if (m.id !== rawMaterialId) return m;
            const newQty = m.quantityInStock + qty;
            const newAvgCost = newQty > 0 ? (m.quantityInStock * m.avgUnitCost + qty * cost) / newQty : m.avgUnitCost;
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
            { id: `pm-${Date.now()}`, name: item.name, unitCost: item.unitCost, stockQty: 0, lowStockThreshold: item.lowStockThreshold },
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
          let totalCost = 0;
          const rawMaterials = s.rawMaterials.map((m) => {
            const line = input.consumptions.find((c) => c.rawMaterialId === m.id);
            if (!line) return m;
            totalCost += line.qty * m.avgUnitCost;
            return { ...m, quantityInStock: Math.max(0, m.quantityInStock - line.qty) };
          });
          const bulkCostPerKg = input.outputYieldKg > 0 ? totalCost / input.outputYieldKg : 0;
          const newBatch: ProductionBatch = {
            id, batchDate: today(), outputYieldKg: input.outputYieldKg, wastageKg: input.wastageKg,
            leftoverQtyKg: input.outputYieldKg, bulkCostPerKg: Number(bulkCostPerKg.toFixed(2)),
            overheadTotal: 0, status: "in_progress",
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
            return { ...b, overheadTotal, bulkCostPerKg: Number((b.bulkCostPerKg + perKg).toFixed(2)) };
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
            b.id === input.batchId ? { ...b, leftoverQtyKg: Math.max(0, b.leftoverQtyKg - input.bulkKgUsed), status: "completed" as const } : b
          );
          const packagingMaterials = s.packagingMaterials.map((p) =>
            p.id === input.packagingMaterialId ? { ...p, stockQty: Math.max(0, p.stockQty - input.cartonQty) } : p
          );
          const newCarton: FinishedCarton = {
            id: `fc-${Date.now()}`, name: `${batch.id} Carton - ${input.packetsPerCarton}pk`,
            sourceBatchId: batch.id, packetsPerCarton: input.packetsPerCarton,
            costPerCarton: Number(costPerCarton.toFixed(2)), stockQty: input.cartonQty,
          };
          return { productionBatches, packagingMaterials, finishedCartons: [...s.finishedCartons, newCarton] };
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
            { id: `led-${Date.now()}`, customerId, type: "payment", amount: -amount, runningBalance: newBalance, date: today(), note: note || "Payment received" },
          ];
          const payments: Payment[] = [
            { id: `pay-${Date.now()}`, customerId, customerName: customer.name, amount, note: note || "Payment received", paidAt: today() },
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
          const items: InvoiceLineRecord[] = [];
          const finishedCartons = s.finishedCartons.map((c) => {
            const line = input.lines.find((l) => l.itemId === c.id);
            if (!line) return c;
            items.push({ itemId: c.id, itemName: c.name, qty: line.qty, unitPrice: line.unitPrice, subtotal: line.qty * line.unitPrice });
            return { ...c, stockQty: Math.max(0, c.stockQty - line.qty) };
          });
          const totalAmount = items.reduce((sum, l) => sum + l.subtotal, 0);
          const customerItemPrices = [...s.customerItemPrices];
          for (const line of input.lines) {
            const idx = customerItemPrices.findIndex((p) => p.customerId === input.customerId && p.itemId === line.itemId);
            if (idx >= 0) customerItemPrices[idx] = { ...customerItemPrices[idx], lastSoldPrice: line.unitPrice };
            else customerItemPrices.push({ customerId: input.customerId, itemId: line.itemId, lastSoldPrice: line.unitPrice });
          }
          const newBalance = customer.currentBalance + totalAmount;
          const customers = s.customers.map((c) => (c.id === input.customerId ? { ...c, currentBalance: newBalance } : c));
          const ledgerEntries: LedgerEntry[] = [
            ...s.ledgerEntries,
            { id: `led-${Date.now()}`, customerId: input.customerId, type: "invoice", amount: totalAmount, runningBalance: newBalance, date: today(), note: id },
          ];
          const newInvoice: Invoice = {
            id, customerId: input.customerId, customerName: customer.name,
            invoiceDate: today(), totalAmount, status: "unpaid", items,
          };
          return { finishedCartons, customerItemPrices, customers, ledgerEntries, invoices: [newInvoice, ...s.invoices] };
        });
        return id;
      },

      updateSettings: (patch) =>
        set((s) => ({ settings: { ...s.settings, ...patch } })),
    }),
    { name: "ghanifoods-dummy-data" }
  )
);
'@

# ---------------------------------------------------------------------------
# 2. Topbar
# ---------------------------------------------------------------------------
Write-Host "`n--- 2. Topbar store wiring ---" -ForegroundColor Cyan

Write-CodeFile "components\ui\topbar.tsx" @'
"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Notification, User as UserIcon, ChevronDown as ChevronDownIcon } from "@carbon/icons-react";
import { useStore } from "@/lib/store";

function NotificationBell() {
  const [open, setOpen] = useState(false);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const packagingMaterials = useStore((s) => s.packagingMaterials);

  const alerts = [
    ...rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold })),
    ...packagingMaterials
      .filter((p) => p.stockQty < p.lowStockThreshold)
      .map((p) => ({ id: p.id, name: p.name, href: `/packaging`, qty: p.stockQty, threshold: p.lowStockThreshold })),
  ];

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="relative flex items-center justify-center size-9 rounded-lg hover:bg-neutral-800 text-neutral-300"
        aria-label="Notifications"
      >
        <Notification size={18} />
        {alerts.length > 0 && (
          <span className="absolute -top-0.5 -right-0.5 flex items-center justify-center size-4 rounded-full bg-red-500 text-[10px] font-semibold text-white">
            {alerts.length}
          </span>
        )}
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 w-72 rounded-xl border border-neutral-800 bg-neutral-900 shadow-lg overflow-hidden">
            <div className="px-4 py-3 border-b border-neutral-800 text-sm font-medium text-neutral-200">
              Low Stock Alerts
            </div>
            <div className="max-h-72 overflow-y-auto">
              {alerts.length === 0 && (
                <div className="px-4 py-6 text-center text-sm text-neutral-500">All stock levels are healthy.</div>
              )}
              {alerts.map((a) => (
                <Link
                  key={a.id}
                  href={a.href}
                  onClick={() => setOpen(false)}
                  className="flex items-center justify-between px-4 py-2.5 hover:bg-neutral-800 border-b border-neutral-900 last:border-0"
                >
                  <span className="text-sm text-neutral-50">{a.name}</span>
                  <span className="text-xs text-red-400">{a.qty} / {a.threshold}</span>
                </Link>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function UserMenu() {
  const [open, setOpen] = useState(false);
  const router = useRouter();

  const handleLogout = () => {
    setOpen(false);
    document.cookie = "ghanifoods-auth=; path=/; max-age=0";
    router.push("/login");
  };

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-1.5 rounded-lg px-1.5 py-1 hover:bg-neutral-800"
        aria-label="User menu"
      >
        <div className="flex items-center justify-center size-8 rounded-full bg-neutral-800 border border-neutral-700">
          <UserIcon size={16} className="text-neutral-200" />
        </div>
        <ChevronDownIcon size={14} className="text-neutral-400" />
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 w-48 rounded-xl border border-neutral-800 bg-neutral-900 shadow-lg overflow-hidden">
            <Link href="/settings" onClick={() => setOpen(false)}
              className="block px-4 py-2.5 text-sm text-neutral-200 hover:bg-neutral-800">
              Settings
            </Link>
            <button onClick={handleLogout}
              className="w-full text-left px-4 py-2.5 text-sm text-red-400 hover:bg-neutral-800">
              Log out
            </button>
          </div>
        </>
      )}
    </div>
  );
}

export function Topbar() {
  return (
    <div className="flex items-center justify-end gap-3 border-b border-neutral-800 bg-neutral-950 px-6 py-3 sticky top-0 z-30">
      <Link href="/invoices/new"
        className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
        + New Invoice
      </Link>
      <NotificationBell />
      <UserMenu />
    </div>
  );
}

export default Topbar;
'@

# ---------------------------------------------------------------------------
# 3. Login page
# ---------------------------------------------------------------------------
Write-Host "`n--- 3. Login page with auth cookie ---" -ForegroundColor Cyan

Write-CodeFile "app\(auth)\login\page.tsx" @'
"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import { AtSignIcon, LockIcon, Grid2x2PlusIcon } from "lucide-react";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password.trim()) {
      setError("Please enter both email and password.");
      return;
    }
    setLoading(true);
    setError("");
    document.cookie = "ghanifoods-auth=1; path=/; max-age=86400";
    router.push("/");
  };

  return (
    <main className="relative md:h-screen md:overflow-hidden lg:grid lg:grid-cols-2">
      <div className="bg-neutral-900 relative hidden h-full flex-col border-r border-neutral-800 p-10 lg:flex">
        <div className="z-10 flex items-center gap-2 text-neutral-50">
          <Grid2x2PlusIcon className="size-6" />
          <p className="text-xl font-semibold">GhaniFoods</p>
        </div>
        <div className="z-10 mt-auto">
          <blockquote className="space-y-2">
            <p className="text-xl text-neutral-100">
              Real-time visibility into raw materials, batches, and customer
              ledgers - all in one place.
            </p>
            <footer className="font-mono text-sm font-semibold text-neutral-400">
              ~ GhaniFoods Production Team
            </footer>
          </blockquote>
        </div>
      </div>

      <div className="relative flex min-h-screen flex-col justify-center p-4 bg-black">
        <div className="mx-auto w-full max-w-sm space-y-4">
          <div className="flex items-center gap-2 lg:hidden text-neutral-50">
            <Grid2x2PlusIcon className="size-6" />
            <p className="text-xl font-semibold">GhaniFoods</p>
          </div>

          <div className="flex flex-col space-y-1">
            <h1 className="text-2xl font-bold tracking-wide text-neutral-50">Sign in to GhaniFoods</h1>
            <p className="text-neutral-400 text-base">Enter your credentials to access the dashboard.</p>
          </div>

          <form className="space-y-3" onSubmit={handleSubmit}>
            <div className="relative">
              <input
                type="email"
                placeholder="you@ghanifoods.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full h-10 rounded-md border border-neutral-800 bg-neutral-900 ps-9 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
              />
              <AtSignIcon className="absolute left-3 top-3 size-4 text-neutral-500 pointer-events-none" />
            </div>

            <div className="relative">
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full h-10 rounded-md border border-neutral-800 bg-neutral-900 ps-9 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
              />
              <LockIcon className="absolute left-3 top-3 size-4 text-neutral-500 pointer-events-none" />
            </div>

            {error && <p className="text-red-400 text-sm">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="w-full h-11 rounded-md bg-neutral-50 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
            >
              {loading ? "Signing in..." : "Sign In"}
            </button>
          </form>

          <p className="text-neutral-500 mt-8 text-sm">
            Demo build - any email / password combination signs you in.
          </p>
        </div>
      </div>
    </main>
  );
}
'@

# ---------------------------------------------------------------------------
# 4. middleware.ts
# ---------------------------------------------------------------------------
Write-Host "`n--- 4. Auth middleware ---" -ForegroundColor Cyan

Write-CodeFile "middleware.ts" @'
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (pathname.startsWith("/login") || pathname.startsWith("/_next") || pathname.startsWith("/api")) {
    return NextResponse.next();
  }

  const isAuthed = request.cookies.get("ghanifoods-auth");
  if (!isAuthed) {
    const loginUrl = new URL("/login", request.url);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
'@

# ---------------------------------------------------------------------------
# 5. Settings page
# ---------------------------------------------------------------------------
Write-Host "`n--- 5. Settings page ---" -ForegroundColor Cyan

Write-CodeFile "app\(dashboard)\settings\page.tsx" @'
"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

const settingsSchema = z.object({
  businessName: z.string().trim().min(2, "Business name required"),
  address: z.string().trim().min(5, "Address required"),
  invoiceFooterText: z.string().trim(),
  defaultProfitMarginPercent: z.coerce.number().min(0, "Cannot be negative"),
  lowStockThresholdDefault: z.coerce.number().min(0, "Cannot be negative"),
});
type SettingsFormValues = z.infer<typeof settingsSchema>;

export default function SettingsPage() {
  const settings = useStore((s) => s.settings);
  const updateSettings = useStore((s) => s.updateSettings);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting, isDirty },
  } = useForm<SettingsFormValues>({
    resolver: zodResolver(settingsSchema),
    defaultValues: settings,
  });

  const onSubmit = async (values: SettingsFormValues) => {
    updateSettings(values);
    toast.success("Settings saved");
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-2xl">
      <h1 className="text-xl font-semibold text-neutral-50">Settings</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-sm font-semibold text-neutral-200">Business Profile</h2>

        <div>
          <label className="text-sm text-neutral-400">Business Name</label>
          <input {...register("businessName")}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.businessName && <p className="text-xs text-red-400 mt-1">{errors.businessName.message}</p>}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Address</label>
          <input {...register("address")}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.address && <p className="text-xs text-red-400 mt-1">{errors.address.message}</p>}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Invoice Footer Text</label>
          <input {...register("invoiceFooterText")}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-sm font-semibold text-neutral-200">Defaults</h2>

        <div>
          <label className="text-sm text-neutral-400">Default Profit Margin %</label>
          <input {...register("defaultProfitMarginPercent")} type="number" step="any"
            className="mt-1 w-48 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.defaultProfitMarginPercent && <p className="text-xs text-red-400 mt-1">{errors.defaultProfitMarginPercent.message}</p>}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Low-Stock Threshold Default</label>
          <input {...register("lowStockThresholdDefault")} type="number"
            className="mt-1 w-48 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.lowStockThresholdDefault && <p className="text-xs text-red-400 mt-1">{errors.lowStockThresholdDefault.message}</p>}
        </div>
      </div>

      <button
        type="submit"
        disabled={isSubmitting || !isDirty}
        className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
      >
        {isSubmitting ? "Saving..." : "Save Settings"}
      </button>
    </form>
  );
}
'@

# ---------------------------------------------------------------------------
# 6. SortableTable
# ---------------------------------------------------------------------------
Write-Host "`n--- 6. Shared SortableTable component ---" -ForegroundColor Cyan

Write-CodeFile "components\ui\sortable-table.tsx" @'
"use client";

import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender,
  type ColumnDef,
  type SortingState,
} from "@tanstack/react-table";
import { useState } from "react";

interface SortableTableProps<T> {
  data: T[];
  columns: ColumnDef<T, unknown>[];
  globalFilterPlaceholder?: string;
  showGlobalFilter?: boolean;
}

export function SortableTable<T>({
  data,
  columns,
  globalFilterPlaceholder = "Search...",
  showGlobalFilter = true,
}: SortableTableProps<T>) {
  const [sorting, setSorting] = useState<SortingState>([]);
  const [globalFilter, setGlobalFilter] = useState("");

  const table = useReactTable({
    data,
    columns,
    state: { sorting, globalFilter },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
  });

  return (
    <div className="space-y-3">
      {showGlobalFilter && (
        <input
          value={globalFilter}
          onChange={(e) => setGlobalFilter(e.target.value)}
          placeholder={globalFilterPlaceholder}
          className="w-full max-w-sm rounded-lg border border-neutral-800 bg-neutral-900 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
        />
      )}

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            {table.getHeaderGroups().map((hg) => (
              <tr key={hg.id} className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
                {hg.headers.map((header) => (
                  <th
                    key={header.id}
                    className="px-4 py-3 font-medium select-none"
                    style={{ width: header.column.getSize() !== 150 ? header.column.getSize() : undefined }}
                  >
                    {header.isPlaceholder ? null : (
                      <div
                        className={header.column.getCanSort() ? "flex items-center gap-1 cursor-pointer hover:text-neutral-200" : ""}
                        onClick={header.column.getToggleSortingHandler()}
                      >
                        {flexRender(header.column.columnDef.header, header.getContext())}
                        {header.column.getCanSort() && (
                          <span className="text-xs text-neutral-600">
                            {{ asc: " up", desc: " down" }[header.column.getIsSorted() as string] ?? " -"}
                          </span>
                        )}
                      </div>
                    )}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-8 text-center text-neutral-500">
                  No results found.
                </td>
              </tr>
            ) : (
              table.getRowModel().rows.map((row) => (
                <tr key={row.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className="px-4 py-3 text-neutral-300">
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="text-xs text-neutral-600">
        {table.getFilteredRowModel().rows.length} of {data.length} rows
      </div>
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# 7. Raw Materials list
# ---------------------------------------------------------------------------
Write-Host "`n--- 7. Raw Materials list with SortableTable ---" -ForegroundColor Cyan

Write-CodeFile "app\(dashboard)\raw-materials\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type RawMaterial } from "@/lib/store";
import { rawMaterialSchema, type RawMaterialFormValues } from "@/lib/schemas";
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

function AddRawMaterialDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<RawMaterialFormValues>({
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
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
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
        <Link href={`/raw-materials/${row.original.id}`} className="text-neutral-50 hover:underline">
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
        <h1 className="text-xl font-semibold text-neutral-50">Raw Materials</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Raw Material
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search raw materials..." />
      <AddRawMaterialDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# 8. Packaging
# ---------------------------------------------------------------------------
Write-Host "`n--- 8. Packaging with SortableTable ---" -ForegroundColor Cyan

Write-CodeFile "app\(dashboard)\packaging\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type PackagingMaterial } from "@/lib/store";
import { packagingMaterialSchema, restockSchema, type PackagingMaterialFormValues, type RestockFormValues } from "@/lib/schemas";
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

function AddPackagingDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addPackagingMaterial = useStore((s) => s.addPackagingMaterial);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<PackagingMaterialFormValues>({
    resolver: zodResolver(packagingMaterialSchema),
    defaultValues: { name: "", unitCost: 0, lowStockThreshold: 50 },
  });
  if (!open) return null;
  const onSubmit = async (values: PackagingMaterialFormValues) => {
    addPackagingMaterial(values);
    toast.success(`"${values.name}" added`);
    reset(); onClose();
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
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

function RestockDialog({ open, onClose, item }: { open: boolean; onClose: () => void; item: PackagingMaterial | null }) {
  const restockPackaging = useStore((s) => s.restockPackaging);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<RestockFormValues>({ resolver: zodResolver(restockSchema) });
  if (!open || !item) return null;
  const onSubmit = async (values: RestockFormValues) => {
    restockPackaging(item.id, values.qty, values.cost ?? 0);
    toast.success(`Restocked ${item.name}`);
    reset(); onClose();
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
            <label className="text-sm text-neutral-400">Cost per unit (optional)</label>
            <input {...register("cost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function PackagingPage() {
  const items = useStore((s) => s.packagingMaterials);
  const [addOpen, setAddOpen] = useState(false);
  const [restockTarget, setRestockTarget] = useState<PackagingMaterial | null>(null);

  const columns = useMemo<ColumnDef<PackagingMaterial, unknown>[]>(() => [
    { accessorKey: "name", header: "Name", cell: ({ getValue }) => <span className="text-neutral-50">{getValue() as string}</span> },
    { accessorKey: "unitCost", header: "Unit Cost", cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}` },
    { accessorKey: "stockQty", header: "Stock Qty", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    { accessorKey: "lowStockThreshold", header: "Threshold", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge isLow={row.original.stockQty < row.original.lowStockThreshold} />,
    },
    {
      id: "action", header: "", enableSorting: false,
      cell: ({ row }) => (
        <button onClick={() => setRestockTarget(row.original)}
          className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800">
          Restock
        </button>
      ),
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Packaging Materials</h1>
        <button onClick={() => setAddOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Packaging Material
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search packaging..." />
      <AddPackagingDialog open={addOpen} onClose={() => setAddOpen(false)} />
      <RestockDialog open={!!restockTarget} onClose={() => setRestockTarget(null)} item={restockTarget} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# 9. Batches list
# ---------------------------------------------------------------------------
Write-Host "`n--- 9. Batches list with SortableTable ---" -ForegroundColor Cyan

Write-CodeFile "app\(dashboard)\batches\page.tsx" @'
"use client";

import { useMemo } from "react";
import Link from "next/link";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type ProductionBatch } from "@/lib/store";
import { SortableTable } from "@/components/ui/sortable-table";

function StatusBadge({ status }: { status: "in_progress" | "completed" }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      status === "completed" ? "bg-green-950 text-green-400 border border-green-900" : "bg-amber-950 text-amber-400 border border-amber-900"
    }`}>
      {status === "completed" ? "Completed" : "In Progress"}
    </span>
  );
}

export default function BatchesPage() {
  const productionBatches = useStore((s) => s.productionBatches);

  const columns = useMemo<ColumnDef<ProductionBatch, unknown>[]>(() => [
    {
      accessorKey: "id", header: "Batch ID",
      cell: ({ row }) => <Link href={`/batches/${row.original.id}`} className="text-neutral-50 hover:underline">{row.original.id}</Link>,
    },
    { accessorKey: "batchDate", header: "Date" },
    { accessorKey: "outputYieldKg", header: "Output Yield (kg)" },
    { accessorKey: "wastageKg", header: "Wastage (kg)" },
    { accessorKey: "leftoverQtyKg", header: "Leftover (kg)" },
    {
      accessorKey: "bulkCostPerKg", header: "Bulk Cost/Kg",
      cell: ({ getValue }) => {
        const v = getValue() as number;
        return v > 0 ? `Rs. ${v.toLocaleString()}` : "-";
      },
    },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Production Batches</h1>
        <Link href="/batches/new" className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + New Batch
        </Link>
      </div>
      <SortableTable data={productionBatches} columns={columns} globalFilterPlaceholder="Search batches..." />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# 10. Customers list
# ---------------------------------------------------------------------------
Write-Host "`n--- 10. Customers list with SortableTable ---" -ForegroundColor Cyan

Write-CodeFile "app\(dashboard)\customers\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Customer } from "@/lib/store";
import { customerSchema, type CustomerFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

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
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<CustomerFormValues>({
    resolver: zodResolver(customerSchema),
    defaultValues: { name: "", phone: "", openingBalance: 0 },
  });
  if (!open) return null;
  const onSubmit = async (values: CustomerFormValues) => {
    addCustomer(values);
    toast.success(`Customer "${values.name}" added`);
    reset(); onClose();
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
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function CustomersPage() {
  const items = useStore((s) => s.customers);
  const [dialogOpen, setDialogOpen] = useState(false);

  const columns = useMemo<ColumnDef<Customer, unknown>[]>(() => [
    {
      accessorKey: "name", header: "Name",
      cell: ({ row }) => <Link href={`/customers/${row.original.id}`} className="text-neutral-50 hover:underline">{row.original.name}</Link>,
    },
    { accessorKey: "phone", header: "Phone" },
    {
      accessorKey: "currentBalance", header: "Current Balance",
      cell: ({ row }) => <BalanceCell balance={row.original.currentBalance} />,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Customers</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Customer
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search customers..." />
      <AddCustomerDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# 11. Invoices list
# ---------------------------------------------------------------------------
Write-Host "`n--- 11. Invoices list with SortableTable ---" -ForegroundColor Cyan

Write-CodeFile "app\(dashboard)\invoices\page.tsx" @'
"use client";

import { useMemo } from "react";
import Link from "next/link";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Invoice } from "@/lib/store";
import { SortableTable } from "@/components/ui/sortable-table";

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

export default function InvoicesPage() {
  const invoices = useStore((s) => s.invoices);

  const columns = useMemo<ColumnDef<Invoice, unknown>[]>(() => [
    {
      accessorKey: "id", header: "Invoice #",
      cell: ({ row }) => <Link href={`/invoices/${row.original.id}`} className="text-neutral-50 hover:underline">{row.original.id}</Link>,
    },
    { accessorKey: "customerName", header: "Customer" },
    { accessorKey: "invoiceDate", header: "Date" },
    {
      accessorKey: "totalAmount", header: "Total",
      cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}`,
    },
    {
      accessorKey: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Invoices</h1>
        <Link href="/invoices/new" className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + New Invoice
        </Link>
      </div>
      <SortableTable data={invoices} columns={columns} globalFilterPlaceholder="Search invoices..." />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# 12. Payments list
# ---------------------------------------------------------------------------
Write-Host "`n--- 12. Payments list with SortableTable ---" -ForegroundColor Cyan

Write-CodeFile "app\(dashboard)\payments\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Payment } from "@/lib/store";
import { paymentSchema, type PaymentFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function RecordPaymentDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const customers = useStore((s) => s.customers);
  const recordPayment = useStore((s) => s.recordPayment);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<PaymentFormValues>({
    resolver: zodResolver(paymentSchema),
    defaultValues: { customerId: customers[0]?.id ?? "", amount: 0, note: "" },
  });
  if (!open) return null;
  const onSubmit = async (values: PaymentFormValues) => {
    recordPayment(values.customerId, values.amount, values.note ?? "");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded`);
    reset(); onClose();
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
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
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

  const columns = useMemo<ColumnDef<Payment, unknown>[]>(() => [
    { accessorKey: "paidAt", header: "Date" },
    { accessorKey: "customerName", header: "Customer", cell: ({ getValue }) => <span className="text-neutral-50">{getValue() as string}</span> },
    {
      accessorKey: "amount", header: "Amount",
      cell: ({ getValue }) => <span className="text-green-400">Rs. {(getValue() as number).toLocaleString()}</span>,
    },
    { accessorKey: "note", header: "Note" },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Payments</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Record Payment
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search payments..." />
      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# 13. Reports page
# ---------------------------------------------------------------------------
Write-Host "`n--- 13. Reports page ---" -ForegroundColor Cyan

Write-CodeFile "app\(dashboard)\reports\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, Legend,
} from "recharts";
import { useStore } from "@/lib/store";

function exportCSV(filename: string, headers: string[], rows: (string | number)[][]) {
  const lines = [headers.join(","), ...rows.map((r) => r.map((v) => `"${v}"`).join(","))];
  const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export default function ReportsPage() {
  const rawMaterials = useStore((s) => s.rawMaterials);
  const packagingMaterials = useStore((s) => s.packagingMaterials);
  const productionBatches = useStore((s) => s.productionBatches);
  const invoices = useStore((s) => s.invoices);
  const finishedCartons = useStore((s) => s.finishedCartons);

  const [tab, setTab] = useState<"inventory" | "yield" | "pnl">("inventory");
  const [from, setFrom] = useState("2026-08-01");
  const [to, setTo] = useState("2026-08-18");

  const inventoryData = useMemo(() => [
    ...rawMaterials.map((m) => ({ name: m.name, stock: m.quantityInStock, threshold: m.lowStockThreshold, type: "Raw" })),
    ...packagingMaterials.map((p) => ({ name: p.name, stock: p.stockQty, threshold: p.lowStockThreshold, type: "Packaging" })),
  ], [rawMaterials, packagingMaterials]);

  const yieldData = useMemo(() =>
    productionBatches.map((b) => ({
      batch: b.id,
      outputYield: b.outputYieldKg,
      wastage: b.wastageKg,
      leftover: b.leftoverQtyKg,
    })), [productionBatches]);

  const pnl = useMemo(() => {
    const filteredInvoices = invoices.filter((i) => i.invoiceDate >= from && i.invoiceDate <= to);
    const filteredBatches = productionBatches.filter((b) => b.batchDate >= from && b.batchDate <= to);
    const totalRevenue = filteredInvoices.reduce((sum, i) => sum + i.totalAmount, 0);
    const totalCost = filteredBatches.reduce((sum, b) => sum + b.outputYieldKg * b.bulkCostPerKg, 0);
    const grossProfit = totalRevenue - totalCost;

    const lineData = filteredInvoices
      .slice()
      .sort((a, b) => a.invoiceDate.localeCompare(b.invoiceDate))
      .map((inv) => ({ date: inv.invoiceDate, revenue: inv.totalAmount }));

    return { totalRevenue, totalCost, grossProfit, lineData };
  }, [invoices, productionBatches, from, to]);

  const cartonsReady = finishedCartons.reduce((sum, c) => sum + c.stockQty, 0);
  const cartonsValue = finishedCartons.reduce((sum, c) => sum + c.stockQty * c.costPerCarton, 0);

  const handleInventoryExport = () => {
    exportCSV("inventory.csv",
      ["Name", "Type", "Stock", "Threshold"],
      inventoryData.map((r) => [r.name, r.type, r.stock, r.threshold])
    );
  };
  const handleYieldExport = () => {
    exportCSV("production-yield.csv",
      ["Batch", "Output Yield (kg)", "Wastage (kg)", "Leftover (kg)"],
      yieldData.map((r) => [r.batch, r.outputYield, r.wastage, r.leftover])
    );
  };
  const handlePnlExport = () => {
    exportCSV("pnl.csv",
      ["Date", "Revenue"],
      pnl.lineData.map((r) => [r.date, r.revenue])
    );
  };

  const tooltipStyle = { backgroundColor: "#171717", border: "1px solid #262626", color: "#f5f5f5", borderRadius: 8 };

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-neutral-50">Reports and Analytics</h1>

      <div className="flex flex-wrap items-end gap-3 rounded-xl border border-neutral-800 bg-neutral-900 p-4">
        <div>
          <label className="text-xs text-neutral-400">From</label>
          <input value={from} onChange={(e) => setFrom(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
        </div>
        <div>
          <label className="text-xs text-neutral-400">To</label>
          <input value={to} onChange={(e) => setTo(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
        </div>
      </div>

      <div className="flex gap-2 border-b border-neutral-800">
        {(["inventory", "yield", "pnl"] as const).map((key) => (
          <button key={key} onClick={() => setTab(key)}
            className={`px-4 py-2 text-sm font-medium border-b-2 capitalize ${
              tab === key ? "border-neutral-50 text-neutral-50" : "border-transparent text-neutral-400"
            }`}>
            {key === "yield" ? "Production Yield" : key === "pnl" ? "P and L" : "Inventory Movement"}
          </button>
        ))}
      </div>

      {tab === "inventory" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={handleInventoryExport}
              className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
              Export CSV
            </button>
          </div>
          <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
            <h2 className="text-sm font-semibold text-neutral-200 mb-4">Stock vs Threshold</h2>
            <ResponsiveContainer width="100%" height={320}>
              <BarChart data={inventoryData} margin={{ top: 5, right: 20, left: 0, bottom: 60 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#262626" />
                <XAxis dataKey="name" tick={{ fill: "#a3a3a3", fontSize: 11 }} angle={-30} textAnchor="end" interval={0} />
                <YAxis tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                <Tooltip contentStyle={tooltipStyle} />
                <Legend wrapperStyle={{ color: "#a3a3a3", paddingTop: 16 }} />
                <Bar dataKey="stock" name="Stock" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                <Bar dataKey="threshold" name="Threshold" fill="#ef4444" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-4">
              <div className="text-xs text-neutral-400">Finished Cartons Ready</div>
              <div className="text-2xl font-semibold text-neutral-50 mt-1">{cartonsReady}</div>
            </div>
            <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-4">
              <div className="text-xs text-neutral-400">Finished Stock Value (at cost)</div>
              <div className="text-2xl font-semibold text-neutral-50 mt-1">Rs. {cartonsValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</div>
            </div>
          </div>
        </div>
      )}

      {tab === "yield" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={handleYieldExport}
              className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
              Export CSV
            </button>
          </div>
          <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
            <h2 className="text-sm font-semibold text-neutral-200 mb-4">Output Yield, Wastage and Leftover per Batch</h2>
            <ResponsiveContainer width="100%" height={320}>
              <BarChart data={yieldData} margin={{ top: 5, right: 20, left: 0, bottom: 20 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#262626" />
                <XAxis dataKey="batch" tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                <YAxis tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                <Tooltip contentStyle={tooltipStyle} />
                <Legend wrapperStyle={{ color: "#a3a3a3", paddingTop: 8 }} />
                <Bar dataKey="outputYield" name="Output (kg)" fill="#22c55e" radius={[4, 4, 0, 0]} />
                <Bar dataKey="wastage" name="Wastage (kg)" fill="#ef4444" radius={[4, 4, 0, 0]} />
                <Bar dataKey="leftover" name="Leftover (kg)" fill="#f59e0b" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {tab === "pnl" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={handlePnlExport}
              className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
              Export CSV
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-4">
              <div className="text-xs text-neutral-400">Total Revenue</div>
              <div className="text-2xl font-semibold text-neutral-50 mt-1">Rs. {pnl.totalRevenue.toLocaleString()}</div>
            </div>
            <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-4">
              <div className="text-xs text-neutral-400">Est. Production Cost</div>
              <div className="text-2xl font-semibold text-neutral-50 mt-1">Rs. {pnl.totalCost.toLocaleString(undefined, { maximumFractionDigits: 0 })}</div>
            </div>
            <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-4">
              <div className="text-xs text-neutral-400">Est. Gross Profit</div>
              <div className={`text-2xl font-semibold mt-1 ${pnl.grossProfit >= 0 ? "text-green-400" : "text-red-400"}`}>
                Rs. {pnl.grossProfit.toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </div>
            </div>
          </div>

          {pnl.lineData.length > 0 && (
            <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
              <h2 className="text-sm font-semibold text-neutral-200 mb-4">Revenue Over Time (selected period)</h2>
              <ResponsiveContainer width="100%" height={280}>
                <LineChart data={pnl.lineData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#262626" />
                  <XAxis dataKey="date" tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                  <YAxis tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Line type="monotone" dataKey="revenue" name="Revenue (Rs.)" stroke="#3b82f6" strokeWidth={2} dot={{ fill: "#3b82f6", r: 4 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}

          {pnl.lineData.length === 0 && (
            <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-8 text-center text-neutral-500 text-sm">
              No invoices in the selected date range.
            </div>
          )}
        </div>
      )}
    </div>
  );
}
'@

Write-Host "`n=== Step 3 complete! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Changes applied:" -ForegroundColor Green
Write-Host "  [1] lib/store.ts - settings slice added" -ForegroundColor Yellow
Write-Host "  [2] topbar.tsx - NotificationBell now reads from Zustand store" -ForegroundColor Yellow
Write-Host "  [3] login/page.tsx - sets auth cookie on sign-in" -ForegroundColor Yellow
Write-Host "  [4] middleware.ts - redirects unauthenticated users to login" -ForegroundColor Yellow
Write-Host "  [5] settings/page.tsx - wired to store with Zod validation" -ForegroundColor Yellow
Write-Host "  [6] sortable-table.tsx - shared TanStack Table v8 component" -ForegroundColor Yellow
Write-Host "  [7] raw-materials - SortableTable" -ForegroundColor Yellow
Write-Host "  [8] packaging - SortableTable" -ForegroundColor Yellow
Write-Host "  [9] batches - SortableTable" -ForegroundColor Yellow
Write-Host "  [10] customers - SortableTable" -ForegroundColor Yellow
Write-Host "  [11] invoices - SortableTable" -ForegroundColor Yellow
Write-Host "  [12] payments - SortableTable" -ForegroundColor Yellow
Write-Host "  [13] reports/page.tsx - store wired with Recharts and CSV export" -ForegroundColor Yellow
Write-Host ""
Write-Host "Run the app:" -ForegroundColor Cyan
Write-Host "  npm run dev:frontend" -ForegroundColor White
Write-Host ""
Write-Host "Test checklist:" -ForegroundColor Cyan
Write-Host "  - Go to login, sign in, should redirect to dashboard" -ForegroundColor White
Write-Host "  - Open new tab without cookie, should redirect back to login" -ForegroundColor White
Write-Host "  - Topbar bell should show Ghee and Spice Mix as low stock" -ForegroundColor White
Write-Host "  - Settings, change business name, save, check toast" -ForegroundColor White
Write-Host "  - Raw Materials, click column header, should sort" -ForegroundColor White
Write-Host "  - Inventory tab, Recharts bar chart should render" -ForegroundColor White
Write-Host "  - Reports, P and L, Export CSV, file should download" -ForegroundColor White