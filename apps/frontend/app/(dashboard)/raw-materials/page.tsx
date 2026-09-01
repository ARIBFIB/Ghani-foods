"use client";

import { Fragment, useEffect, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "@/components/ui/toast";
import { ChevronDown, ChevronRight, RefreshCw } from "lucide-react";
import { useStore } from "@/lib/store";
import { rawMaterialMasterSchema, type RawMaterialMasterFormValues } from "@/lib/schemas";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";
import { InfoTip } from "@/components/ui/info-tip";

import { UNIT_OPTIONS } from "@/lib/constants/units";
import { RAW_MATERIAL_CATEGORY_OPTIONS } from "@/lib/constants/raw-material-categories";
function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddRawMaterialMasterDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const deleteRawMaterial = useStore((s) => s.deleteRawMaterial);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<RawMaterialMasterFormValues>({
    resolver: zodResolver(rawMaterialMasterSchema),
    defaultValues: { name: "", unit: "kg", lowStockThreshold: 50, category: "" },
  });

  if (!open) return null;

  const onSubmit = async (values: RawMaterialMasterFormValues) => {
    try {
      await addRawMaterial(values);
      toast.success(`Raw material "${values.name}" added - record a purchase to add stock`);
      reset();
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to add raw material");
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Raw Material</h2>
        <p className="text-xs text-[var(--text-faint)]">
          Creates the master record only (name, unit, threshold). Stock and cost come from
          purchase receipts - use "Record Purchase" to add stock.
        </p>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Unit</label>
            <select {...register("unit")}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
              {UNIT_OPTIONS.map((u) => (
                <option key={u.value} value={u.value}>{u.label}</option>
              ))}
            </select>
            {errors.unit && <p className="text-xs text-red-400 mt-1">{errors.unit.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Category</label>
            <input {...register("category")} list="raw-material-category-suggestions" placeholder="e.g. Flour"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            <datalist id="raw-material-category-suggestions">
              {RAW_MATERIAL_CATEGORY_OPTIONS.map((c) => <option key={c} value={c} />)}
            </datalist>
            {errors.category && <p className="text-xs text-red-400 mt-1">{errors.category.message}</p>}
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

export default function RawMaterialsPage() {
  const rawMaterials = useStore((s) => s.rawMaterials);
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const deleteRawMaterial = useStore((s) => s.deleteRawMaterial);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);

  const [isRefreshing, setIsRefreshing] = useState(false);
  const handleRefresh = async () => {
    if (isRefreshing) return;
    setIsRefreshing(true);
    try {
      await loadRawMaterialsModule();
      toast.success("Table refreshed");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to refresh");
    } finally {
      setIsRefreshing(false);
    }
  };

  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("all");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [receiptOpen, setReceiptOpen] = useState(false);

  const [deletingId, setDeletingId] = useState<string | null>(null);
  const handleDelete = async (id: string, name: string) => {
    if (!window.confirm(`Delete raw material "${name}"? This cannot be undone.`)) return;
    setDeletingId(id);
    try {
      await deleteRawMaterial(id);
      toast.success("Raw material deleted");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to delete raw material");
    } finally {
      setDeletingId(null);
    }
  };
  const categoryOptions = useMemo(() => {
    const set = new Set(rawMaterials.map((m) => m.category).filter((c): c is string => !!c && c.trim().length > 0));
    return Array.from(set).sort();
  }, [rawMaterials]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return rawMaterials.filter((m) => {
      const matchesSearch = !q || m.name.toLowerCase().includes(q) || m.unit.toLowerCase().includes(q) || (m.category ?? "").toLowerCase().includes(q);
      const matchesCategory = categoryFilter === "all" || (m.category ?? "") === categoryFilter;
      return matchesSearch && matchesCategory;
    });
  }, [rawMaterials, search, categoryFilter]);

  const historyFor = (materialId: string) => {
    return receiptLines
      .filter((rl) => rl.rawMaterialId === materialId)
      .map((rl) => {
        const receipt = receipts.find((r) => r.id === rl.receiptId);
        const supplier = receipt ? suppliers.find((s) => s.id === receipt.supplierId) : undefined;
        return {
          id: rl.id,
          date: receipt?.purchaseDate ?? "-",
          supplierName: supplier?.name ?? "-",
          supplierId: supplier?.id,
          qty: rl.qty,
          cost: rl.cost,
        };
      })
      .sort((a, b) => b.date.localeCompare(a.date));
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-2">
          <h1 className="text-xl font-semibold text-[var(--foreground)]">Raw Materials</h1>
          <button type="button" onClick={handleRefresh} disabled={isRefreshing} title="Refresh table" aria-label="Refresh table" className="shrink-0 rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] p-2 text-[var(--text-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--foreground)] disabled:opacity-50 transition-colors">
            <RefreshCw className={`w-4 h-4 ${isRefreshing ? "animate-spin" : ""}`} />
          </button>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => setAddOpen(true)} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
            + Add Raw Material
          </button>
          <button onClick={() => setReceiptOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
            + Record Purchase
          </button>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search raw materials..."
          className="w-full max-w-sm rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
        />
        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
          className="rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
        >
          <option value="all">All categories</option>
          {categoryOptions.map((c) => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[720px] text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium w-8"></th>
              <th className="px-4 py-3 font-medium">Name</th>
              <th className="px-4 py-3 font-medium">Unit</th>
              <th className="px-4 py-3 font-medium">Category</th>
              <th className="px-4 py-3 font-medium">Qty in Stock</th>
              <th className="px-4 py-3 font-medium">
                <span className="inline-flex items-center">
                  Avg Unit Cost
                  <InfoTip text="Weighted average cost per unit across all purchase receipts for this raw material, recalculated on every new receipt." />
                </span>
              </th>
              <th className="px-4 py-3 font-medium">Threshold</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 && (
              <tr><td colSpan={9} className="px-4 py-8 text-center text-[var(--text-faint)]">No raw materials found.</td></tr>
            )}
            {filtered.map((m) => {
              const isLow = m.quantityInStock < m.lowStockThreshold;
              const isExpanded = expandedId === m.id;
              const history = isExpanded ? historyFor(m.id) : [];
              return (
                <Fragment key={m.id}>
                  <tr className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                    <td className="px-4 py-3">
                      <button
                        type="button"
                        onClick={() => setExpandedId(isExpanded ? null : m.id)}
                        className="text-[var(--text-muted)] hover:text-[var(--foreground)]"
                        aria-label={isExpanded ? "Collapse" : "Expand"}
                      >
                        {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <NavLink href={`/raw-materials/${m.id}`} className="text-[var(--foreground)] hover:underline">
                        {m.name}
                      </NavLink>
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{m.unit}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{m.category || "-"}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{m.quantityInStock}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {m.avgUnitCost.toLocaleString()}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{m.lowStockThreshold}</td>
                    <td className="px-4 py-3"><StatusBadge isLow={isLow} /></td>
                    <td className="px-4 py-3">
                      <button
                        type="button"
                        onClick={() => handleDelete(m.id, m.name)}
                        disabled={deletingId === m.id}
                        className="rounded-lg border border-red-900 px-2.5 py-1 text-xs font-medium text-red-400 hover:bg-red-950 disabled:opacity-50"
                      >
                        {deletingId === m.id ? "Deleting..." : "Delete"}
                      </button>
                    </td>
                  </tr>
                  {isExpanded && (
                    <tr className="border-b border-[var(--surface-border)] last:border-0 bg-[var(--background)]">
                      <td></td>
                      <td colSpan={8} className="px-4 py-3">
                        {history.length === 0 ? (
                          <p className="text-xs text-[var(--text-faint)] py-2">No purchase history yet for this material.</p>
                        ) : (
                          <table className="w-full text-xs">
                            <thead>
                              <tr className="text-left text-[var(--text-muted)]">
                                <th className="pb-2 font-medium">Date</th>
                                <th className="pb-2 font-medium">Supplier</th>
                                <th className="pb-2 font-medium">Quantity</th>
                                <th className="pb-2 font-medium">Cost/Unit</th>
                                <th className="pb-2 font-medium">Total</th>
                              </tr>
                            </thead>
                            <tbody>
                              {history.map((h) => (
                                <tr key={h.id} className="border-t border-[var(--surface-border)]">
                                  <td className="py-2 text-[var(--text-secondary)]">{h.date}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">
                                    {h.supplierId ? (
                                      <NavLink href={`/suppliers/${h.supplierId}`} className="hover:underline text-[var(--foreground)]">{h.supplierName}</NavLink>
                                    ) : h.supplierName}
                                  </td>
                                  <td className="py-2 text-[var(--text-secondary)]">{h.qty} {m.unit}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {h.cost.toLocaleString()}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {(h.qty * h.cost).toLocaleString()}</td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        )}
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>

      <AddRawMaterialMasterDialog open={addOpen} onClose={() => setAddOpen(false)} />
      <PurchaseReceiptDialog open={receiptOpen} onClose={() => setReceiptOpen(false)} />
    </div>
  );
}