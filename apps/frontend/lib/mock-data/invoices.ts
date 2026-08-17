// lib/mock-data/invoices.ts
export type Invoice = {
  id: string;
  customerId: string;
  customerName: string;
  invoiceDate: string;
  totalAmount: number;
  status: "unpaid" | "partial" | "paid";
};

export const invoices: Invoice[] = [
  { id: "inv-1001", customerId: "cust-1", customerName: "Al-Madina General Store", invoiceDate: "2026-08-15", totalAmount: 18300, status: "partial" },
  { id: "inv-1002", customerId: "cust-2", customerName: "Bilal Traders", invoiceDate: "2026-08-14", totalAmount: 9200, status: "paid" },
  { id: "inv-1003", customerId: "cust-3", customerName: "Rehman Wholesale", invoiceDate: "2026-08-12", totalAmount: 4600, status: "unpaid" },
];