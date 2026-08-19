"use client";

import { create } from "zustand";
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

// =============================================================================
// Types (BRS v1.2 / Frontend Spec v2.2 domain model)
// =============================================================================

export type Supplier = {
  id: string;
  name: string;
  phone: string;
  address?: string;
};

export type RawMaterial = {
  id: string;
  name: string;
  unit: string; // e.g. "kg", "g" - drives grams-conversion for Wrapper/Box consumption
  quantityInStock: number;
  avgUnitCost: number;
  lowStockThreshold: number;
};

// PurchaseReceipt (header) + PurchaseReceiptLine (New, FR-5/FR-7)
export type PurchaseReceipt = {
  id: string;
  supplierId: string;
  purchaseDate: string;
};

export type PurchaseReceiptLine = {
  id: string;
  receiptId: string;
  rawMaterialId: string;
  qty: number;
  cost: number;
};

// Wrapper / Box - now raw-material-linked production outputs (FR-11 - FR-15)
export type Wrapper = {
  id: string;
  name: string;
  rawMaterialId: string;
  gramsPerUnit: number;
  stockQty: number;
  lowStockThreshold: number;
};

export type Box = {
  id: string;
  name: string;
  rawMaterialId: string;
  gramsPerUnit: number;
  stockQty: number;
  lowStockThreshold: number;
};

export type WrapperProductionRun = {
  id: string;
  wrapperId: string;
  quantityProduced: number;
  gramsConsumed: number;
  date: string;
};

export type BoxProductionRun = {
  id: string;
  boxId: string;
  quantityProduced: number;
  gramsConsumed: number;
  date: string;
};

// Carton Configuration - now named (FR-16)
export type CartonConfiguration = {
  id: string;
  name: string;
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
  name: string; // mirrors the source Carton Configuration's Name
  sourceBatchId: string;
  configId: string;
  cartonsProduced: number;
  packetsPerCarton: number;
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

// Keyed by (customerId, itemId) - drives live price auto-fill and the
// price-source note on invoice lines (FR-34, FR-35).
export type CustomerItemPrice = {
  customerId: string;
  itemId: string;
  lastSoldPrice: number;
  lastSoldDate: string;
};

export type InvoiceLineRecord = {
  itemId: string;
  itemName: string;
  qty: number;
  unitPrice: number;
  subtotal: number;
  priceSourceNote?: string; // e.g. "First sale - margin applied" or "Last sold on 2026-08-10 at Rs. 640"
};

// Invoice - no Paid/Unpaid/Partial status field (FR-40).
export type Invoice = {
  id: string;
  customerId: string;
  customerName: string;
  invoiceDate: string;
  totalAmount: number;
  items: InvoiceLineRecord[];
};

// Customer Ledger - explicit direction on every entry (FR-41, FR-42).
// NOTE ON DIRECTION SEMANTICS (flagged as an open question in the BRS itself,
// section 11): "received" = payment received from the customer, "given" =
// amount given to the customer or a credit-note/adjustment in their favor.
// Both directions reduce the outstanding running balance - the running
// balance only ever increases via an "invoice" type entry (a debit). The
// direction field is retained as audit/reporting metadata (payment vs.
// credit adjustment), not as a differently-signed balance operation. This
// should be confirmed with the client per BRS 11 before go-live.
export type LedgerEntryType = "invoice" | "payment" | "adjustment";
export type LedgerDirection = "received" | "given";

export type LedgerEntry = {
  id: string;
  customerId: string;
  type: LedgerEntryType;
  direction: LedgerDirection | null; // null for "invoice" type entries (always a debit)
  amount: number; // always a positive magnitude
  runningBalance: number;
  date: string;
  note?: string;
};

export type Payment = {
  id: string;
  customerId: string;
  customerName: string;
  amount: number;
  direction: LedgerDirection;
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

// =============================================================================
// Unit-conversion helper for Wrapper/Box grams-per-unit consumption (FR-12 -
// FR-15). Raw materials linked to a Wrapper/Box may be stocked in "kg" or
// "g" - this normalizes both to a common grams basis so gram-level
// consumption math is always correct regardless of the material's unit.
// =============================================================================

function unitToGramsMultiplier(unit: string): number {
  const u = unit.trim().toLowerCase();
  if (u === "kg" || u === "kilogram" || u === "kilograms") return 1000;
  if (u === "g" || u === "gram" || u === "grams") return 1;
  // Unknown unit: assume already gram-equivalent rather than silently
  // mis-converting.
  return 1;
}

export function computePackagingUnitCost(gramsPerUnit: number, rawMaterial: RawMaterial | undefined): number {
  if (!rawMaterial) return 0;
  const multiplier = unitToGramsMultiplier(rawMaterial.unit);
  const costPerGram = rawMaterial.avgUnitCost / multiplier;
  return gramsPerUnit * costPerGram;
}

const today = () => new Date().toISOString().slice(0, 10);

// =============================================================================
// Seed / dummy data
// =============================================================================

const initialSuppliers: Supplier[] = [
  { id: "sup-1", name: "Malik Traders", phone: "0301-2345678", address: "Rawalpindi" },
  { id: "sup-2", name: "Al-Fateh Agro Suppliers", phone: "0322-9988776", address: "Mansehra" },
  { id: "sup-3", name: "Khyber Ghee Distributors", phone: "0345-1122334", address: "Abbottabad" },
  { id: "sup-4", name: "Frontier Packaging Supplies", phone: "0333-4455667", address: "Peshawar" },
];

const initialRawMaterials: RawMaterial[] = [
  { id: "rm-1", name: "Atta (Flour)", unit: "kg", quantityInStock: 420, avgUnitCost: 145.5, lowStockThreshold: 100 },
  { id: "rm-2", name: "Ghee", unit: "kg", quantityInStock: 65, avgUnitCost: 780, lowStockThreshold: 80 },
  { id: "rm-3", name: "Salt", unit: "kg", quantityInStock: 210, avgUnitCost: 28, lowStockThreshold: 50 },
  { id: "rm-4", name: "Spice Mix", unit: "kg", quantityInStock: 34, avgUnitCost: 620, lowStockThreshold: 40 },
  // Underlying raw materials for Wrapper/Box production (FR-12, FR-13).
  { id: "rm-5", name: "Wrapper Paper", unit: "g", quantityInStock: 500000, avgUnitCost: 0.08, lowStockThreshold: 50000 },
  { id: "rm-6", name: "Cardboard / Gatta", unit: "g", quantityInStock: 300000, avgUnitCost: 0.05, lowStockThreshold: 30000 },
];

// Each legacy single-item purchase becomes its own one-line PurchaseReceipt.
// The shape now supports multiple lines per receipt going forward (FR-5).
const initialReceipts: PurchaseReceipt[] = [
  { id: "rcpt-1", supplierId: "sup-1", purchaseDate: "2026-08-12" },
  { id: "rcpt-2", supplierId: "sup-1", purchaseDate: "2026-08-01" },
  { id: "rcpt-3", supplierId: "sup-2", purchaseDate: "2026-07-20" },
  { id: "rcpt-4", supplierId: "sup-3", purchaseDate: "2026-08-05" },
];

const initialReceiptLines: PurchaseReceiptLine[] = [
  { id: "rline-1", receiptId: "rcpt-1", rawMaterialId: "rm-1", qty: 200, cost: 142.0 },
  { id: "rline-2", receiptId: "rcpt-2", rawMaterialId: "rm-1", qty: 150, cost: 148.5 },
  { id: "rline-3", receiptId: "rcpt-3", rawMaterialId: "rm-1", qty: 100, cost: 146.0 },
  { id: "rline-4", receiptId: "rcpt-4", rawMaterialId: "rm-2", qty: 40, cost: 770 },
];

const initialWrappers: Wrapper[] = [
  { id: "wr-1", name: "Rs. 5 Wrapper", rawMaterialId: "rm-5", gramsPerUnit: 2, stockQty: 5000, lowStockThreshold: 1000 },
  { id: "wr-2", name: "Rs. 10 Wrapper", rawMaterialId: "rm-5", gramsPerUnit: 3, stockQty: 3200, lowStockThreshold: 800 },
];

const initialBoxes: Box[] = [
  { id: "bx-1", name: "Box (12 packets)", rawMaterialId: "rm-6", gramsPerUnit: 40, stockQty: 400, lowStockThreshold: 100 },
  { id: "bx-2", name: "Box (24 packets)", rawMaterialId: "rm-6", gramsPerUnit: 60, stockQty: 250, lowStockThreshold: 80 },
];

const initialWrapperProductionRuns: WrapperProductionRun[] = [];
const initialBoxProductionRuns: BoxProductionRun[] = [];

const initialCartonConfigurations: CartonConfiguration[] = [
  { id: "cc-1", name: "Carton A - 48pk", wrapperId: "wr-1", packetsPerBox: 12, boxId: "bx-1", boxesPerCarton: 4, usedInPackingRun: true },
  { id: "cc-2", name: "Carton B - 48pk", wrapperId: "wr-2", packetsPerBox: 24, boxId: "bx-2", boxesPerCarton: 2, usedInPackingRun: false },
];

const initialBatches: ProductionBatch[] = [
  { id: "batch-1", batchDate: "2026-08-10", outputYieldKg: 500, wastageKg: 8, leftoverQtyKg: 40, bulkCostPerKg: 210.75, overheadTotal: 0, status: "completed" },
  { id: "batch-2", batchDate: "2026-08-13", outputYieldKg: 480, wastageKg: 5, leftoverQtyKg: 480, bulkCostPerKg: 205.3, overheadTotal: 0, status: "completed" },
  { id: "batch-3", batchDate: "2026-08-16", outputYieldKg: 300, wastageKg: 0, leftoverQtyKg: 300, bulkCostPerKg: 0, overheadTotal: 0, status: "in_progress" },
];

const initialCartons: FinishedCarton[] = [
  { id: "fc-1", name: "Carton A - 48pk", sourceBatchId: "batch-1", configId: "cc-1", cartonsProduced: 85, packetsPerCarton: 48, costPerCarton: 610, costPerBox: 152.5, costPerPacket: 12.71, stockQty: 85 },
  { id: "fc-2", name: "Carton B - 48pk", sourceBatchId: "batch-2", configId: "cc-2", cartonsProduced: 42, packetsPerCarton: 48, costPerCarton: 1150, costPerBox: 575, costPerPacket: 23.96, stockQty: 42 },
];

const initialCustomers: Customer[] = [
  { id: "cust-1", name: "Al-Madina General Store", phone: "0300-1234567", currentBalance: 12500 },
  { id: "cust-2", name: "Bilal Traders", phone: "0333-9988776", currentBalance: -2000 },
  { id: "cust-3", name: "Rehman Wholesale", phone: "0345-1122334", currentBalance: 0 },
];

const initialItemPrices: CustomerItemPrice[] = [
  { customerId: "cust-1", itemId: "fc-1", lastSoldPrice: 640, lastSoldDate: "2026-08-15" },
  { customerId: "cust-2", itemId: "fc-2", lastSoldPrice: 1180, lastSoldDate: "2026-08-14" },
];

const initialInvoices: Invoice[] = [
  { id: "inv-1001", customerId: "cust-1", customerName: "Al-Madina General Store", invoiceDate: "2026-08-15", totalAmount: 18300, items: [] },
  { id: "inv-1002", customerId: "cust-2", customerName: "Bilal Traders", invoiceDate: "2026-08-14", totalAmount: 9200, items: [] },
  { id: "inv-1003", customerId: "cust-3", customerName: "Rehman Wholesale", invoiceDate: "2026-08-12", totalAmount: 4600, items: [] },
];

const initialLedger: LedgerEntry[] = [
  { id: "led-1", customerId: "cust-1", type: "adjustment", direction: "given", amount: 4000, runningBalance: 4000, date: "2026-07-01", note: "Opening balance" },
  { id: "led-2", customerId: "cust-1", type: "invoice", direction: null, amount: 8700, runningBalance: 12700, date: "2026-08-05", note: "inv-1000" },
  { id: "led-3", customerId: "cust-1", type: "payment", direction: "received", amount: 5800, runningBalance: 6900, date: "2026-08-10", note: "Partial payment" },
  { id: "led-4", customerId: "cust-1", type: "invoice", direction: null, amount: 18300, runningBalance: 25200, date: "2026-08-15", note: "inv-1001" },
  { id: "led-5", customerId: "cust-1", type: "payment", direction: "received", amount: 12700, runningBalance: 12500, date: "2026-08-16", note: "Partial payment" },
  { id: "led-6", customerId: "cust-2", type: "invoice", direction: null, amount: 9200, runningBalance: 9200, date: "2026-08-14", note: "inv-1002" },
  { id: "led-7", customerId: "cust-2", type: "payment", direction: "received", amount: 9200, runningBalance: 0, date: "2026-08-15", note: "Full settlement" },
  { id: "led-8", customerId: "cust-2", type: "adjustment", direction: "given", amount: 2000, runningBalance: -2000, date: "2026-08-16", note: "Credit note" },
  { id: "led-9", customerId: "cust-3", type: "invoice", direction: null, amount: 4600, runningBalance: 4600, date: "2026-08-12", note: "inv-1003" },
];

const initialPayments: Payment[] = [
  { id: "pay-1", customerId: "cust-2", customerName: "Bilal Traders", amount: 9200, direction: "received", note: "Full settlement inv-1002", paidAt: "2026-08-15" },
  { id: "pay-2", customerId: "cust-1", customerName: "Al-Madina General Store", amount: 5800, direction: "received", note: "Partial payment", paidAt: "2026-08-16" },
];

const initialSettings: AppSettings = {
  businessName: "GhaniFoods",
  address: "Mansehra, Khyber Pakhtunkhwa, Pakistan",
  invoiceFooterText: "Thank you for your business!",
  defaultProfitMarginPercent: 20,
  lowStockThresholdDefault: 50,
};

// =============================================================================
// Store
// =============================================================================

type State = {
  suppliers: Supplier[];
  rawMaterials: RawMaterial[];
  receipts: PurchaseReceipt[];
  receiptLines: PurchaseReceiptLine[];
  wrappers: Wrapper[];
  boxes: Box[];
  wrapperProductionRuns: WrapperProductionRun[];
  boxProductionRuns: BoxProductionRun[];
  cartonConfigurations: CartonConfiguration[];
  productionBatches: ProductionBatch[];
  finishedCartons: FinishedCarton[];
  customers: Customer[];
  customerItemPrices: CustomerItemPrice[];
  invoices: Invoice[];
  ledgerEntries: LedgerEntry[];
  payments: Payment[];
  settings: AppSettings;

  // Suppliers
  addSupplier: (item: { name: string; phone: string; address?: string }) => Promise<string>;

  // Raw materials + multi-item Purchase Receipts (FR-4 - FR-10)
  addRawMaterial: (item: { name: string; unit: string; lowStockThreshold: number }) => Promise<string>;
  createPurchaseReceipt: (input: {
    supplierId: string;
    purchaseDate: string;
    items: { rawMaterialId: string; qty: number; cost: number }[];
  }) => Promise<string>;
  loadRawMaterialsModule: () => Promise<void>;

  // Wrapper / Box - Define + Produce (FR-11 - FR-15)
  addWrapper: (item: { name: string; rawMaterialId: string; gramsPerUnit: number; lowStockThreshold: number }) => string;
  produceWrapper: (wrapperId: string, quantityProduced: number) => { ok: boolean; reason?: string };
  addBox: (item: { name: string; rawMaterialId: string; gramsPerUnit: number; lowStockThreshold: number }) => string;
  produceBox: (boxId: string, quantityProduced: number) => { ok: boolean; reason?: string };
  wrapperUnitCost: (wrapperId: string) => number;
  boxUnitCost: (boxId: string) => number;

  // Carton Configuration (FR-16)
  addCartonConfiguration: (input: {
    name: string;
    wrapperId: string;
    packetsPerBox: number;
    boxId: string;
    boxesPerCarton: number;
  }) => string;

  // Production Batch
  createBatch: (input: {
    consumptions: { rawMaterialId: string; qty: number }[];
    outputYieldKg: number;
    wastageKg: number;
    leftoverBatchId?: string;
    leftoverKgUsed?: number;
  }) => string;
  allocateOverhead: (batchId: string, electricity: number, gas: number, rent: number) => void;

  // Packing Run (FR-23 - FR-31)
  createPackingRun: (input: { batchId: string; configId: string; cartonsProduced: number }) => void;

  // Customers, Invoicing, Ledger (FR-32 - FR-45)
  addCustomer: (item: { name: string; phone: string; openingBalance: number }) => string;
  recordLedgerEntry: (customerId: string, amount: number, direction: LedgerDirection, note: string) => void;

  lastSoldPriceInfo: (customerId: string, itemId: string) => { price: number; date: string } | undefined;
  createInvoice: (input: {
    customerId: string;
    lines: { itemId: string; qty: number; unitPrice: number; priceSourceNote?: string }[];
  }) => string;

  updateSettings: (patch: Partial<AppSettings>) => void;
};

export const useStore = create<State>()(
  persist(
    (set, get) => ({
      suppliers: initialSuppliers,
      rawMaterials: initialRawMaterials,
      receipts: initialReceipts,
      receiptLines: initialReceiptLines,
      wrappers: initialWrappers,
      boxes: initialBoxes,
      wrapperProductionRuns: initialWrapperProductionRuns,
      boxProductionRuns: initialBoxProductionRuns,
      cartonConfigurations: initialCartonConfigurations,
      productionBatches: initialBatches,
      finishedCartons: initialCartons,
      customers: initialCustomers,
      customerItemPrices: initialItemPrices,
      invoices: initialInvoices,
      ledgerEntries: initialLedger,
      payments: initialPayments,
      settings: initialSettings,

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

      addWrapper: (item) => {
        const id = `wr-${Date.now()}`;
        set((s) => ({
          wrappers: [
            ...s.wrappers,
            { id, name: item.name, rawMaterialId: item.rawMaterialId, gramsPerUnit: item.gramsPerUnit, stockQty: 0, lowStockThreshold: item.lowStockThreshold },
          ],
        }));
        return id;
      },

      // FR-14: quantity-only production run. Grams consumed = gramsPerUnit *
      // quantityProduced, deducted from the underlying raw material (in
      // grams, converted per that material's unit), added to Wrapper stock.
      produceWrapper: (wrapperId, quantityProduced) => {
        const s = get();
        const wrapper = s.wrappers.find((w) => w.id === wrapperId);
        if (!wrapper) return { ok: false, reason: "Wrapper not found" };
        const rawMaterial = s.rawMaterials.find((m) => m.id === wrapper.rawMaterialId);
        if (!rawMaterial) return { ok: false, reason: "Underlying raw material not found" };

        const multiplier = unitToGramsMultiplier(rawMaterial.unit);
        const gramsConsumed = wrapper.gramsPerUnit * quantityProduced;
        const stockInGrams = rawMaterial.quantityInStock * multiplier;

        if (gramsConsumed > stockInGrams) {
          return { ok: false, reason: `Not enough ${rawMaterial.name} in stock` };
        }

        set((st) => {
          const remainingGrams = stockInGrams - gramsConsumed;
          const rawMaterials = st.rawMaterials.map((m) =>
            m.id === rawMaterial.id ? { ...m, quantityInStock: Number((remainingGrams / multiplier).toFixed(3)) } : m
          );
          const wrappers = st.wrappers.map((w) =>
            w.id === wrapperId ? { ...w, stockQty: w.stockQty + quantityProduced } : w
          );
          const run: WrapperProductionRun = {
            id: `wpr-${Date.now()}`,
            wrapperId,
            quantityProduced,
            gramsConsumed: Number(gramsConsumed.toFixed(2)),
            date: today(),
          };
          return { rawMaterials, wrappers, wrapperProductionRuns: [run, ...st.wrapperProductionRuns] };
        });

        return { ok: true };
      },

      addBox: (item) => {
        const id = `bx-${Date.now()}`;
        set((s) => ({
          boxes: [
            ...s.boxes,
            { id, name: item.name, rawMaterialId: item.rawMaterialId, gramsPerUnit: item.gramsPerUnit, stockQty: 0, lowStockThreshold: item.lowStockThreshold },
          ],
        }));
        return id;
      },

      produceBox: (boxId, quantityProduced) => {
        const s = get();
        const box = s.boxes.find((b) => b.id === boxId);
        if (!box) return { ok: false, reason: "Box not found" };
        const rawMaterial = s.rawMaterials.find((m) => m.id === box.rawMaterialId);
        if (!rawMaterial) return { ok: false, reason: "Underlying raw material not found" };

        const multiplier = unitToGramsMultiplier(rawMaterial.unit);
        const gramsConsumed = box.gramsPerUnit * quantityProduced;
        const stockInGrams = rawMaterial.quantityInStock * multiplier;

        if (gramsConsumed > stockInGrams) {
          return { ok: false, reason: `Not enough ${rawMaterial.name} in stock` };
        }

        set((st) => {
          const remainingGrams = stockInGrams - gramsConsumed;
          const rawMaterials = st.rawMaterials.map((m) =>
            m.id === rawMaterial.id ? { ...m, quantityInStock: Number((remainingGrams / multiplier).toFixed(3)) } : m
          );
          const boxes = st.boxes.map((b) =>
            b.id === boxId ? { ...b, stockQty: b.stockQty + quantityProduced } : b
          );
          const run: BoxProductionRun = {
            id: `bpr-${Date.now()}`,
            boxId,
            quantityProduced,
            gramsConsumed: Number(gramsConsumed.toFixed(2)),
            date: today(),
          };
          return { rawMaterials, boxes, boxProductionRuns: [run, ...st.boxProductionRuns] };
        });

        return { ok: true };
      },

      wrapperUnitCost: (wrapperId) => {
        const s = get();
        const wrapper = s.wrappers.find((w) => w.id === wrapperId);
        if (!wrapper) return 0;
        const rawMaterial = s.rawMaterials.find((m) => m.id === wrapper.rawMaterialId);
        return computePackagingUnitCost(wrapper.gramsPerUnit, rawMaterial);
      },

      boxUnitCost: (boxId) => {
        const s = get();
        const box = s.boxes.find((b) => b.id === boxId);
        if (!box) return 0;
        const rawMaterial = s.rawMaterials.find((m) => m.id === box.rawMaterialId);
        return computePackagingUnitCost(box.gramsPerUnit, rawMaterial);
      },

      addCartonConfiguration: (input) => {
        const id = `cc-${Date.now()}`;
        set((s) => ({
          cartonConfigurations: [
            ...s.cartonConfigurations,
            {
              id,
              name: input.name,
              wrapperId: input.wrapperId,
              packetsPerBox: input.packetsPerBox,
              boxId: input.boxId,
              boxesPerCarton: input.boxesPerCarton,
              usedInPackingRun: false,
            },
          ],
        }));
        return id;
      },

      // FIFO leftover logic (FR-21) - unchanged from prior version.
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

      // FR-23 - FR-27: only batchId + configId + cartonsProduced come from
      // the user. Boxes/packets produced, wrapper/box deduction, and the
      // full cost build-up (packet -> box -> carton) are all derived here.
      createPackingRun: (input) =>
        set((s) => {
          const batch = s.productionBatches.find((b) => b.id === input.batchId);
          const config = s.cartonConfigurations.find((c) => c.id === input.configId);
          if (!batch || !config) return {};
          const wrapper = s.wrappers.find((w) => w.id === config.wrapperId);
          const box = s.boxes.find((b) => b.id === config.boxId);
          if (!wrapper || !box) return {};
          const wrapperRawMaterial = s.rawMaterials.find((m) => m.id === wrapper.rawMaterialId);
          const boxRawMaterial = s.rawMaterials.find((m) => m.id === box.rawMaterialId);

          const boxesProduced = input.cartonsProduced * config.boxesPerCarton;
          const packetsProduced = boxesProduced * config.packetsPerBox;

          const nominalKgPerPacket = 0.05;
          const estimatedKgNeeded = packetsProduced * nominalKgPerPacket;
          const bulkKgUsed = Math.min(estimatedKgNeeded, batch.leftoverQtyKg);

          const bulkCostShare = batch.bulkCostPerKg * bulkKgUsed;
          const wrapperUnitCostValue = computePackagingUnitCost(wrapper.gramsPerUnit, wrapperRawMaterial);
          const boxUnitCostValue = computePackagingUnitCost(box.gramsPerUnit, boxRawMaterial);
          const costPerPacket = packetsProduced > 0 ? bulkCostShare / packetsProduced + wrapperUnitCostValue : wrapperUnitCostValue;
          const costPerBox = config.packetsPerBox * costPerPacket + boxUnitCostValue;
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
            name: config.name,
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

      // FR-42/FR-43: explicit direction required. See the LedgerDirection
      // comment above for the sign-convention caveat.
      recordLedgerEntry: (customerId, amount, direction, note) =>
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
              direction,
              amount,
              runningBalance: newBalance,
              date: today(),
              note: note || (direction === "received" ? "Payment received" : "Credit adjustment"),
            },
          ];
          const payments: Payment[] = [
            {
              id: `pay-${Date.now()}`,
              customerId,
              customerName: customer.name,
              amount,
              direction,
              note: note || (direction === "received" ? "Payment received" : "Credit adjustment"),
              paidAt: today(),
            },
            ...s.payments,
          ];
          return { customers, ledgerEntries, payments };
        }),

      lastSoldPriceInfo: (customerId, itemId) => {
        const rec = get().customerItemPrices.find((p) => p.customerId === customerId && p.itemId === itemId);
        return rec ? { price: rec.lastSoldPrice, date: rec.lastSoldDate } : undefined;
      },

      createInvoice: (input) => {
        const id = `inv-${1000 + get().invoices.length + 1}`;
        set((s) => {
          const customer = s.customers.find((c) => c.id === input.customerId);
          if (!customer) return {};
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
              priceSourceNote: line.priceSourceNote,
            });
            return { ...c, stockQty: Math.max(0, c.stockQty - line.qty) };
          });
          const totalAmount = items.reduce((sum, l) => sum + l.subtotal, 0);
          const invoiceDate = today();
          const customerItemPrices = [...s.customerItemPrices];
          for (const line of input.lines) {
            const idx = customerItemPrices.findIndex((p) => p.customerId === input.customerId && p.itemId === line.itemId);
            if (idx >= 0) customerItemPrices[idx] = { ...customerItemPrices[idx], lastSoldPrice: line.unitPrice, lastSoldDate: invoiceDate };
            else customerItemPrices.push({ customerId: input.customerId, itemId: line.itemId, lastSoldPrice: line.unitPrice, lastSoldDate: invoiceDate });
          }
          const newBalance = customer.currentBalance + totalAmount;
          const customers = s.customers.map((c) => (c.id === input.customerId ? { ...c, currentBalance: newBalance } : c));
          const ledgerEntries: LedgerEntry[] = [
            ...s.ledgerEntries,
            { id: `led-${Date.now()}`, customerId: input.customerId, type: "invoice", direction: null, amount: totalAmount, runningBalance: newBalance, date: invoiceDate, note: id },
          ];
          const newInvoice: Invoice = {
            id, customerId: input.customerId, customerName: customer.name,
            invoiceDate, totalAmount, items,
          };
          return { finishedCartons, customerItemPrices, customers, ledgerEntries, invoices: [newInvoice, ...s.invoices] };
        });
        return id;
      },

      updateSettings: (patch) =>
        set((s) => ({ settings: { ...s.settings, ...patch } })),
    }),
    { name: "ghanifoods-dummy-data-v2" }
  )
);