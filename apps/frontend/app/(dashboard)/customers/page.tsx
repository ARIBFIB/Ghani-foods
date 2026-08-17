"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Customer } from "@/lib/store";
import { customerSchema, type CustomerFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function BalanceCell({ balance }: { balance: number }) {
  const owes = balance > 0;
  const isZero = balance === 0;
  return (
    <span className={isZero ? "text-[var(--text-muted)]" : owes ? "text-red-400" : "text-green-400"}>
      Rs. {Math.abs(balance).toLocaleString()} {!isZero && (owes ? "(owes)" : "(credit)")}
    </span>
  );
}

function AddCustomerDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addCustomer = useStore((s) => s.addCustomer);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<CustomerFormValues>({
    resolver: zodResolver(customerSchema),
    defaultValues: { name: "", phone: "", openingBalance: 0 },
  });
  if (!open) return null;
  const onSubmit = async (values: CustomerFormValues) => {
    addCustomer(values);
    toast.success(`Customer "${values.name}" added`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Customer</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Phone</label>
            <input {...register("phone")} placeholder="0300-1234567"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.phone && <p className="text-xs text-red-400 mt-1">{errors.phone.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Opening Balance</label>
            <input {...register("openingBalance")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.openingBalance && <p className="text-xs text-red-400 mt-1">{errors.openingBalance.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function CustomersPage() {
  const items = useStore((s) => s.customers);
  const [dialogOpen, setDialogOpen] = useState(false);

  const columns = useMemo<ColumnDef<Customer, unknown>[]>(() => [
    {
      accessorKey: "name", header: "Name",
      cell: ({ row }) => <Link href={`/customers/${row.original.id}`} className="text-[var(--foreground)] hover:underline">{row.original.name}</Link>,
    },
    { accessorKey: "phone", header: "Phone" },
    {
      accessorKey: "currentBalance", header: "Current Balance",
      cell: ({ row }) => <BalanceCell balance={row.original.currentBalance} />,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Customers</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Customer
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search customers..." />
      <AddCustomerDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}