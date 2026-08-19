// lib/mock-data/payments.ts
export type Payment = {
  id: string;
  customerId: string;
  customerName: string;
  amount: number;
  note: string;
  paidAt: string;
};

export const payments: Payment[] = [
  { id: "pay-1", customerId: "cust-2", customerName: "Bilal Traders", amount: 9200, note: "Full settlement inv-1002", paidAt: "2026-08-15" },
  { id: "pay-2", customerId: "cust-1", customerName: "Al-Madina General Store", amount: 5800, note: "Partial payment", paidAt: "2026-08-16" },
];