"use client";

import { Fragment, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight } from "lucide-react";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";

export default function ReceiptsPage() {
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);

  const [supplierFilter, setSupplierFilter] = useState("");
  const [materialFilter, setMaterialFilter] = useState("");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  const rows = useMemo(() => {
    return receipts
      .map((r) => {
        const lines = receiptLines.filter((l) => l.receiptId === r.id);
        const supplier = suppliers.find((s) => s.id === r.supplierId);
        const totalValue = lines.reduce((sum, l) => sum + l.qty * l.cost, 0);
        const itemNames = lines.map((l) => rawMaterials.find((m) => m.id === l.rawMaterialId)?.name ?? "?");
        return { receipt: r, lines, supplier, totalValue, itemNames };
      })
      .filter(({ receipt, lines }) => {
        if (supplierFilter && receipt.supplierId !== supplierFilter) return false;
        if (materialFilter && !lines.some((l) => l.rawMaterialId === materialFilter)) return false;
        if (fromDate && receipt.purchaseDate < fromDate) return false;
        if (toDate && receipt.purchaseDate > toDate) return false;
        return true;
      })
      .sort((a, b) => b.receipt.purchaseDate.localeCompare(a.receipt.purchaseDate));
  }, [receipts, receiptLines, suppliers, rawMaterials, supplierFilter, materialFilter, fromDate, toDate]);

  const hasFilters = !!(supplierFilter || materialFilter || fromDate || toDate);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Receipts</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
      </div>

      <div className="flex flex-col sm:flex-row flex-wrap items-stretch sm:items-end gap-3 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
        <div>
          <label className="text-xs text-[var(--text-muted)]">Supplier</label>
          <select value={supplierFilter} onChange={(e) => setSupplierFilter(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            <option value="">All suppliers</option>
            {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">Raw Material</label>
          <select value={materialFilter} onChange={(e) => setMaterialFilter(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            <option value="">All materials</option>
            {rawMaterials.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">From</label>
          <input value={fromDate} onChange={(e) => setFromDate(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">To</label>
          <input value={toDate} onChange={(e) => setToDate(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
        </div>
        {hasFilters && (
          <button
            type="button"
            onClick={() => { setSupplierFilter(""); setMaterialFilter(""); setFromDate(""); setToDate(""); }}
            className="rounded-lg px-3 py-2 text-xs text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
          >
            Clear filters
          </button>
        )}
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[640px] text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium w-8"></th>
              <th className="px-4 py-3 font-medium">Receipt Date</th>
              <th className="px-4 py-3 font-medium">Supplier</th>
              <th className="px-4 py-3 font-medium">Items</th>
              <th className="px-4 py-3 font-medium">Total Value</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-[var(--text-faint)]">No receipts match these filters.</td></tr>
            )}
            {rows.map(({ receipt, lines, supplier, totalValue, itemNames }) => {
              const isExpanded = expandedId === receipt.id;
              const summary = itemNames.length > 2
                ? `${itemNames.length} items: ${itemNames.slice(0, 2).join(", ")}, +${itemNames.length - 2}`
                : `${itemNames.length} item${itemNames.length !== 1 ? "s" : ""}: ${itemNames.join(", ")}`;
              return (
                <Fragment key={receipt.id}>
                  <tr className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                    <td className="px-4 py-3">
                      <button type="button" onClick={() => setExpandedId(isExpanded ? null : receipt.id)} className="text-[var(--text-muted)] hover:text-[var(--foreground)]">
                        {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{receipt.purchaseDate}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">
                      {supplier ? (
                        <NavLink href={`/suppliers/${supplier.id}`} className="hover:underline text-[var(--foreground)]">{supplier.name}</NavLink>
                      ) : "-"}
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{summary}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {totalValue.toLocaleString()}</td>
                  </tr>
                  {isExpanded && (
                    <tr className="border-b border-[var(--surface-border)] last:border-0 bg-[var(--background)]">
                      <td></td>
                      <td colSpan={4} className="px-4 py-3">
                        <table className="w-full text-xs">
                          <thead>
                            <tr className="text-left text-[var(--text-muted)]">
                              <th className="pb-2 font-medium">Raw Material</th>
                              <th className="pb-2 font-medium">Quantity</th>
                              <th className="pb-2 font-medium">Cost/Unit</th>
                              <th className="pb-2 font-medium">Total</th>
                            </tr>
                          </thead>
                          <tbody>
                            {lines.map((l) => {
                              const material = rawMaterials.find((m) => m.id === l.rawMaterialId);
                              return (
                                <tr key={l.id} className="border-t border-[var(--surface-border)]">
                                  <td className="py-2 text-[var(--text-secondary)]">
                                    {material ? (
                                      <NavLink href={`/raw-materials/${material.id}`} className="hover:underline text-[var(--foreground)]">{material.name}</NavLink>
                                    ) : "-"}
                                  </td>
                                  <td className="py-2 text-[var(--text-secondary)]">{l.qty} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {l.cost.toLocaleString()}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {(l.qty * l.cost).toLocaleString()}</td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>

      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}