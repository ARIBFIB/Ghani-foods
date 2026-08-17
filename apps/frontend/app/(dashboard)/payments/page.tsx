"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { paymentSchema, type PaymentFormValues } from "@/lib/schemas";

function RecordPaymentDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const customers = useStore((s) => s.customers);
  const recordPayment = useStore((s) => s.recordPayment);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PaymentFormValues>({
    resolver: zodResolver(paymentSchema),
    defaultValues: { customerId: customers[0]?.id ?? "", amount: 0, note: "" },
  });

  if (!open) return null;

  const onSubmit = async (values: PaymentFormValues) => {
    recordPayment(values.customerId, values.amount, values.note ?? "");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Customer</label>
            <select {...register("customerId")}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600">
              {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            {errors.customerId && <p className="text-xs text-red-400 mt-1">{errors.customerId.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Amount</label>
            <input {...register("amount")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
            {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
          </div>
          <div>
            <label className="text-sm text-neutral-400">Note</label>
            <input {...register("note")}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function PaymentsPage() {
  const items = useStore((s) => s.payments);
  const [dialogOpen, setDialogOpen] = useState(false);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Payments</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Record Payment
        </button>
      </div>

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Customer</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Note</th>
            </tr>
          </thead>
          <tbody>
            {items.map((p) => (
              <tr key={p.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3 text-neutral-300">{p.paidAt}</td>
                <td className="px-4 py-3 text-neutral-50">{p.customerName}</td>
                <td className="px-4 py-3 text-green-400">Rs. {p.amount.toLocaleString()}</td>
                <td className="px-4 py-3 text-neutral-300">{p.note}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}