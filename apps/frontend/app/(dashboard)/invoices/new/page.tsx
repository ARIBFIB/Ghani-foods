"use client";

import { Suspense, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { invoiceHeaderSchema, type InvoiceHeaderFormValues } from "@/lib/schemas";

type InvoiceLine = { id: string; itemId: string; qty: string; unitPrice: string };

function NewInvoiceForm() {
  const router = useRouter();
  const { navigate } = useNavigationLoading();
  const searchParams = useSearchParams();
  const preselectedCustomerId = searchParams.get("customerId") ?? "";

  const customers = useStore((s) => s.customers);
  const finishedCartons = useStore((s) => s.finishedCartons);
  const lastSoldPrice = useStore((s) => s.lastSoldPrice);
  const createInvoice = useStore((s) => s.createInvoice);

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<InvoiceHeaderFormValues>({
    resolver: zodResolver(invoiceHeaderSchema),
    defaultValues: { customerId: preselectedCustomerId || customers[0]?.id || "", margin: 20 },
  });
  const customerId = watch("customerId");
  const margin = watch("margin");

  const [lines, setLines] = useState<InvoiceLine[]>([
    { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" },
  ]);
  const [lineError, setLineError] = useState("");

  const addLine = () => setLines((prev) => [...prev, { id: crypto.randomUUID(), itemId: finishedCartons[0]?.id ?? "", qty: "1", unitPrice: "" }]);
  const removeLine = (id: string) => setLines((prev) => (prev.length > 1 ? prev.filter((l) => l.id !== id) : prev));
  const updateLine = (id: string, patch: Partial<InvoiceLine>) =>
    setLines((prev) => prev.map((l) => (l.id === id ? { ...l, ...patch } : l)));

  const handleItemChange = (id: string, itemId: string) => {
    const carton = finishedCartons.find((c) => c.id === itemId);
    const memorized = lastSoldPrice(customerId, itemId);
    const marginMultiplier = 1 + (Number(margin) || 0) / 100;
    const fallback = carton ? Math.round(carton.costPerCarton * marginMultiplier) : 0;
    updateLine(id, { itemId, unitPrice: String(memorized ?? fallback) });
  };

  const total = useMemo(() => lines.reduce((sum, l) => sum + (Number(l.qty) || 0) * (Number(l.unitPrice) || 0), 0), [lines]);

  const onSubmit = async (values: InvoiceHeaderFormValues) => {
    setLineError("");
    const parsedLines = lines
      .filter((l) => l.itemId && Number(l.qty) > 0)
      .map((l) => ({ itemId: l.itemId, qty: Number(l.qty), unitPrice: Number(l.unitPrice) || 0 }));

    if (parsedLines.length === 0) {
      setLineError("Add at least one invoice item with a quantity greater than 0");
      return;
    }
    const insufficient = parsedLines.find((l) => {
      const c = finishedCartons.find((fc) => fc.id === l.itemId);
      return c && l.qty > c.stockQty;
    });
    if (insufficient) {
      setLineError("Not enough finished carton stock for one of the items");
      return;
    }
    const invalidPrice = parsedLines.find((l) => l.unitPrice <= 0);
    if (invalidPrice) {
      setLineError("Every line needs a unit price greater than 0");
      return;
    }

    const newId = createInvoice({ customerId: values.customerId, lines: parsedLines });
    toast.success(`Invoice ${newId} created â€” stock deducted, ledger updated`);
    navigate(`/invoices/${newId}`);
  };

  const selectedCustomer = customers.find((c) => c.id === customerId);

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-[var(--foreground)]">New Invoice</h1>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <div>
          <label className="text-sm text-[var(--text-muted)]">Customer</label>
          <select {...register("customerId")}
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          {errors.customerId && <p className="text-xs text-red-400 mt-1">{errors.customerId.message}</p>}
          {selectedCustomer && (
            <p className="text-xs text-[var(--text-faint)] mt-1">
              Current balance: Rs. {Math.abs(selectedCustomer.currentBalance).toLocaleString()}{" "}
              {selectedCustomer.currentBalance > 0 ? "(owes)" : "(credit)"}
            </p>
          )}
        </div>

        <div>
          <label className="text-sm text-[var(--text-muted)]">Margin % (used for items with no price history)</label>
          <input {...register("margin")} type="number" step="any"
            className="mt-1 w-40 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.margin && <p className="text-xs text-red-400 mt-1">{errors.margin.message}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[var(--foreground)]">Invoice Items</h2>
          <button type="button" onClick={addLine} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">+ Add Item</button>
        </div>

        <div className="space-y-3">
          {lines.map((line) => {
            const memorized = lastSoldPrice(customerId, line.itemId);
            const carton = finishedCartons.find((c) => c.id === line.itemId);
            return (
              <div key={line.id} className="space-y-1">
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
                  <select value={line.itemId} onChange={(e) => handleItemChange(line.id, e.target.value)}
                    className="flex-1 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                    {finishedCartons.map((c) => <option key={c.id} value={c.id}>{c.name} â€” {c.stockQty} in stock</option>)}
                  </select>
                  <input value={line.qty} onChange={(e) => updateLine(line.id, { qty: e.target.value })} type="number" placeholder="Qty"
                    className="w-full sm:w-20 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                  <input value={line.unitPrice} onChange={(e) => updateLine(line.id, { unitPrice: e.target.value })} type="number" placeholder="Unit Price"
                    className="w-full sm:w-28 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                  <button type="button" onClick={() => removeLine(line.id)} className="rounded-lg border border-[var(--surface-border)] px-3 py-2 text-sm text-[var(--text-muted)] hover:bg-[var(--surface-hover)]">-</button>
                </div>
                <div className="flex gap-2">
                  {memorized !== undefined && (
                    <span className="inline-block rounded-full bg-[var(--surface-hover)] px-2.5 py-0.5 text-xs text-[var(--text-secondary)]">
                      Last price: Rs. {memorized.toLocaleString()}
                    </span>
                  )}
                  {carton && Number(line.qty) > carton.stockQty && (
                    <span className="inline-block rounded-full bg-red-950 border border-red-900 px-2.5 py-0.5 text-xs text-red-400">
                      Only {carton.stockQty} in stock
                    </span>
                  )}
                </div>
              </div>
            );
          })}
          {lineError && <p className="text-xs text-red-400">{lineError}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 flex items-center justify-between">
        <span className="text-sm text-[var(--text-muted)]">Total</span>
        <span className="text-2xl font-semibold text-[var(--foreground)]">Rs. {total.toLocaleString()}</span>
      </div>

      <div className="flex justify-end gap-2">
        <button type="button" onClick={() => navigate("/invoices")} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
        <button type="submit" disabled={isSubmitting}
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
          {isSubmitting ? "Saving..." : "Save & Generate Invoice"}
        </button>
      </div>
    </form>
  );
}

export default function NewInvoicePage() {
  return (
    <Suspense fallback={<div className="text-[var(--text-muted)] text-sm">Loading...</div>}>
      <NewInvoiceForm />
    </Suspense>
  );
}