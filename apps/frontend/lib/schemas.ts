import { z } from "zod";

// ---------------------------------------------------------------------------
// Suppliers & Raw Material master
// ---------------------------------------------------------------------------

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

// Raw material master record only - name, unit, threshold. Stock quantity
// and average cost now originate exclusively from Purchase Receipt lines
// (FR-4).
export const rawMaterialMasterSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  unit: z.string().trim().min(1, "Unit is required"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
});
export type RawMaterialMasterFormValues = z.infer<typeof rawMaterialMasterSchema>;

// ---------------------------------------------------------------------------
// Multi-item Purchase Receipt (FR-5, FR-6, FR-7)
// One Supplier + one Purchase Date, one or more line items.
// ---------------------------------------------------------------------------

export const purchaseReceiptLineSchema = z.object({
  rawMaterialId: z.string().min(1, "Select a raw material"),
  qty: z.coerce.number().positive("Quantity must be greater than 0"),
  cost: z.coerce.number().positive("Cost must be greater than 0"),
});
export type PurchaseReceiptLineValues = z.infer<typeof purchaseReceiptLineSchema>;

export const purchaseReceiptSchema = z.object({
  supplierId: z.string().min(1, "Select a supplier"),
  purchaseDate: z.string().min(1, "Purchase date is required"),
  items: z.array(purchaseReceiptLineSchema).min(1, "Add at least one item"),
});
export type PurchaseReceiptFormValues = z.infer<typeof purchaseReceiptSchema>;

// ---------------------------------------------------------------------------
// Wrapper / Box - raw-material-linked production (FR-11 - FR-15)
// ---------------------------------------------------------------------------

// Used to Define a Wrapper or a Box (same shape per BRS section 6).
export const wrapperDefinitionSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  rawMaterialId: z.string().min(1, "Select the underlying raw material"),
  gramsPerUnit: z.coerce.number().positive("Grams per unit must be greater than 0"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
});
export type WrapperDefinitionFormValues = z.infer<typeof wrapperDefinitionSchema>;

export const boxDefinitionSchema = wrapperDefinitionSchema;
export type BoxDefinitionFormValues = z.infer<typeof boxDefinitionSchema>;

// Used for a Wrapper Production Run or a Box Production Run. Only the
// quantity to produce is user-entered - grams consumed are always derived,
// never user-editable (FR-14).
export const productionRunSchema = z.object({
  quantityProduced: z.coerce
    .number()
    .int("Must be a whole number")
    .positive("Must be greater than 0"),
});
export type ProductionRunFormValues = z.infer<typeof productionRunSchema>;

// ---------------------------------------------------------------------------
// Carton Configuration - now named (FR-16)
// ---------------------------------------------------------------------------

export const cartonConfigSchema = z.object({
  name: z.string().trim().min(1, "Configuration name is required"),
  wrapperId: z.string().min(1, "Select a wrapper"),
  packetsPerBox: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
  boxId: z.string().min(1, "Select a box"),
  boxesPerCarton: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
});
export type CartonConfigFormValues = z.infer<typeof cartonConfigSchema>;

// ---------------------------------------------------------------------------
// Production Batch
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Batch Expenses & Monthly Overhead (0007)
// ---------------------------------------------------------------------------

export const batchExpenseSchema = z.object({
  name: z.string().trim().min(1, "Expense name is required"),
  amount: z.coerce.number().min(0, "Cannot be negative"),
});
export type BatchExpenseFormValues = z.infer<typeof batchExpenseSchema>;

export const monthlyExpenseSchema = z.object({
  month: z.string().min(1, "Month is required"),
  name: z.string().trim().min(1, "Expense name is required"),
  amount: z.coerce.number().min(0, "Cannot be negative"),
});
export type MonthlyExpenseFormValues = z.infer<typeof monthlyExpenseSchema>;

// ---------------------------------------------------------------------------
// Packing Run - carton count only, everything else derived (FR-23 - FR-29)
// ---------------------------------------------------------------------------

export const packingRunSchema = z.object({
  batchId: z.string().min(1, "Select a batch"),
  configId: z.string().min(1, "Select a carton configuration"),
  cartonsProduced: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
});
export type PackingRunFormValues = z.infer<typeof packingRunSchema>;

// ---------------------------------------------------------------------------
// Customers & Invoicing
// ---------------------------------------------------------------------------

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

export const invoiceHeaderSchema = z.object({
  customerId: z.string().min(1, "Select a customer"),
  margin: z.coerce.number().min(0, "Margin cannot be negative"),
});
export type InvoiceHeaderFormValues = z.infer<typeof invoiceHeaderSchema>;

// ---------------------------------------------------------------------------
// Customer Ledger - Record Payment / Adjustment, explicit direction (FR-42)
// ---------------------------------------------------------------------------

export const paymentSchema = z.object({
  customerId: z.string().min(1, "Select a customer"),
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  direction: z.enum(["received", "given"], {
    required_error: "Select a direction",
  }),
  method: z.enum(["bank", "cash"], {
    required_error: "Select Bank or Cash",
  }),
  note: z.string().trim().optional(),
});
export type PaymentFormValues = z.infer<typeof paymentSchema>;