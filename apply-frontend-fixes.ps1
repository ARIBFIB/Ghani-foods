# apply-frontend-fixes.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\apply-frontend-fixes.ps1
#
# What this does:
#   1. FIFO leftover logic  - "Use Leftover From Previous Batch First" switch on
#      /batches/new now actually consumes leftover bulk product (blended cost).
#   2. PDF Download          - Invoice detail page now generates & downloads a
#      real PDF (via jsPDF) instead of showing a "not implemented" toast.
#   3. Ant Design cleanup    - Removes the unused AntdThemeProvider (dead code,
#      never wired into layout.tsx) and the unused antd packages from
#      package.json so bundle size / confusion goes down.
#
# Safe to re-run - it overwrites the same files with the same fixed content.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    Write-Host "Make sure you're running this from the GhaniFoods root folder." -ForegroundColor Red
    exit 1
}

Write-Host "=== Applying GhaniFoods frontend fixes ===" -ForegroundColor Cyan
Write-Host "Project root: $Root" -ForegroundColor Gray

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. lib/store.ts - FIFO leftover consumption logic in createBatch()
# --------------------------------------------------------------------------

$storePath = Join-Path $FrontendRoot "lib\store.ts"
$storeContent = @'
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
  leftoverSourceBatchId?: string;
  leftoverKgConsumed?: number;
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
    leftoverBatchId?: string;
    leftoverKgUsed?: number;
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

      // ------------------------------------------------------------------
      // FIFO leftover logic (FR-10):
      // If leftoverBatchId + leftoverKgUsed are provided, that quantity of
      // bulk product is pulled from the earlier batch's leftover pool BEFORE
      // being combined with this batch's freshly produced output. The two
      // are cost-blended so the new batch's effective cost/kg reflects both
      // the raw-material cost of the new output AND the carried-forward
      // cost/kg of the reused leftover.
      // ------------------------------------------------------------------
      createBatch: (input) => {
        const id = `batch-${Date.now()}`;
        set((s) => {
          let rawMaterialCost = 0;
          const rawMaterials = s.rawMaterials.map((m) => {
            const line = input.consumptions.find((c) => c.rawMaterialId === m.id);
            if (!line) return m;
            rawMaterialCost += line.qty * m.avgUnitCost;
            return { ...m, quantityInStock: Math.max(0, m.quantityInStock - line.qty) };
          });

          let productionBatches = s.productionBatches;
          let leftoverCostContribution = 0;
          let leftoverKgActuallyUsed = 0;

          if (input.leftoverBatchId && input.leftoverKgUsed && input.leftoverKgUsed > 0) {
            const sourceBatch = s.productionBatches.find((b) => b.id === input.leftoverBatchId);
            if (sourceBatch) {
              // Never consume more than what's actually available (FIFO safety cap)
              leftoverKgActuallyUsed = Math.min(input.leftoverKgUsed, sourceBatch.leftoverQtyKg);
              leftoverCostContribution = leftoverKgActuallyUsed * sourceBatch.bulkCostPerKg;

              productionBatches = productionBatches.map((b) =>
                b.id === input.leftoverBatchId
                  ? { ...b, leftoverQtyKg: Number((b.leftoverQtyKg - leftoverKgActuallyUsed).toFixed(2)) }
                  : b
              );
            }
          }

          const totalCost = rawMaterialCost + leftoverCostContribution;
          const totalKg = input.outputYieldKg + leftoverKgActuallyUsed;
          const bulkCostPerKg = totalKg > 0 ? totalCost / totalKg : 0;

          const newBatch: ProductionBatch = {
            id,
            batchDate: today(),
            outputYieldKg: input.outputYieldKg,
            wastageKg: input.wastageKg,
            leftoverQtyKg: Number(totalKg.toFixed(2)),
            bulkCostPerKg: Number(bulkCostPerKg.toFixed(2)),
            overheadTotal: 0,
            status: "in_progress",
            leftoverSourceBatchId: leftoverKgActuallyUsed > 0 ? input.leftoverBatchId : undefined,
            leftoverKgConsumed: leftoverKgActuallyUsed > 0 ? Number(leftoverKgActuallyUsed.toFixed(2)) : undefined,
          };

          return { rawMaterials, productionBatches: [newBatch, ...productionBatches] };
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
Write-Utf8NoBom $storePath $storeContent

# --------------------------------------------------------------------------
# 2. app/(dashboard)/batches/new/page.tsx - wire the leftover switch to
#    actually pass leftoverBatchId + leftoverKgUsed into createBatch()
# --------------------------------------------------------------------------

$newBatchPath = Join-Path $FrontendRoot "app\(dashboard)\batches\new\page.tsx"
$newBatchContent = @'
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
  const [leftoverKgUsed, setLeftoverKgUsed] = useState("");

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);
  const selectedLeftoverBatch = leftoverBatches.find((b) => b.id === leftoverBatchId);

  const addRow = () => setRows((prev) => [...prev, { id: crypto.randomUUID(), rawMaterialId: rawMaterials[0]?.id ?? "", qty: "" }]);
  const removeRow = (id: string) => setRows((prev) => (prev.length > 1 ? prev.filter((r) => r.id !== id) : prev));
  const updateRow = (id: string, patch: Partial<ConsumptionRow>) =>
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  const estimatedRawMaterialCost = useMemo(() => {
    return rows.reduce((total, row) => {
      const material = rawMaterials.find((m) => m.id === row.rawMaterialId);
      const qty = Number(row.qty) || 0;
      if (!material) return total;
      return total + qty * material.avgUnitCost;
    }, 0);
  }, [rows, rawMaterials]);

  const estimatedLeftoverCost = useMemo(() => {
    if (!useLeftoverFirst || !selectedLeftoverBatch) return 0;
    const kg = Math.min(Number(leftoverKgUsed) || 0, selectedLeftoverBatch.leftoverQtyKg);
    return kg * selectedLeftoverBatch.bulkCostPerKg;
  }, [useLeftoverFirst, selectedLeftoverBatch, leftoverKgUsed]);

  const estimatedTotalCost = estimatedRawMaterialCost + estimatedLeftoverCost;

  const effectiveKgUsedFromLeftover = useMemo(() => {
    if (!useLeftoverFirst || !selectedLeftoverBatch) return 0;
    return Math.min(Number(leftoverKgUsed) || 0, selectedLeftoverBatch.leftoverQtyKg);
  }, [useLeftoverFirst, selectedLeftoverBatch, leftoverKgUsed]);

  const estimatedTotalKg = (Number(outputYield) || 0) + effectiveKgUsedFromLeftover;

  const estimatedCostPerKg = useMemo(() => {
    if (estimatedTotalKg <= 0) return 0;
    return estimatedTotalCost / estimatedTotalKg;
  }, [estimatedTotalCost, estimatedTotalKg]);

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

    if (useLeftoverFirst) {
      if (!leftoverBatchId) {
        setRowError("Select a leftover batch, or turn off 'Use Leftover From Previous Batch First'");
        return;
      }
      const kg = Number(leftoverKgUsed) || 0;
      if (kg <= 0) {
        setRowError("Enter how many kg of leftover to use");
        return;
      }
      if (selectedLeftoverBatch && kg > selectedLeftoverBatch.leftoverQtyKg) {
        setRowError(`Only ${selectedLeftoverBatch.leftoverQtyKg} kg leftover available in ${selectedLeftoverBatch.id}`);
        return;
      }
    }

    const newId = createBatch({
      consumptions,
      outputYieldKg: values.outputYieldKg,
      wastageKg: values.wastageKg,
      leftoverBatchId: useLeftoverFirst ? leftoverBatchId : undefined,
      leftoverKgUsed: useLeftoverFirst ? Number(leftoverKgUsed) || 0 : undefined,
    });

    if (useLeftoverFirst) {
      toast.success(`Batch ${newId} created — raw material stock deducted and ${leftoverKgUsed} kg leftover from ${leftoverBatchId} consumed`);
    } else {
      toast.success(`Batch ${newId} created — raw material stock deducted`);
    }
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
            Rs. {estimatedTotalCost.toLocaleString(undefined, { maximumFractionDigits: 2 })}
          </div>
          {estimatedLeftoverCost > 0 && (
            <div className="text-xs text-neutral-500 mt-1">
              includes Rs. {estimatedLeftoverCost.toLocaleString(undefined, { maximumFractionDigits: 2 })} carried over from leftover
            </div>
          )}
          {estimatedTotalKg > 0 && (
            <div className="text-xs text-neutral-400 mt-1">
              Est. cost/kg: Rs. {estimatedCostPerKg.toLocaleString(undefined, { maximumFractionDigits: 2 })}
              {" "}(on {estimatedTotalKg} kg total{effectiveKgUsedFromLeftover > 0 ? `, incl. ${effectiveKgUsedFromLeftover} kg leftover` : ""})
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
          <input
            type="checkbox"
            checked={useLeftoverFirst}
            onChange={(e) => {
              setUseLeftoverFirst(e.target.checked);
              if (!e.target.checked) {
                setLeftoverBatchId("");
                setLeftoverKgUsed("");
              }
            }}
            className="size-4 rounded border-neutral-700 bg-neutral-950"
          />
          <span className="text-sm text-neutral-200">Use Leftover From Previous Batch First</span>
        </label>

        {useLeftoverFirst && (
          <div className="space-y-3">
            <div>
              <label className="text-sm text-neutral-400">Leftover Batch</label>
              <select
                value={leftoverBatchId}
                onChange={(e) => { setLeftoverBatchId(e.target.value); setLeftoverKgUsed(""); }}
                className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
              >
                <option value="">Select leftover batch...</option>
                {leftoverBatches.map((b) => (
                  <option key={b.id} value={b.id}>{b.id} — {b.leftoverQtyKg} kg available @ Rs. {b.bulkCostPerKg}/kg</option>
                ))}
              </select>
            </div>

            {selectedLeftoverBatch && (
              <div>
                <label className="text-sm text-neutral-400">Leftover Qty to Use (kg)</label>
                <input
                  value={leftoverKgUsed}
                  onChange={(e) => setLeftoverKgUsed(e.target.value)}
                  type="number"
                  step="any"
                  max={selectedLeftoverBatch.leftoverQtyKg}
                  placeholder={`Up to ${selectedLeftoverBatch.leftoverQtyKg} kg`}
                  className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
                />
                {Number(leftoverKgUsed) > selectedLeftoverBatch.leftoverQtyKg && (
                  <p className="text-xs text-red-400 mt-1">Only {selectedLeftoverBatch.leftoverQtyKg} kg available in this batch</p>
                )}
              </div>
            )}
          </div>
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
Write-Utf8NoBom $newBatchPath $newBatchContent

# --------------------------------------------------------------------------
# 3. app/(dashboard)/batches/[id]/page.tsx - show leftover-source info
# --------------------------------------------------------------------------

$batchDetailPath = Join-Path $FrontendRoot "app\(dashboard)\batches\[id]\page.tsx"
$batchDetailContent = @'
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

        {batch.leftoverSourceBatchId && batch.leftoverKgConsumed && (
          <div className="mt-2 text-xs text-blue-400">
            Includes {batch.leftoverKgConsumed} kg of leftover bulk product carried forward from{" "}
            <Link href={`/batches/${batch.leftoverSourceBatchId}`} className="underline">{batch.leftoverSourceBatchId}</Link>{" "}
            (FIFO — cost blended into this batch's effective cost/kg).
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
Write-Utf8NoBom $batchDetailPath $batchDetailContent

# --------------------------------------------------------------------------
# 4. app/(dashboard)/invoices/[id]/page.tsx - real PDF download via jsPDF
# --------------------------------------------------------------------------

$invoiceDetailPath = Join-Path $FrontendRoot "app\(dashboard)\invoices\[id]\page.tsx"
$invoiceDetailContent = @'
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
  const settings = useStore((s) => s.settings);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [generatingPdf, setGeneratingPdf] = useState(false);

  if (!invoice) {
    return (
      <div className="space-y-4">
        <Link href="/invoices" className="text-sm text-neutral-400 hover:underline">&larr; Back to Invoices</Link>
        <p className="text-neutral-400">Invoice not found.</p>
      </div>
    );
  }

  const handleDownloadPDF = async () => {
    setGeneratingPdf(true);
    try {
      const { jsPDF } = await import("jspdf");
      const doc = new jsPDF({ unit: "pt", format: "a4" });

      const marginX = 48;
      let y = 56;

      doc.setFontSize(18);
      doc.setFont("helvetica", "bold");
      doc.text(settings.businessName || "GhaniFoods", marginX, y);

      doc.setFontSize(9);
      doc.setFont("helvetica", "normal");
      y += 16;
      doc.text(settings.address || "", marginX, y);

      doc.setFontSize(20);
      doc.setFont("helvetica", "bold");
      doc.text("INVOICE", 595 - marginX, 56, { align: "right" });
      doc.setFontSize(10);
      doc.setFont("helvetica", "normal");
      doc.text(invoice.id, 595 - marginX, 74, { align: "right" });
      doc.text(invoice.invoiceDate, 595 - marginX, 88, { align: "right" });

      y += 32;
      doc.setDrawColor(200);
      doc.line(marginX, y, 595 - marginX, y);

      y += 24;
      doc.setFontSize(9);
      doc.setTextColor(120);
      doc.text("BILLED TO", marginX, y);
      y += 14;
      doc.setFontSize(12);
      doc.setTextColor(20);
      doc.setFont("helvetica", "bold");
      doc.text(invoice.customerName, marginX, y);
      doc.setFont("helvetica", "normal");

      y += 30;
      const colItem = marginX;
      const colQty = 330;
      const colPrice = 400;
      const colSubtotal = 500;

      doc.setFillColor(23, 23, 23);
      doc.rect(marginX, y - 14, 595 - marginX * 2, 22, "F");
      doc.setTextColor(255);
      doc.setFontSize(9);
      doc.setFont("helvetica", "bold");
      doc.text("ITEM", colItem + 6, y + 1);
      doc.text("QTY", colQty, y + 1);
      doc.text("UNIT PRICE", colPrice, y + 1);
      doc.text("SUBTOTAL", colSubtotal, y + 1);

      y += 22;
      doc.setTextColor(30);
      doc.setFont("helvetica", "normal");
      doc.setFontSize(10);

      const lines = invoice.items.length > 0
        ? invoice.items
        : [{ itemName: "Nimko Carton (legacy record)", qty: 0, unitPrice: 0, subtotal: invoice.totalAmount, itemId: "" }];

      for (const line of lines) {
        doc.text(String(line.itemName), colItem + 6, y);
        doc.text(line.qty ? String(line.qty) : "-", colQty, y);
        doc.text(line.unitPrice ? `Rs. ${line.unitPrice.toLocaleString()}` : "-", colPrice, y);
        doc.text(`Rs. ${line.subtotal.toLocaleString()}`, colSubtotal, y);
        y += 20;
        doc.setDrawColor(230);
        doc.line(marginX, y - 6, 595 - marginX, y - 6);
      }

      y += 20;
      doc.setFont("helvetica", "bold");
      doc.setFontSize(12);
      doc.text("Total:", colPrice, y);
      doc.text(`Rs. ${invoice.totalAmount.toLocaleString()}`, colSubtotal, y);

      y += 50;
      doc.setFont("helvetica", "normal");
      doc.setFontSize(9);
      doc.setTextColor(120);
      doc.text(settings.invoiceFooterText || "Thank you for your business!", marginX, y);

      doc.save(`${invoice.id}.pdf`);
      toast.success(`Invoice ${invoice.id} downloaded as PDF`);
    } catch (err) {
      toast.error("Could not generate PDF. Please try again.");
      console.error(err);
    } finally {
      setGeneratingPdf(false);
    }
  };

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
        <button
          onClick={handleDownloadPDF}
          disabled={generatingPdf}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800 disabled:opacity-50"
        >
          {generatingPdf ? "Generating..." : "Download PDF"}
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
Write-Utf8NoBom $invoiceDetailPath $invoiceDetailContent

# --------------------------------------------------------------------------
# 5. Ant Design dead code cleanup
# --------------------------------------------------------------------------

$antdProviderPath = Join-Path $FrontendRoot "components\layout\AntdThemeProvider.tsx"
if (Test-Path $antdProviderPath) {
    Remove-Item $antdProviderPath -Force
    Write-Host "  Removed:  $($antdProviderPath.Substring($Root.Path.Length).TrimStart('\')) (dead code, never wired into layout.tsx)" -ForegroundColor Yellow
} else {
    Write-Host "  Skipped:  AntdThemeProvider.tsx already absent" -ForegroundColor Gray
}

# --------------------------------------------------------------------------
# 6. package.json - add jspdf, remove unused antd packages
# --------------------------------------------------------------------------

$pkgPath = Join-Path $FrontendRoot "package.json"
$pkgJson = Get-Content $pkgPath -Raw | ConvertFrom-Json

$depsToRemove = @("antd", "@ant-design/icons", "@ant-design/nextjs-registry")
foreach ($dep in $depsToRemove) {
    if ($pkgJson.dependencies.PSObject.Properties.Name -contains $dep) {
        $pkgJson.dependencies.PSObject.Properties.Remove($dep)
        Write-Host "  Removed dependency: $dep" -ForegroundColor Yellow
    }
}

if (-not ($pkgJson.dependencies.PSObject.Properties.Name -contains "jspdf")) {
    $pkgJson.dependencies | Add-Member -MemberType NoteProperty -Name "jspdf" -Value "^2.5.2"
    Write-Host "  Added dependency: jspdf" -ForegroundColor Green
}

$pkgJson | ConvertTo-Json -Depth 10 | Set-Content -Path $pkgPath -Encoding UTF8
Write-Host "  Updated: $($pkgPath.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green

# --------------------------------------------------------------------------
# 7. Install updated dependencies
# --------------------------------------------------------------------------

Write-Host "`n=== Installing dependencies (npm install) ===" -ForegroundColor Cyan
Push-Location $FrontendRoot
try {
    npm install
} finally {
    Pop-Location
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Changes applied:" -ForegroundColor Green
Write-Host "  1. FIFO leftover consumption now actually deducts from source batch and blends cost" -ForegroundColor Gray
Write-Host "  2. Invoice 'Download PDF' now generates a real PDF via jsPDF" -ForegroundColor Gray
Write-Host "  3. Unused AntdThemeProvider + antd packages removed" -ForegroundColor Gray
Write-Host "`nRun 'npm run dev' (or 'npm run dev:frontend') to see the changes." -ForegroundColor Yellow