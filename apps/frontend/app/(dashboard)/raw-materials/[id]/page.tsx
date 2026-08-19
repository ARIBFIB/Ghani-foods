"use client";

import { use, useEffect, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useStore } from "@/lib/store";
import { PurchaseReceiptDialog } from "@/components/ui/purchase-receipt-dialog";

export default function RawMaterialDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const material = useStore((s) => s.rawMaterials.find((m) => m.id === id));
  const receipts = useStore((s) => s.receipts);
  const receiptLines = useStore((s) => s.receiptLines);
  const suppliers = useStore((s) => s.suppliers);
  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    loadRawMaterialsModule();
  }, [loadRawMaterialsModule]);

  const history = useMemo(() => {
    return receiptLines
      .filter((rl) => rl.rawMaterialId === id)
      .map((rl) => {
        const receipt = receipts.find((r) => r.id === rl.receiptId);
        const supplier = receipt ? suppliers.find((s) => s.id === receipt.supplierId) : undefined;
        return {
          id: rl.id,
          date: receipt?.purchaseDate ?? "-",
          supplier,
          receiptId: rl.receiptId,
          qty: rl.qty,
          cost: rl.cost,
        };
      })
      .sort((a, b) => b.date.localeCompare(a.date));
  }, [receiptLines, receipts, suppliers, id]);

  if (!material) {
    return (
      <div className="space-y-4">
        <NavLink href="/raw-materials" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Raw Materials</NavLink>
        <p className="text-[var(--text-muted)]">Raw material not found.</p>
      </div>
    );
  }

  const isLow = material.quantityInStock < material.lowStockThreshold;

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <NavLink href="/raw-materials" className="hover:underline text-[var(--text-secondary)]">Raw Materials</NavLink>{" "}
        / <span className="text-[var(--foreground)]">{material.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-[var(--foreground)]">{material.name}</h1>
            <p className="text-sm text-[var(--text-muted)] mt-1">Unit: {material.unit}</p>
          </div>
          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
            isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
          }`}>
            {isLow ? "Low Stock" : "OK"}
          </span>
        </div>

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Current Stock</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{material.quantityInStock} {material.unit}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs flex items-center gap-1">
              Avg Unit Cost
              <span title="Weighted average: (Existing Qty x Existing Avg Cost + New Qty x New Cost) / (Existing Qty + New Qty)" className="cursor-help text-[var(--text-faint)]">(i)</span>
            </div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {material.avgUnitCost.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Low Stock Threshold</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{material.lowStockThreshold}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Stock Value</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {(material.quantityInStock * material.avgUnitCost).toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Purchase
        </button>
      </div>

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Supplier</th>
              <th className="px-4 py-3 font-medium">Quantity</th>
              <th className="px-4 py-3 font-medium">Cost / Unit</th>
              <th className="px-4 py-3 font-medium">Total</th>
              <th className="px-4 py-3 font-medium">Receipt</th>
            </tr>
          </thead>
          <tbody>
            {history.map((h) => (
              <tr key={h.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                <td className="px-4 py-3 text-[var(--text-secondary)]">{h.date}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">
                  {h.supplier ? (
                    <NavLink href={`/suppliers/${h.supplier.id}`} className="hover:underline text-[var(--foreground)]">{h.supplier.name}</NavLink>
                  ) : "-"}
                </td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">{h.qty} {material.unit}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {h.cost.toLocaleString()}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {(h.qty * h.cost).toLocaleString()}</td>
                <td className="px-4 py-3 text-[var(--text-secondary)]">
                  <NavLink href={`/receipts`} className="hover:underline text-[var(--foreground)]">{h.receiptId}</NavLink>
                </td>
              </tr>
            ))}
            {history.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[var(--text-faint)]">No purchases recorded yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <PurchaseReceiptDialog open={dialogOpen} onClose={() => setDialogOpen(false)} lockRawMaterialId={material.id} />
    </div>
  );
}