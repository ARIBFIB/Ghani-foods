"use client";

import { Suspense, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { customers } from "@/lib/mock-data/customers";
import { finishedCartons } from "@/lib/mock-data/finished-cartons";
import { customerItemPrices } from "@/lib/mock-data/customer-item-prices";
import { invoices } from "@/lib/mock-data/invoices";

type InvoiceLine = { id: string; itemId: string; qty: string; unitPrice: string };

function lastSoldPrice(customerId: string, itemId: string) {
  return customerItemPrices.find((p) => p.customerId === customerId && p.itemId === itemId)?.lastSoldPrice;
}

function NewInvoiceForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const preselectedCustomerId = searchParams.get("customerId") ?? "";

  const [customerId, setCustomerId] = useState(preselectedCustomerId || customers[0]?.id || "");
  const [margin, setMargin] = useState("20");
  const [lines, setLines] = useState<InvoiceLine[]>([
    { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" },
  ]);

  const addLine = () => {
    setLines((prev) => [...prev, { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" }]);
  };

  const removeLine = (id: string) => {
    setLines((prev) => (prev.length > 1 ? prev.filter((l) => l.id !== id) : prev));
  };

  const updateLine = (id: string, patch: Partial<InvoiceLine>) => {
    setLines((prev) => prev.map((l) => (l.id === id ? { ...l, ...patch } : l)));
  };

  const handleItemChange = (id: string, itemId: string) => {
    const carton = finishedCartons.find((c) => c.id === itemId);
    const memorized = lastSoldPrice(customerId, itemId);
    const marginMultiplier = 1 + (Number(margin) || 0) / 100;
    const fallback = carton ? Math.round(carton.costPerCarton * marginMultiplier) : 0;
    updateLine(id, { itemId, unitPrice: String(memorized ?? fallback) });
  };

  const total = useMemo(() => {
    return lines.reduce((sum, l) => sum + (Number(l.qty) || 0) * (Number(l.unitPrice) || 0), 0);
  }, [lines]);

  const handleSave = () => {
    // Demo build: no real persistence, navigate to an existing invoice detail.
    router.push(`/invoices/${invoices[0]?.id ?? ""}`);
  };

  const selectedCustomer = customers.find((c) => c.id === customerId);

  return (
    <div className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-neutral-50">New Invoice</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div>
          <label className="text-sm text-neutral-400">Customer</label>
          <select
            value={customerId}
            onChange={(e) => setCustomerId(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          >
            {customers.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
          {selectedCustomer && (
            <p className="text-xs text-neutral-500 mt-1">
              Current balance: Rs. {Math.abs(selectedCustomer.currentBalance).toLocaleString()}{" "}
              {selectedCustomer.currentBalance > 0 ? "(owes)" : "(credit)"}
            </p>
          )}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Margin % (used for items with no price history)</label>
          <input
            value={margin}
            onChange={(e) => setMargin(e.target.value)}
            type="number"
            className="mt-1 w-40 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-neutral-200">Invoice Items</h2>
          <button
            onClick={addLine}
            className="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs text-neutral-200 hover:bg-neutral-800"
          >
            + Add Item
          </button>
        </div>

        <div className="space-y-3">
          {lines.map((line) => {
            const memorized = lastSoldPrice(customerId, line.itemId);
            return (
              <div key={line.id} className="space-y-1">
                <div className="flex items-center gap-2">
                  <select
                    value={line.itemId}
                    onChange={(e) => handleItemChange(line.id, e.target.value)}
                    className="flex-1 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
                  >
                    {finishedCartons.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                  <input
                    value={line.qty}
                    onChange={(e) => updateLine(line.id, { qty: e.target.value })}
                    type="number"
                    placeholder="Qty"
                    className="w-20 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
                  />
                  <input
                    value={line.unitPrice}
                    onChange={(e) => updateLine(line.id, { unitPrice: e.target.value })}
                    type="number"
                    placeholder="Unit Price"
                    className="w-28 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
                  />
                  <button
                    onClick={() => removeLine(line.id)}
                    className="rounded-lg border border-neutral-800 px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800"
                  >
                    â€“
                  </button>
                </div>
                {memorized !== undefined && (
                  <span className="inline-block rounded-full bg-neutral-800 px-2.5 py-0.5 text-xs text-neutral-300">
                    Last price: Rs. {memorized.toLocaleString()}
                  </span>
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 flex items-center justify-between">
        <span className="text-sm text-neutral-400">Total</span>
        <span className="text-2xl font-semibold text-neutral-50">Rs. {total.toLocaleString()}</span>
      </div>

      <div className="flex justify-end gap-2">
        <button
          onClick={() => router.push("/invoices")}
          className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800"
        >
          Cancel
        </button>
        <button
          onClick={handleSave}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          Save & Generate Invoice
        </button>
      </div>
    </div>
  );
}

export default function NewInvoicePage() {
  return (
    <Suspense fallback={<div className="text-neutral-400 text-sm">Loading...</div>}>
      <NewInvoiceForm />
    </Suspense>
  );
}