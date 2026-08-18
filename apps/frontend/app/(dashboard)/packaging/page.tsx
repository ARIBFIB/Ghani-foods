"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Wrapper, type Box } from "@/lib/store";
import { wrapperSchema, boxSchema, restockSchema, type WrapperFormValues, type BoxFormValues, type RestockFormValues } from "@/lib/schemas";
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

function AddWrapperDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addWrapper = useStore((s) => s.addWrapper);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<WrapperFormValues>({
    resolver: zodResolver(wrapperSchema),
    defaultValues: { name: "", unitCost: 0, lowStockThreshold: 500 },
  });
  if (!open) return null;
  const onSubmit = async (values: WrapperFormValues) => {
    addWrapper(values);
    toast.success(`Wrapper "${values.name}" added`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Wrapper</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Rs. 5 Wrapper"
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
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

function AddBoxDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addBox = useStore((s) => s.addBox);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<BoxFormValues>({
    resolver: zodResolver(boxSchema),
    defaultValues: { name: "", unitCost: 0, lowStockThreshold: 100 },
  });
  if (!open) return null;
  const onSubmit = async (values: BoxFormValues) => {
    addBox(values);
    toast.success(`Box "${values.name}" added`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Box</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Box (12 packets)"
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
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

type RestockTarget = { kind: "wrapper" | "box"; item: Wrapper | Box } | null;

function RestockDialog({ target, onClose }: { target: RestockTarget; onClose: () => void }) {
  const restockWrapper = useStore((s) => s.restockWrapper);
  const restockBox = useStore((s) => s.restockBox);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<RestockFormValues>({ resolver: zodResolver(restockSchema) });

  if (!target) return null;
  const { kind, item } = target;

  const onSubmit = async (values: RestockFormValues) => {
    if (kind === "wrapper") restockWrapper(item.id, values.qty, values.cost ?? 0);
    else restockBox(item.id, values.qty, values.cost ?? 0);
    toast.success(`Restocked ${item.name}`);
    reset(); onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
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
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function PackagingPage() {
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const [tab, setTab] = useState<"wrappers" | "boxes">("wrappers");
  const [addWrapperOpen, setAddWrapperOpen] = useState(false);
  const [addBoxOpen, setAddBoxOpen] = useState(false);
  const [restockTarget, setRestockTarget] = useState<RestockTarget>(null);

  const wrapperColumns = useMemo<ColumnDef<Wrapper, unknown>[]>(() => [
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
        <button onClick={() => setRestockTarget({ kind: "wrapper", item: row.original })}
          className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Restock
        </button>
      ),
    },
  ], []);

  const boxColumns = useMemo<ColumnDef<Box, unknown>[]>(() => [
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
        <button onClick={() => setRestockTarget({ kind: "box", item: row.original })}
          className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Restock
        </button>
      ),
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Packaging Materials</h1>
        <div className="flex items-center gap-2">
          <Link href="/packaging/carton-config" className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
            Carton Configurations
          </Link>
          {tab === "wrappers" ? (
            <button onClick={() => setAddWrapperOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
              + Add Wrapper
            </button>
          ) : (
            <button onClick={() => setAddBoxOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
              + Add Box
            </button>
          )}
        </div>
      </div>

      <div className="flex gap-2 border-b border-[var(--surface-border)]">
        <button onClick={() => setTab("wrappers")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "wrappers" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Wrappers
        </button>
        <button onClick={() => setTab("boxes")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "boxes" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Boxes
        </button>
      </div>

      {tab === "wrappers" ? (
        <SortableTable data={wrappers} columns={wrapperColumns} globalFilterPlaceholder="Search wrappers..." />
      ) : (
        <SortableTable data={boxes} columns={boxColumns} globalFilterPlaceholder="Search boxes..." />
      )}

      <AddWrapperDialog open={addWrapperOpen} onClose={() => setAddWrapperOpen(false)} />
      <AddBoxDialog open={addBoxOpen} onClose={() => setAddBoxOpen(false)} />
      <RestockDialog target={restockTarget} onClose={() => setRestockTarget(null)} />
    </div>
  );
}