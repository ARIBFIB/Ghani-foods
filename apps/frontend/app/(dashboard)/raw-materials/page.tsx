"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { z } from "zod";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type RawMaterial } from "@/lib/store";
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

// Purchase-receipt style form: raw material name + unit (new material only),
// supplier (existing or inline "+ Add Supplier"), purchase date, qty, cost.
const addFlowSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters"),
  unit: z.string().trim().min(1, "Unit is required"),
  lowStockThreshold: z.coerce.number().min(0, "Threshold cannot be negative"),
  supplierId: z.string().min(1, "Select or add a supplier"),
  purchaseDate: z.string().min(1, "Purchase date is required"),
  qty: z.coerce.number().positive("Quantity must be greater than 0"),
  cost: z.coerce.number().positive("Cost must be greater than 0"),
});
type AddFlowValues = z.infer<typeof addFlowSchema>;

function AddRawMaterialDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const recordPurchase = useStore((s) => s.recordPurchase);
  const suppliers = useStore((s) => s.suppliers);
  const addSupplier = useStore((s) => s.addSupplier);
  const rawMaterials = useStore((s) => s.rawMaterials);

  const [showAddSupplier, setShowAddSupplier] = useState(false);
  const [newSupplierName, setNewSupplierName] = useState("");
  const [newSupplierPhone, setNewSupplierPhone] = useState("");

  const today = new Date().toISOString().slice(0, 10);

  const { register, handleSubmit, control, reset, setValue, formState: { errors, isSubmitting } } = useForm<AddFlowValues>({
    resolver: zodResolver(addFlowSchema),
    defaultValues: { name: "", unit: "kg", lowStockThreshold: 50, supplierId: suppliers[0]?.id ?? "", purchaseDate: today, qty: 0, cost: 0 },
  });

  if (!open) return null;

  const handleInlineAddSupplier = () => {
    if (!newSupplierName.trim() || !newSupplierPhone.trim()) return;
    const id = addSupplier({ name: newSupplierName.trim(), phone: newSupplierPhone.trim() });
    setValue("supplierId", id);
    setNewSupplierName("");
    setNewSupplierPhone("");
    setShowAddSupplier(false);
    toast.success(`Supplier "${newSupplierName.trim()}" added`);
  };

  const onSubmit = async (values: AddFlowValues) => {
    let materialId = rawMaterials.find((m) => m.name.toLowerCase() === values.name.trim().toLowerCase())?.id;
    if (!materialId) {
      addRawMaterial({ name: values.name.trim(), unit: values.unit, lowStockThreshold: values.lowStockThreshold });
      materialId = useStore.getState().rawMaterials.find((m) => m.name.toLowerCase() === values.name.trim().toLowerCase())?.id;
    }
    if (materialId) {
      recordPurchase(materialId, values.qty, values.cost, values.supplierId, values.purchaseDate);
    }
    toast.success(`Raw material "${values.name.trim()}" - purchase recorded`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Raw Material (Purchase Receipt)</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Unit (only used if this is a new material)</label>
            <input {...register("unit")} placeholder="kg, litre, etc."
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.unit && <p className="text-xs text-red-400 mt-1">{errors.unit.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Low Stock Threshold (new material only)</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>

          <div className="border-t border-[var(--surface-border)] pt-3">
            <label className="text-sm text-[var(--text-muted)]">Supplier</label>
            <Controller
              control={control}
              name="supplierId"
              render={({ field }) => (
                <select {...field}
                  className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                  <option value="">Select supplier...</option>
                  {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              )}
            />
            {errors.supplierId && <p className="text-xs text-red-400 mt-1">{errors.supplierId.message}</p>}
            <button type="button" onClick={() => setShowAddSupplier((v) => !v)} className="text-xs text-[var(--text-muted)] hover:text-[var(--foreground)] hover:underline mt-1">
              + Add Supplier
            </button>
            {showAddSupplier && (
              <div className="mt-2 space-y-2 rounded-lg border border-[var(--surface-border)] p-3">
                <input value={newSupplierName} onChange={(e) => setNewSupplierName(e.target.value)} placeholder="Supplier name"
                  className="w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                <input value={newSupplierPhone} onChange={(e) => setNewSupplierPhone(e.target.value)} placeholder="Phone"
                  className="w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                <button type="button" onClick={handleInlineAddSupplier} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
                  Save Supplier
                </button>
              </div>
            )}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Purchase Date</label>
            <input {...register("purchaseDate")} type="date"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.purchaseDate && <p className="text-xs text-red-400 mt-1">{errors.purchaseDate.message}</p>}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm text-[var(--text-muted)]">Quantity</label>
              <input {...register("qty")} type="number" step="any"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
            </div>
            <div>
              <label className="text-sm text-[var(--text-muted)]">Cost per unit</label>
              <input {...register("cost")} type="number" step="any"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.cost && <p className="text-xs text-red-400 mt-1">{errors.cost.message}</p>}
            </div>
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

export default function RawMaterialsPage() {
  const items = useStore((s) => s.rawMaterials);
  const [dialogOpen, setDialogOpen] = useState(false);

  const columns = useMemo<ColumnDef<RawMaterial, unknown>[]>(() => [
    {
      accessorKey: "name",
      header: "Name",
      cell: ({ row }) => (
        <Link href={`/raw-materials/${row.original.id}`} className="text-[var(--foreground)] hover:underline">
          {row.original.name}
        </Link>
      ),
    },
    { accessorKey: "unit", header: "Unit" },
    {
      accessorKey: "quantityInStock",
      header: "Qty in Stock",
      cell: ({ getValue }) => <span>{getValue() as number}</span>,
    },
    {
      accessorKey: "avgUnitCost",
      header: "Avg Unit Cost",
      cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}`,
    },
    { accessorKey: "lowStockThreshold", header: "Threshold" },
    {
      id: "status",
      header: "Status",
      cell: ({ row }) => <StatusBadge isLow={row.original.quantityInStock < row.original.lowStockThreshold} />,
      enableSorting: false,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Raw Materials</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Add Raw Material
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search raw materials..." />
      <AddRawMaterialDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}