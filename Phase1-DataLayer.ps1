# Phase1-DataLayer.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\Phase1-DataLayer.ps1
#
# PHASE 1 of 5 - Data Layer
# Rewrites apps\frontend\lib\store.ts and apps\frontend\lib\schemas.ts to add:
#   - Supplier, Wrapper, Box, CartonConfiguration types
#   - RawMaterialReceipt.supplierId / purchaseDate
#   - FinishedCarton.configId / cartonsProduced
#   - New store actions (addSupplier, addWrapper, addBox, addCartonConfiguration,
#     createPackingRun rewritten to auto-calculate from cartonsProduced only)
#
# IMPORTANT: after this script, the project will NOT build cleanly yet.
# Pages that still reference the old `packagingMaterials` array
# (packaging/page.tsx, finished-cartons/page.tsx, dashboard page.tsx,
# topbar.tsx, reports/page.tsx) will show TypeScript errors until
# Phase 2 - Phase 5 scripts update them. This is expected - see the
# summary printed at the end of this script.

$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$FrontendLib = Join-Path $ProjectRoot "apps\frontend\lib"

if (-not (Test-Path $FrontendLib)) {
    Write-Host "ERROR: apps\frontend\lib not found. Run this script from the GhaniFoods root." -ForegroundColor Red
    exit 1
}

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Host "=== Phase 1: Data Layer (store.ts + schemas.ts) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# lib/schemas.ts
# ---------------------------------------------------------------------------
$schemasContent = @'
import { z } from "zod";

export const rawMaterialSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  unit: z.string().trim().min(1, "Unit is required"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
});
export type RawMaterialFormValues = z.infer<typeof rawMaterialSchema>;

// Supplier-linked purchase receipt. supplierId is required (existing supplier
// picked from combobox, or a freshly created one). purchaseDate defaults to
// today but is always required per BRS FR-5.
export const purchaseSchema = z.object({
  supplierId: z.string().min(1, "Select a supplier"),
  purchaseDate: z.string().min(1, "Purchase date is required"),
  qty: z.coerce.number().positive("Quantity must be greater than 0"),
  cost: z.coerce.number().positive("Cost must be greater than 0"),
});
export type PurchaseFormValues = z.infer<typeof purchaseSchema>;

export const supplierSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  phone: z
    .string()
    .trim()
    .min(7, "Enter a valid phone number")
    .regex(/^[0-9+\-()\s]+$/, "Phone can only contain digits, spaces, + - ( )"),
  address: z.string().trim().optional(),
});
export type SupplierFormValues = z.infer<typeof supplierSchema>;

// Wrapper materials (wraps a single packet - Rs.5 / Rs.10 packet etc.)
export const wrapperSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  unitCost: z.coerce.number().min(0, "Unit cost cannot be negative"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
});
export type WrapperFormValues = z.infer<typeof wrapperSchema>;

// Box materials (holds a defined number of packets)
export const boxSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  unitCost: z.coerce.number().min(0, "Unit cost cannot be negative"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
});
export type BoxFormValues = z.infer<typeof boxSchema>;

export const restockSchema = z.object({
  qty: z.coerce.number().positive("Quantity must be greater than 0"),
  cost: z.coerce.number().min(0, "Cost cannot be negative").optional(),
});
export type RestockFormValues = z.infer<typeof restockSchema>;

// Carton Configuration: Wrapper x Packets-per-Box x Box x Boxes-per-Carton.
// Drives all auto-calculation during a packing run (FR-10, FR-17 - FR-21).
export const cartonConfigSchema = z.object({
  wrapperId: z.string().min(1, "Select a wrapper"),
  packetsPerBox: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
  boxId: z.string().min(1, "Select a box"),
  boxesPerCarton: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
});
export type CartonConfigFormValues = z.infer<typeof cartonConfigSchema>;

// Packing Run: the ONLY manual input is cartonsProduced. Everything else
// (boxes, packets, material deductions, cost build-up) is derived in the
// store from batchId + configId + cartonsProduced (FR-17).
export const packingRunSchema = z.object({
  batchId: z.string().min(1, "Select a batch"),
  configId: z.string().min(1, "Select a carton configuration"),
  cartonsProduced: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
});
export type PackingRunFormValues = z.infer<typeof packingRunSchema>;

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

$schemasPath = Join-Path $FrontendLib "schemas.ts"
Write-Utf8NoBom -Path $schemasPath -Content $schemasContent
Write-Host "  [1/2] Wrote apps\frontend\lib\schemas.ts" -ForegroundColor Green

# ---------------------------------------------------------------------------
# lib/store.ts
# ---------------------------------------------------------------------------
$storeContent = @'
"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

export type Supplier = {
  id: string;
  name: string;
  phone: string;
  address?: string;
};

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
  supplierId: string;
  purchaseDate: string;
  date: string; // kept for backward compat with existing UI (mirrors purchaseDate)
  qty: number;
  cost: number;
};

// Wrapper: used to wrap a single packet (e.g. Rs.5 / Rs.10 packet)
export type Wrapper = {
  id: string;
  name: string;
  unitCost: number;
  stockQty: number;
  lowStockThreshold: number;
};

// Box: holds a defined number of packets
export type Box = {
  id: string;
  name: string;
  unitCost: number;
  stockQty: number;
  lowStockThreshold: number;
};

// Carton Configuration: Wrapper x Packets-per-Box x Box x Boxes-per-Carton
export type CartonConfiguration = {
  id: string;
  wrapperId: string;
  packetsPerBox: number;
  boxId: string;
  boxesPerCarton: number;
  usedInPackingRun: boolean; // once true, read-only per BRS assumption
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
  configId: string;
  cartonsProduced: number;
  packetsPerCarton: number; // derived: packetsPerBox * boxesPerCarton, kept for display
  costPerCarton: number;
  costPerBox: number;
  costPerPacket: number;
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

// ---------------------------------------------------------------------------
// Seed / dummy data
// ---------------------------------------------------------------------------

const initialSuppliers: Supplier[] = [
  { id: "sup-1", name: "Malik Traders", phone: "0301-2345678", address: "Rawalpindi" },
  { id: "sup-2", name: "Al-Fateh Agro Suppliers", phone: "0322-9988776", address: "Mansehra" },
  { id: "sup-3", name: "Khyber Ghee Distributors", phone: "0345-1122334", address: "Abbottabad" },
];

const initialRawMaterials: RawMaterial[] = [
  { id: "rm-1", name: "Atta (Flour)", unit: "kg", quantityInStock: 420, avgUnitCost: 145.5, lowStockThreshold: 100 },
  { id: "rm-2", name: "Ghee", unit: "kg", quantityInStock: 65, avgUnitCost: 780, lowStockThreshold: 80 },
  { id: "rm-3", name: "Salt", unit: "kg", quantityInStock: 210, avgUnitCost: 28, lowStockThreshold: 50 },
  { id: "rm-4", name: "Spice Mix", unit: "kg", quantityInStock: 34, avgUnitCost: 620, lowStockThreshold: 40 },
];

const initialReceipts: RawMaterialReceipt[] = [
  { id: "r-1", rawMaterialId: "rm-1", supplierId: "sup-1", purchaseDate: "2026-08-12", date: "2026-08-12", qty: 200, cost: 142.0 },
  { id: "r-2", rawMaterialId: "rm-1", supplierId: "sup-1", purchaseDate: "2026-08-01", date: "2026-08-01", qty: 150, cost: 148.5 },
  { id: "r-3", rawMaterialId: "rm-1", supplierId: "sup-2", purchaseDate: "2026-07-20", date: "2026-07-20", qty: 100, cost: 146.0 },
  { id: "r-4", rawMaterialId: "rm-2", supplierId: "sup-3", purchaseDate: "2026-08-05", date: "2026-08-05", qty: 40, cost: 770 },
];

const initialWrappers: Wrapper[] = [
  { id: "wr-1", name: "Rs. 5 Wrapper", unitCost: 0.8, stockQty: 5000, lowStockThreshold: 1000 },
  { id: "wr-2", name: "Rs. 10 Wrapper", unitCost: 1.2, stockQty: 3200, lowStockThreshold: 800 },
];

const initialBoxes: Box[] = [
  { id: "bx-1", name: "Box (12 packets)", unitCost: 8, stockQty: 400, lowStockThreshold: 100 },
  { id: "bx-2", name: "Box (24 packets)", unitCost: 12, stockQty: 250, lowStockThreshold: 80 },
];

const initialCartonConfigurations: CartonConfiguration[] = [
  { id: "cc-1", wrapperId: "wr-1", packetsPerBox: 12, boxId: "bx-1", boxesPerCarton: 4, usedInPackingRun: true },
  { id: "cc-2", wrapperId: "wr-2", packetsPerBox: 24, boxId: "bx-2", boxesPerCarton: 2, usedInPackingRun: false },
];

const initialBatches: ProductionBatch[] = [
  { id: "batch-1", batchDate: "2026-08-10", outputYieldKg: 500, wastageKg: 8, leftoverQtyKg: 40, bulkCostPerKg: 210.75, overheadTotal: 0, status: "completed" },
  { id: "batch-2", batchDate: "2026-08-13", outputYieldKg: 480, wastageKg: 5, leftoverQtyKg: 480, bulkCostPerKg: 205.3, overheadTotal: 0, status: "completed" },
  { id: "batch-3", batchDate: "2026-08-16", outputYieldKg: 300, wastageKg: 0, leftoverQtyKg: 300, bulkCostPerKg: 0, overheadTotal: 0, status: "in_progress" },
];

const initialCartons: FinishedCarton[] = [
  { id: "fc-1", name: "batch-1 Carton (cc-1)", sourceBatchId: "batch-1", configId: "cc-1", cartonsProduced: 85, packetsPerCarton: 48, costPerCarton: 610, costPerBox: 152.5, costPerPacket: 12.71, stockQty: 85 },
  { id: "fc-2", name: "batch-2 Carton (cc-2)", sourceBatchId: "batch-2", configId: "cc-2", cartonsProduced: 42, packetsPerCarton: 48, costPerCarton: 1150, costPerBox: 575, costPerPacket: 23.96, stockQty: 42 },
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
  suppliers: Supplier[];
  rawMaterials: RawMaterial[];
  receipts: RawMaterialReceipt[];
  wrappers: Wrapper[];
  boxes: Box[];
  cartonConfigurations: CartonConfiguration[];
  productionBatches: ProductionBatch[];
  finishedCartons: FinishedCarton[];
  customers: Customer[];
  customerItemPrices: CustomerItemPrice[];
  invoices: Invoice[];
  ledgerEntries: LedgerEntry[];
  payments: Payment[];
  settings: AppSettings;

  addSupplier: (item: { name: string; phone: string; address?: string }) => string;

  addRawMaterial: (item: { name: string; unit: string; lowStockThreshold: number }) => void;
  recordPurchase: (rawMaterialId: string, qty: number, cost: number, supplierId: string, purchaseDate: string) => void;

  addWrapper: (item: { name: string; unitCost: number; lowStockThreshold: number }) => void;
  restockWrapper: (wrapperId: string, qty: number, cost: number) => void;
  addBox: (item: { name: string; unitCost: number; lowStockThreshold: number }) => void;
  restockBox: (boxId: string, qty: number, cost: number) => void;

  addCartonConfiguration: (input: { wrapperId: string; packetsPerBox: number; boxId: string; boxesPerCarton: number }) => string;

  createBatch: (input: {
    consumptions: { rawMaterialId: string; qty: number }[];
    outputYieldKg: number;
    wastageKg: number;
    leftoverBatchId?: string;
    leftoverKgUsed?: number;
  }) => string;
  allocateOverhead: (batchId: string, electricity: number, gas: number, rent: number) => void;

  // Rewritten: only batchId + configId + cartonsProduced. Boxes produced,
  // packets produced, wrapper/box deduction, and cost/packet-box-carton are
  // all derived internally (FR-17 - FR-22).
  createPackingRun: (input: { batchId: string; configId: string; cartonsProduced: number }) => void;

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
      suppliers: initialSuppliers,
      rawMaterials: initialRawMaterials,
      receipts: initialReceipts,
      wrappers: initialWrappers,
      boxes: initialBoxes,
      cartonConfigurations: initialCartonConfigurations,
      productionBatches: initialBatches,
      finishedCartons: initialCartons,
      customers: initialCustomers,
      customerItemPrices: initialItemPrices,
      invoices: initialInvoices,
      ledgerEntries: initialLedger,
      payments: initialPayments,
      settings: initialSettings,

      addSupplier: (item) => {
        const id = `sup-${Date.now()}`;
        set((s) => ({
          suppliers: [...s.suppliers, { id, name: item.name, phone: item.phone, address: item.address }],
        }));
        return id;
      },

      addRawMaterial: (item) =>
        set((s) => ({
          rawMaterials: [
            ...s.rawMaterials,
            { id: `rm-${Date.now()}`, name: item.name, unit: item.unit, quantityInStock: 0, avgUnitCost: 0, lowStockThreshold: item.lowStockThreshold },
          ],
        })),

      // FR-5 / FR-6 / FR-7: every purchase is a supplier-linked, dated
      // receipt. Weighted average cost = ((existingQty*existingAvg) +
      // (newQty*newCost)) / (existingQty+newQty).
      recordPurchase: (rawMaterialId, qty, cost, supplierId, purchaseDate) =>
        set((s) => {
          const rawMaterials = s.rawMaterials.map((m) => {
            if (m.id !== rawMaterialId) return m;
            const newQty = m.quantityInStock + qty;
            const newAvgCost = newQty > 0 ? (m.quantityInStock * m.avgUnitCost + qty * cost) / newQty : m.avgUnitCost;
            return { ...m, quantityInStock: newQty, avgUnitCost: Number(newAvgCost.toFixed(2)) };
          });
          const receipts: RawMaterialReceipt[] = [
            { id: `r-${Date.now()}`, rawMaterialId, supplierId, purchaseDate, date: purchaseDate, qty, cost },
            ...s.receipts,
          ];
          return { rawMaterials, receipts };
        }),

      addWrapper: (item) =>
        set((s) => ({
          wrappers: [
            ...s.wrappers,
            { id: `wr-${Date.now()}`, name: item.name, unitCost: item.unitCost, stockQty: 0, lowStockThreshold: item.lowStockThreshold },
          ],
        })),

      restockWrapper: (wrapperId, qty, cost) =>
        set((s) => ({
          wrappers: s.wrappers.map((w) => {
            if (w.id !== wrapperId) return w;
            const newQty = w.stockQty + qty;
            const newCost = cost > 0 ? (w.stockQty * w.unitCost + qty * cost) / newQty : w.unitCost;
            return { ...w, stockQty: newQty, unitCost: Number(newCost.toFixed(2)) };
          }),
        })),

      addBox: (item) =>
        set((s) => ({
          boxes: [
            ...s.boxes,
            { id: `bx-${Date.now()}`, name: item.name, unitCost: item.unitCost, stockQty: 0, lowStockThreshold: item.lowStockThreshold },
          ],
        })),

      restockBox: (boxId, qty, cost) =>
        set((s) => ({
          boxes: s.boxes.map((b) => {
            if (b.id !== boxId) return b;
            const newQty = b.stockQty + qty;
            const newCost = cost > 0 ? (b.stockQty * b.unitCost + qty * cost) / newQty : b.unitCost;
            return { ...b, stockQty: newQty, unitCost: Number(newCost.toFixed(2)) };
          }),
        })),

      addCartonConfiguration: (input) => {
        const id = `cc-${Date.now()}`;
        set((s) => ({
          cartonConfigurations: [
            ...s.cartonConfigurations,
            { id, wrapperId: input.wrapperId, packetsPerBox: input.packetsPerBox, boxId: input.boxId, boxesPerCarton: input.boxesPerCarton, usedInPackingRun: false },
          ],
        }));
        return id;
      },

      // ------------------------------------------------------------------
      // FIFO leftover logic (FR-15): unchanged from prior version.
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

      // ------------------------------------------------------------------
      // Packing Run - FR-17 to FR-22:
      // Only batchId + configId + cartonsProduced come from the user.
      //   boxesProduced   = cartonsProduced * boxesPerCarton
      //   packetsProduced = boxesProduced * packetsPerBox
      // Wrapper stock deducted by packetsProduced, Box stock deducted by
      // boxesProduced. Bulk leftover (kg) is consumed proportionally -
      // here we treat each carton as consuming an even share of leftover,
      // matching the batch's existing bulkCostPerKg. Cost build-up:
      //   costPerPacket = bulkCostShare/packetsProduced + wrapper.unitCost
      //   costPerBox    = packetsPerBox * costPerPacket + box.unitCost
      //   costPerCarton = boxesPerCarton * costPerBox
      // ------------------------------------------------------------------
      createPackingRun: (input) =>
        set((s) => {
          const batch = s.productionBatches.find((b) => b.id === input.batchId);
          const config = s.cartonConfigurations.find((c) => c.id === input.configId);
          if (!batch || !config) return {};
          const wrapper = s.wrappers.find((w) => w.id === config.wrapperId);
          const box = s.boxes.find((b) => b.id === config.boxId);
          if (!wrapper || !box) return {};

          const boxesProduced = input.cartonsProduced * config.boxesPerCarton;
          const packetsProduced = boxesProduced * config.packetsPerBox;

          // Estimate bulk kg used: assume ~1 packet = a fixed nominal share
          // of the batch's leftover; here we simply cap usage at whatever
          // leftover remains, splitting it evenly by cartons produced
          // relative to total cartons the leftover could still support.
          // For dummy/demo purposes we allocate leftover proportionally to
          // packetsProduced against a nominal 0.05kg-per-packet estimate,
          // capped by what's actually available.
          const nominalKgPerPacket = 0.05;
          const estimatedKgNeeded = packetsProduced * nominalKgPerPacket;
          const bulkKgUsed = Math.min(estimatedKgNeeded, batch.leftoverQtyKg);

          const bulkCostShare = batch.bulkCostPerKg * bulkKgUsed;
          const costPerPacket = packetsProduced > 0 ? bulkCostShare / packetsProduced + wrapper.unitCost : wrapper.unitCost;
          const costPerBox = config.packetsPerBox * costPerPacket + box.unitCost;
          const costPerCarton = config.boxesPerCarton * costPerBox;

          const productionBatches = s.productionBatches.map((b) =>
            b.id === input.batchId
              ? { ...b, leftoverQtyKg: Math.max(0, Number((b.leftoverQtyKg - bulkKgUsed).toFixed(2))), status: "completed" as const }
              : b
          );
          const wrappers = s.wrappers.map((w) =>
            w.id === config.wrapperId ? { ...w, stockQty: Math.max(0, w.stockQty - packetsProduced) } : w
          );
          const boxes = s.boxes.map((b) =>
            b.id === config.boxId ? { ...b, stockQty: Math.max(0, b.stockQty - boxesProduced) } : b
          );
          const cartonConfigurations = s.cartonConfigurations.map((c) =>
            c.id === config.id ? { ...c, usedInPackingRun: true } : c
          );

          const newCarton: FinishedCarton = {
            id: `fc-${Date.now()}`,
            name: `${batch.id} Carton (${config.id})`,
            sourceBatchId: batch.id,
            configId: config.id,
            cartonsProduced: input.cartonsProduced,
            packetsPerCarton: config.packetsPerBox * config.boxesPerCarton,
            costPerCarton: Number(costPerCarton.toFixed(2)),
            costPerBox: Number(costPerBox.toFixed(2)),
            costPerPacket: Number(costPerPacket.toFixed(2)),
            stockQty: input.cartonsProduced,
          };

          return {
            productionBatches,
            wrappers,
            boxes,
            cartonConfigurations,
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

$storePath = Join-Path $FrontendLib "store.ts"
Write-Utf8NoBom -Path $storePath -Content $storeContent
Write-Host "  [2/2] Wrote apps\frontend\lib\store.ts" -ForegroundColor Green

Write-Host "`n=== Phase 1 complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "DONE in this script:" -ForegroundColor Yellow
Write-Host "  - lib/schemas.ts   : supplierSchema, wrapperSchema, boxSchema, cartonConfigSchema," -ForegroundColor Gray
Write-Host "                       packingRunSchema added. purchaseSchema now requires supplierId + purchaseDate." -ForegroundColor Gray
Write-Host "  - lib/store.ts     : Supplier, Wrapper, Box, CartonConfiguration types + seed data added." -ForegroundColor Gray
Write-Host "                       packagingMaterials REMOVED, replaced by wrappers[] + boxes[]." -ForegroundColor Gray
Write-Host "                       New actions: addSupplier, addWrapper, restockWrapper, addBox, restockBox," -ForegroundColor Gray
Write-Host "                       addCartonConfiguration. recordPurchase signature changed (adds supplierId, purchaseDate)." -ForegroundColor Gray
Write-Host "                       createPackingRun REWRITTEN: now takes only {batchId, configId, cartonsProduced}" -ForegroundColor Gray
Write-Host "                       and derives boxes/packets/costs/stock deductions internally." -ForegroundColor Gray
Write-Host ""
Write-Host "NOT done yet (Phase 2-5, coming next):" -ForegroundColor Yellow
Write-Host "  - app/(dashboard)/suppliers/page.tsx               (NEW - list + add dialog)" -ForegroundColor Gray
Write-Host "  - app/(dashboard)/suppliers/[id]/page.tsx          (NEW - detail + purchase history)" -ForegroundColor Gray
Write-Host "  - app/(dashboard)/packaging/carton-config/page.tsx (NEW - config list + create form)" -ForegroundColor Gray
Write-Host "  - app/(dashboard)/packaging/page.tsx               (REWRITE - Wrappers/Boxes tabs)" -ForegroundColor Gray
Write-Host "  - app/(dashboard)/raw-materials/page.tsx           (UPDATE - Add dialog needs Supplier + date)" -ForegroundColor Gray
Write-Host "  - app/(dashboard)/raw-materials/[id]/page.tsx      (UPDATE - Supplier column + dialog)" -ForegroundColor Gray
Write-Host "  - app/(dashboard)/finished-cartons/page.tsx        (REWRITE - Packing Run simplified to 1 input)" -ForegroundColor Gray
Write-Host "  - app/(dashboard)/page.tsx (Dashboard)              (UPDATE - Add Raw Material dialog, packagingMaterials refs)" -ForegroundColor Gray
Write-Host "  - components/ui/topbar.tsx                          (UPDATE - low-stock alerts need wrappers+boxes, not packagingMaterials)" -ForegroundColor Gray
Write-Host "  - components/ui/sidebar-component.tsx               (UPDATE - add 'suppliers' section/nav item)" -ForegroundColor Gray
Write-Host "  - app/(dashboard)/reports/page.tsx                  (UPDATE - inventory chart needs wrappers+boxes, not packagingMaterials)" -ForegroundColor Gray
Write-Host ""
Write-Host "WARNING: project will NOT type-check / build cleanly until Phase 2-5 scripts" -ForegroundColor Red
Write-Host "are run, because those pages above still import/reference the old" -ForegroundColor Red
Write-Host "'packagingMaterials' array and old recordPurchase/createPackingRun signatures." -ForegroundColor Red
Write-Host "This is expected mid-refactor - next script (Phase 2) will fix Raw Materials + Suppliers pages." -ForegroundColor Yellow