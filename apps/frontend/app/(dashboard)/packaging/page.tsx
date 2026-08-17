"use client";

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type PackagingMaterial } from "@/lib/store";
import { packagingMaterialSchema, restockSchema, type PackagingMaterialFormValues, type RestockFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddPackagingDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addPackagingMaterial = useStore((s) => s.addPackagingMaterial);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<PackagingMaterialFormValues>({
    resolver: zodResolver(packagingMaterialSchema),
    defaultValues: { name: "", unitCost: 0, lowStockThreshold: 50 },
  });
  if (!open) return null;
  const onSubmit = async (values: PackagingMaterialFormValues) => {
    addPackagingMaterial(values);
    toast.success(`"${values.name}" added`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Packaging Material</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Carton Box (Large)"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Unit Cost</label>
            <input {...register("unitCost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.unitCost && <p className="text-xs text-red-400 mt-1">{errors.unitCost.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Low Stock Threshold</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
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

function RestockDialog({ open, onClose, item }: { open: boolean; onClose: () => void; item: PackagingMaterial | null }) {
  const restockPackaging = useStore((s) => s.restockPackaging);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<RestockFormValues>({ resolver: zodResolver(restockSchema) });
  if (!open || !item) return null;
  const onSubmit = async (values: RestockFormValues) => {
    restockPackaging(item.id, values.qty, values.cost ?? 0);
    toast.success(`Restocked ${item.name}`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Restock: {item.name}</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Quantity to Add</label>
            <input {...register("qty")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Cost per unit (optional)</label>
            <input {...register("cost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
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

export default function PackagingPage() {
  const items = useStore((s) => s.packagingMaterials);
  const [addOpen, setAddOpen] = useState(false);
  const [restockTarget, setRestockTarget] = useState<PackagingMaterial | null>(null);

  const columns = useMemo<ColumnDef<PackagingMaterial, unknown>[]>(() => [
    { accessorKey: "name", header: "Name", cell: ({ getValue }) => <span className="text-[var(--foreground)]">{getValue() as string}</span> },
    { accessorKey: "unitCost", header: "Unit Cost", cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}` },
    { accessorKey: "stockQty", header: "Stock Qty", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    { accessorKey: "lowStockThreshold", header: "Threshold", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge isLow={row.original.stockQty < row.original.lowStockThreshold} />,
    },
    {
      id: "action", header: "", enableSorting: false,
      cell: ({ row }) => (
        <button onClick={() => setRestockTarget(row.original)}
          className="rounded-lg border border-[var(--surface-border-strong)] px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Restock
        </button>
      ),
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Packaging Materials</h1>
        <button onClick={() => setAddOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + Add Packaging Material
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search packaging..." />
      <AddPackagingDialog open={addOpen} onClose={() => setAddOpen(false)} />
      <RestockDialog open={!!restockTarget} onClose={() => setRestockTarget(null)} item={restockTarget} />
    </div>
  );
}