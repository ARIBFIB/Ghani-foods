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