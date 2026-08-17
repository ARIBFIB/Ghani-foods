// lib/mock-data/ledger.ts
export type LedgerEntry = {
  id: string;
  customerId: string;
  type: "invoice" | "payment" | "adjustment";
  amount: number;
  runningBalance: number;
  date: string;
  note?: string;
};

export const ledgerEntries: LedgerEntry[] = [
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