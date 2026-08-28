"use client";

import { Fragment, useEffect, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { ChevronDown, ChevronRight, RefreshCw } from "lucide-react";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";
import { PurchaseOrderDialog } from "@/components/ui/purchase-order-dialog";
import type { PurchaseOrderStatus } from "@/lib/store";

const STATUS_STYLES: Record<PurchaseOrderStatus, string> = {
  draft: "bg-neutral-500/10 text-neutral-500",
  sent: "bg-blue-500/10 text-blue-500",
  partially_received: "bg-amber-500/10 text-amber-500",
  received: "bg-green-500/10 text-green-500",
  closed: "bg-neutral-500/10 text-neutral-400",
};

const STATUS_LABELS: Record<PurchaseOrderStatus, string> = {
  draft: "Draft",
  sent: "Sent",
  partially_received: "Partially Received",
  received: "Received",
  closed: "Closed",
};

export default function PurchaseOrdersPage() {
  const purchaseOrders = useStore((s) => s.purchaseOrders);
  const purchaseOrderLines = useStore((s) => s.purchaseOrderLines);
  const suppliers = useStore((s) => s.suppliers);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const loadPurchaseOrders = useStore((s) => s.loadPurchaseOrders);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);

  useEffect(() => {
    loadPurchaseOrders();
    loadRawMaterialsModule();
  }, [loadPurchaseOrders, loadRawMaterialsModule]);

  const [search, setSearch] = useState("");
  const [supplierFilter, setSupplierFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState<PurchaseOrderStatus | "">("");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const handleRefresh = async () => {
    if (isRefreshing) return;
    setIsRefreshing(true);
    try {
      await loadPurchaseOrders();
      toast.success("Table refreshed");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to refresh");
    } finally {
      setIsRefreshing(false);
    }
  };

  const rows = useMemo(() => {
    return purchaseOrders
      .map((po) => {
        const lines = purchaseOrderLines.filter((l) => l.poId === po.id);
        const supplier = suppliers.find((s) => s.id === po.supplierId);
        const estimatedTotal = lines.reduce((sum, l) => sum + l.qtyOrdered * l.expectedUnitCost, 0);
        const outstandingQty = lines.reduce((sum, l) => sum + Math.max(0, l.qtyOrdered - l.qtyReceived), 0);
        const itemNames = lines.map((l) => rawMaterials.find((m) => m.id === l.rawMaterialId)?.name ?? "?");
        return { po, lines, supplier, estimatedTotal, outstandingQty, itemNames };
      })
      .filter(({ po, supplier, itemNames }) => {
        if (supplierFilter && po.supplierId !== supplierFilter) return false;
        if (statusFilter && po.status !== statusFilter) return false;
        if (search.trim()) {
          const q = search.trim().toLowerCase();
          const haystack = `${po.poNumber} ${supplier?.name ?? ""} ${itemNames.join(" ")}`.toLowerCase();
          if (!haystack.includes(q)) return false;
        }
        return true;
      })
      .sort((a, b) => b.po.poDate.localeCompare(a.po.poDate));
  }, [purchaseOrders, purchaseOrderLines, suppliers, rawMaterials, search, supplierFilter, statusFilter]);

  const hasFilters = !!(supplierFilter || statusFilter);

  return (
    <div className="p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold text-[var(--foreground)]">Purchase Orders</h1>
          <p className="text-sm text-[var(--text-muted)]">
            Nothing gets received into stock without a valid Purchase Order.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="rounded-lg border border-[var(--surface-border)] p-2 text-[var(--text-secondary)] hover:bg-[var(--surface-hover)] disabled:opacity-50"
            title="Refresh"
          >
            <RefreshCw size={16} className={isRefreshing ? "animate-spin" : ""} />
          </button>
          <button
            type="button"
            onClick={() => setDialogOpen(true)}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90"
          >
            New PO
          </button>
        </div>
      </div>

      <div className="mt-4 flex flex-wrap items-end gap-3">
        <div className="min-w-[200px] flex-1">
          <label className="text-xs text-[var(--text-muted)]">Search</label>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="PO number, supplier, item..."
            className="mt-1 block w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">Supplier</label>
          <select
            value={supplierFilter}
            onChange={(e) => setSupplierFilter(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          >
            <option value="">All suppliers</option>
            {suppliers.map((s) => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">Status</label>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as PurchaseOrderStatus | "")}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          >
            <option value="">All statuses</option>
            {(Object.keys(STATUS_LABELS) as PurchaseOrderStatus[]).map((s) => (
              <option key={s} value={s}>{STATUS_LABELS[s]}</option>
            ))}
          </select>
        </div>
        {hasFilters && (
          <button
            type="button"
            onClick={() => { setSupplierFilter(""); setStatusFilter(""); }}
            className="rounded-lg px-3 py-2 text-xs text-[var(--text-muted)] hover:bg-[var(--surface-hover)]"
          >
            Clear filters
          </button>
        )}
      </div>

      <div className="mt-4 overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[820px] text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium w-8"></th>
              <th className="px-4 py-3 font-medium">PO #</th>
              <th className="px-4 py-3 font-medium">Supplier</th>
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Outstanding Qty</th>
              <th className="px-4 py-3 font-medium">Estimated Total</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr><td colSpan={7} className="px-4 py-8 text-center text-[var(--text-faint)]">No purchase orders match these filters.</td></tr>
            )}
            {rows.map(({ po, lines, supplier, estimatedTotal, outstandingQty }) => {
              const isExpanded = expandedId === po.id;
              return (
                <Fragment key={po.id}>
                  <tr className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                    <td className="px-4 py-3">
                      <button type="button" onClick={() => setExpandedId(isExpanded ? null : po.id)} className="text-[var(--text-muted)] hover:text-[var(--foreground)]">
                        {isExpanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                      </button>
                    </td>
                    <td className="px-4 py-3 font-medium text-[var(--foreground)]">{po.poNumber}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">
                      {supplier ? (
                        <NavLink href={`/suppliers/${supplier.id}`} className="hover:underline text-[var(--foreground)]">{supplier.name}</NavLink>
                      ) : "-"}
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{po.poDate}</td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${STATUS_STYLES[po.status]}`}>
                        {STATUS_LABELS[po.status]}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">{outstandingQty}</td>
                    <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {estimatedTotal.toLocaleString()}</td>
                  </tr>
                  {isExpanded && (
                    <tr className="border-b border-[var(--surface-border)] last:border-0 bg-[var(--background)]">
                      <td></td>
                      <td colSpan={6} className="px-4 py-3">
                        {po.notes && (
                          <div className="mb-2 text-xs text-[var(--text-muted)]">Notes: {po.notes}</div>
                        )}
                        <table className="w-full text-xs">
                          <thead>
                            <tr className="text-left text-[var(--text-muted)]">
                              <th className="pb-2 font-medium">Raw Material</th>
                              <th className="pb-2 font-medium">Qty Ordered</th>
                              <th className="pb-2 font-medium">Qty Received</th>
                              <th className="pb-2 font-medium">Outstanding</th>
                              <th className="pb-2 font-medium">Expected Cost/Unit</th>
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
                                  <td className="py-2 text-[var(--text-secondary)]">{l.qtyOrdered} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">{l.qtyReceived} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">{Math.max(0, l.qtyOrdered - l.qtyReceived)} {material?.unit ?? ""}</td>
                                  <td className="py-2 text-[var(--text-secondary)]">Rs. {l.expectedUnitCost.toLocaleString()}</td>
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

      <PurchaseOrderDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}