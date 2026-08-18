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