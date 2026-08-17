"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { z } from "zod";

const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  note: z.string().trim().optional(),
});
type PaymentAmountValues = z.infer<typeof paymentAmountSchema>;

function RecordPaymentDialog({ open, onClose, customerId }: { open: boolean; onClose: () => void; customerId: string }) {
  const recordPayment = useStore((s) => s.recordPayment);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PaymentAmountValues>({ resolver: zodResolver(paymentAmountSchema) });

  if (!open) return null;

  const onSubmit = async (values: PaymentAmountValues) => {
    recordPayment(customerId, values.amount, values.note ?? "");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Amount</label>
            <input {...register("amount")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Note</label>
            <input {...register("note")}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function CustomerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const customer = useStore((s) => s.customers.find((c) => c.id === id));
  const allLedger = useStore((s) => s.ledgerEntries);
  const [dialogOpen, setDialogOpen] = useState(false);

  const ledger = useMemo(() => allLedger.filter((l) => l.customerId === id), [allLedger, id]);

  if (!customer) {
    return (
      <div className="space-y-4">
        <Link href="/customers" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Customers</Link>
        <p className="text-[var(--text-muted)]">Customer not found.</p>
      </div>
    );
  }

  const totalInvoiced = ledger.filter((l) => l.type === "invoice").reduce((sum, l) => sum + l.amount, 0);
  const totalPaid = ledger.filter((l) => l.type === "payment").reduce((sum, l) => sum + Math.abs(l.amount), 0);

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <Link href="/customers" className="hover:underline text-[var(--text-secondary)]">Customers</Link>{" "}
        / <span className="text-[var(--foreground)]">{customer.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">{customer.name}</h1>
        <p className="text-sm text-[var(--text-muted)] mt-1">{customer.phone}</p>

        <div className="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Current Balance</div>
            <div className={`text-lg font-semibold mt-1 ${customer.currentBalance > 0 ? "text-red-400" : "text-green-400"}`}>
              Rs. {Math.abs(customer.currentBalance).toLocaleString()}
            </div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Invoiced</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {totalInvoiced.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Paid</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {totalPaid.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-[var(--surface-border-strong)] px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          + Record Payment
        </button>
        <button onClick={() => router.push(`/invoices/new?customerId=${customer.id}`)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          New Invoice for this Customer
        </button>
      </div>

      <h2 className="text-lg font-semibold text-[var(--foreground)]">Ledger History</h2>
      <div className="overflow-hidden rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Note</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Running Balance</th>
            </tr>
          </thead>
          <tbody>
            {ledger.map((l) => (
              <tr key={l.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                <td className="px-4 py-3 text-[var(--text-secondary)]">{l.date}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)] capitalize">{l.type}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">{l.note}</td>
                <td className={`px-4 py-3 ${l.amount >= 0 ? "text-red-400" : "text-green-400"}`}>
                  {l.amount >= 0 ? "+" : ""}Rs. {l.amount.toLocaleString()}
                </td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {l.runningBalance.toLocaleString()}</td>
              </tr>
            ))}
            {ledger.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-[var(--foreground)]0">No ledger entries yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={customer.id} />
    </div>
  );
}