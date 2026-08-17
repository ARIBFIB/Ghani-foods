"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-[var(--surface)] border border-[var(--surface-border)] rounded-xl p-4">
      <div className="text-[var(--text-muted)] text-sm">{label}</div>
      <div className="text-2xl font-semibold text-[var(--foreground)] mt-1">{value}</div>
    </div>
  );
}

function StatusBadge({ status }: { status: "unpaid" | "partial" | "paid" }) {
  const styles: Record<string, string> = {
    paid: "bg-green-950 text-green-400 border border-green-900",
    partial: "bg-amber-950 text-amber-400 border border-amber-900",
    unpaid: "bg-red-950 text-red-400 border border-red-900",
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${styles[status]}`}>
      {status[0].toUpperCase() + status.slice(1)}
    </span>
  );
}

function AddRawMaterialDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addRawMaterial = useStore((s) => s.addRawMaterial);
  const [name, setName] = useState("");
  const [unit, setUnit] = useState("kg");
  const [threshold, setThreshold] = useState("50");

  if (!open) return null;

  const handleSave = () => {
    if (!name.trim()) return;
    addRawMaterial({ name: name.trim(), unit, lowStockThreshold: Number(threshold) || 0 });
    toast.success(`Raw material "${name.trim()}" added`);
    setName("");
    setUnit("kg");
    setThreshold("50");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Raw Material</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Unit of Purchase</label>
            <input value={unit} onChange={(e) => setUnit(e.target.value)}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Low Stock Threshold</label>
            <input value={threshold} onChange={(e) => setThreshold(e.target.value)} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button onClick={handleSave} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">Save</button>
        </div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const rawMaterials = useStore((s) => s.rawMaterials);
  const packagingMaterials = useStore((s) => s.packagingMaterials);
  const invoices = useStore((s) => s.invoices);
  const finishedCartons = useStore((s) => s.finishedCartons);
  const customers = useStore((s) => s.customers);
  const [dialogOpen, setDialogOpen] = useState(false);

  const lowStockItems = useMemo(() => {
    const rawAlerts = rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold }));
    const packagingAlerts = packagingMaterials
      .filter((p) => p.stockQty < p.lowStockThreshold)
      .map((p) => ({ id: p.id, name: p.name, href: `/packaging`, qty: p.stockQty, threshold: p.lowStockThreshold }));
    return [...rawAlerts, ...packagingAlerts];
  }, [rawMaterials, packagingMaterials]);

  const kpis = useMemo(() => {
    const totalRawMaterialValue = rawMaterials.reduce((sum, m) => sum + m.quantityInStock * m.avgUnitCost, 0);
    const finishedCartonsReady = finishedCartons.reduce((sum, c) => sum + c.stockQty, 0);
    const totalReceivables = customers.reduce((sum, c) => sum + Math.max(0, c.currentBalance), 0);
    return { totalRawMaterialValue, finishedCartonsReady, totalReceivables };
  }, [rawMaterials, finishedCartons, customers]);

  const recentInvoices = invoices.slice(0, 5);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Dashboard</h1>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Total Raw Material Value" value={`Rs. ${kpis.totalRawMaterialValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}`} />
        <KpiCard label="Batches This Month" value={6} />
        <KpiCard label="Finished Cartons Ready" value={kpis.finishedCartonsReady} />
        <KpiCard label="Total Receivables" value={`Rs. ${kpis.totalReceivables.toLocaleString()}`} />
      </div>

      <div className="flex flex-wrap gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-[var(--surface-border-strong)] px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          + Add Raw Material
        </button>
        <button onClick={() => router.push("/batches/new")} className="rounded-lg border border-[var(--surface-border-strong)] px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          + New Batch
        </button>
        <button onClick={() => router.push("/invoices/new")} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + New Invoice
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] overflow-hidden">
          <div className="px-4 py-3 border-b border-[var(--surface-border)]">
            <h2 className="text-sm font-semibold text-[var(--foreground)]">Low Stock Alerts</h2>
          </div>
          <div className="divide-y divide-[var(--surface-border)]">
            {lowStockItems.length === 0 && (
              <div className="px-4 py-6 text-center text-sm text-[var(--foreground)]0">All stock levels are healthy.</div>
            )}
            {lowStockItems.map((item) => (
              <Link key={item.id} href={item.href} className="flex items-center justify-between px-4 py-3 hover:bg-[var(--surface-hover)]/60">
                <span className="text-sm text-[var(--foreground)]">{item.name}</span>
                <span className="text-xs text-red-400">{item.qty} / {item.threshold}</span>
              </Link>
            ))}
          </div>
        </div>

        <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] overflow-hidden">
          <div className="px-4 py-3 border-b border-[var(--surface-border)] flex items-center justify-between">
            <h2 className="text-sm font-semibold text-[var(--foreground)]">Recent Invoices</h2>
            <Link href="/invoices" className="text-xs text-[var(--text-muted)] hover:text-[var(--foreground)] hover:underline">View all</Link>
          </div>
          <table className="w-full text-sm">
            <tbody>
              {recentInvoices.map((inv) => (
                <tr key={inv.id} className="border-b border-[var(--surface-border)] last:border-0">
                  <td className="px-4 py-3">
                    <Link href={`/invoices/${inv.id}`} className="text-[var(--foreground)] hover:underline">{inv.id}</Link>
                  </td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{inv.customerName}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {inv.totalAmount.toLocaleString()}</td>
                  <td className="px-4 py-3"><StatusBadge status={inv.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <AddRawMaterialDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}