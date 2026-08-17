"use client";

import { use, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function RecordPaymentDialog({ open, onClose, customerId }: { open: boolean; onClose: () => void; customerId: string }) {
  const recordPayment = useStore((s) => s.recordPayment);
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");

  if (!open) return null;

  const handleSave = () => {
    const a = Number(amount);
    if (!a) return;
    recordPayment(customerId, a, note);
    toast.success(`Payment of Rs. ${a.toLocaleString()} recorded`);
    setAmount("");
    setNote("");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Amount</label>
            <input value={amount} onChange={(e) => setAmount(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Note</label>
            <input value={note} onChange={(e) => setNote(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
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
        <Link href="/customers" className="text-sm text-neutral-400 hover:underline">&larr; Back to Customers</Link>
        <p className="text-neutral-400">Customer not found.</p>
      </div>
    );
  }

  const totalInvoiced = ledger.filter((l) => l.type === "invoice").reduce((sum, l) => sum + l.amount, 0);
  const totalPaid = ledger.filter((l) => l.type === "payment").reduce((sum, l) => sum + Math.abs(l.amount), 0);

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/customers" className="hover:underline text-neutral-300">Customers</Link>{" "}
        / <span className="text-neutral-50">{customer.name}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5">
        <h1 className="text-xl font-semibold text-neutral-50">{customer.name}</h1>
        <p className="text-sm text-neutral-400 mt-1">{customer.phone}</p>

        <div className="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Current Balance</div>
            <div className={`text-lg font-semibold mt-1 ${customer.currentBalance > 0 ? "text-red-400" : "text-green-400"}`}>
              Rs. {Math.abs(customer.currentBalance).toLocaleString()}
            </div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Total Invoiced</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {totalInvoiced.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Total Paid</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {totalPaid.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          + Record Payment
        </button>
        <button onClick={() => router.push(`/invoices/new?customerId=${customer.id}`)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          New Invoice for this Customer
        </button>
      </div>

      <h2 className="text-lg font-semibold text-neutral-50">Ledger History</h2>
      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Note</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Running Balance</th>
            </tr>
          </thead>
          <tbody>
            {ledger.map((l) => (
              <tr key={l.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3 text-neutral-300">{l.date}</td>
                <td className="px-4 py-3 text-neutral-300 capitalize">{l.type}</td>
                <td className="px-4 py-3 text-neutral-300">{l.note}</td>
                <td className={`px-4 py-3 ${l.amount >= 0 ? "text-red-400" : "text-green-400"}`}>
                  {l.amount >= 0 ? "+" : ""}Rs. {l.amount.toLocaleString()}
                </td>
                <td className="px-4 py-3 text-neutral-300">Rs. {l.runningBalance.toLocaleString()}</td>
              </tr>
            ))}
            {ledger.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-neutral-500">No ledger entries yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={customer.id} />
    </div>
  );
}