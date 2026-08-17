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