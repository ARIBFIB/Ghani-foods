"use client";

import { use, useMemo } from "react";
import Link from "next/link";
import { useStore } from "@/lib/store";

export default function SupplierDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const supplier = useStore((s) => s.suppliers.find((sup) => sup.id === id));
  const allReceipts = useStore((s) => s.receipts);
  const rawMaterials = useStore((s) => s.rawMaterials);

  const receipts = useMemo(
    () => allReceipts.filter((r) => r.supplierId === id).sort((a, b) => b.purchaseDate.localeCompare(a.purchaseDate)),
    [allReceipts, id]
  );

  const totalLifetimeValue = useMemo(
    () => receipts.reduce((sum, r) => sum + r.qty * r.cost, 0),
    [receipts]
  );

  if (!supplier) {
    return (
      <div className="space-y-4">
        <Link href="/suppliers" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Suppliers</Link>
        <p className="text-[var(--text-muted)]">Supplier not found.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <Link href="/suppliers" className="hover:underline text-[var(--text-secondary)]">Suppliers</Link>{" "}
        / <span className="text-[var(--foreground)]">{supplier.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">{supplier.name}</h1>
        <p className="text-sm text-[var(--text-muted)] mt-1">{supplier.phone}</p>
        {supplier.address && <p className="text-sm text-[var(--text-muted)]">{supplier.address}</p>}

        <div className="mt-5 grid grid-cols-2 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Receipts</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">{receipts.length}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Lifetime Value</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {totalLifetimeValue.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <h2 className="text-lg font-semibold text-[var(--foreground)]">Purchase History</h2>
      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Raw Material</th>
              <th className="px-4 py-3 font-medium">Quantity</th>
              <th className="px-4 py-3 font-medium">Cost / Unit</th>
              <th className="px-4 py-3 font-medium">Total</th>
            </tr>
          </thead>
          <tbody>
            {receipts.map((r) => {
              const material = rawMaterials.find((m) => m.id === r.rawMaterialId);
              return (
                <tr key={r.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{r.purchaseDate}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">
                    {material ? (
                      <Link href={`/raw-materials/${material.id}`} className="hover:underline text-[var(--foreground)]">{material.name}</Link>
                    ) : "-"}
                  </td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{r.qty} {material?.unit ?? ""}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {r.cost.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {(r.qty * r.cost).toLocaleString()}</td>
                </tr>
              );
            })}
            {receipts.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-[var(--text-faint)]">No purchases recorded yet for this supplier.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}