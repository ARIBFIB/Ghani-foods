"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Supplier } from "@/lib/store";
import { supplierSchema, type SupplierFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function AddSupplierDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addSupplier = useStore((s) => s.addSupplier);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<SupplierFormValues>({
    resolver: zodResolver(supplierSchema),
    defaultValues: { name: "", phone: "", address: "" },
  });
  if (!open) return null;
  const onSubmit = async (values: SupplierFormValues) => {
    addSupplier(values);
    toast.success(`Supplier "${values.name}" added`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Supplier</h2>
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
            <label className="text-sm text-[var(--text-muted)]">Address (optional)</label>
            <input {...register("address")}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function SuppliersPage() {
  const suppliers = useStore((s) => s.suppliers);
  const receipts = useStore((s) => s.receipts);
  const [dialogOpen, setDialogOpen] = useState(false);

  type Row = Supplier & { totalPurchases: number; lastPurchaseDate: string };

  const rows = useMemo<Row[]>(() => {
    return suppliers.map((sup) => {
      const supReceipts = receipts.filter((r) => r.supplierId === sup.id);
      const lastPurchaseDate = supReceipts.length > 0
        ? supReceipts.map((r) => r.purchaseDate).sort().reverse()[0]
        : "-";
      return { ...sup, totalPurchases: supReceipts.length, lastPurchaseDate };
    });
  }, [suppliers, receipts]);

  const columns = useMemo<ColumnDef<Row, unknown>[]>(() => [
    {
      accessorKey: "name", header: "Name",
      cell: ({ row }) => <Link href={`/suppliers/${row.original.id}`} className="text-[var(--foreground)] hover:underline">{row.original.name}</Link>,
    },
    { accessorKey: "phone", header: "Phone" },
    { accessorKey: "totalPurchases", header: "Total Purchases" },
    { accessorKey: "lastPurchaseDate", header: "Last Purchase Date" },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Suppliers</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Add Supplier
        </button>
      </div>
      <SortableTable data={rows} columns={columns} globalFilterPlaceholder="Search suppliers..." />
      <AddSupplierDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}