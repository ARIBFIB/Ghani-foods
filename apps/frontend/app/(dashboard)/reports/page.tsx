"use client";

import { useMemo, useState } from "react";
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, Legend,
} from "recharts";
import { useStore } from "@/lib/store";

function exportCSV(filename: string, headers: string[], rows: (string | number)[][]) {
  const lines = [headers.join(","), ...rows.map((r) => r.map((v) => `"${v}"`).join(","))];
  const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export default function ReportsPage() {
  const rawMaterials = useStore((s) => s.rawMaterials);
  const packagingMaterials = useStore((s) => s.packagingMaterials);
  const productionBatches = useStore((s) => s.productionBatches);
  const invoices = useStore((s) => s.invoices);
  const finishedCartons = useStore((s) => s.finishedCartons);

  const [tab, setTab] = useState<"inventory" | "yield" | "pnl">("inventory");
  const [from, setFrom] = useState("2026-08-01");
  const [to, setTo] = useState("2026-08-18");

  const inventoryData = useMemo(() => [
    ...rawMaterials.map((m) => ({ name: m.name, stock: m.quantityInStock, threshold: m.lowStockThreshold, type: "Raw" })),
    ...packagingMaterials.map((p) => ({ name: p.name, stock: p.stockQty, threshold: p.lowStockThreshold, type: "Packaging" })),
  ], [rawMaterials, packagingMaterials]);

  const yieldData = useMemo(() =>
    productionBatches.map((b) => ({
      batch: b.id,
      outputYield: b.outputYieldKg,
      wastage: b.wastageKg,
      leftover: b.leftoverQtyKg,
    })), [productionBatches]);

  const pnl = useMemo(() => {
    const filteredInvoices = invoices.filter((i) => i.invoiceDate >= from && i.invoiceDate <= to);
    const filteredBatches = productionBatches.filter((b) => b.batchDate >= from && b.batchDate <= to);
    const totalRevenue = filteredInvoices.reduce((sum, i) => sum + i.totalAmount, 0);
    const totalCost = filteredBatches.reduce((sum, b) => sum + b.outputYieldKg * b.bulkCostPerKg, 0);
    const grossProfit = totalRevenue - totalCost;

    const lineData = filteredInvoices
      .slice()
      .sort((a, b) => a.invoiceDate.localeCompare(b.invoiceDate))
      .map((inv) => ({ date: inv.invoiceDate, revenue: inv.totalAmount }));

    return { totalRevenue, totalCost, grossProfit, lineData };
  }, [invoices, productionBatches, from, to]);

  const cartonsReady = finishedCartons.reduce((sum, c) => sum + c.stockQty, 0);
  const cartonsValue = finishedCartons.reduce((sum, c) => sum + c.stockQty * c.costPerCarton, 0);

  const handleInventoryExport = () => {
    exportCSV("inventory.csv",
      ["Name", "Type", "Stock", "Threshold"],
      inventoryData.map((r) => [r.name, r.type, r.stock, r.threshold])
    );
  };
  const handleYieldExport = () => {
    exportCSV("production-yield.csv",
      ["Batch", "Output Yield (kg)", "Wastage (kg)", "Leftover (kg)"],
      yieldData.map((r) => [r.batch, r.outputYield, r.wastage, r.leftover])
    );
  };
  const handlePnlExport = () => {
    exportCSV("pnl.csv",
      ["Date", "Revenue"],
      pnl.lineData.map((r) => [r.date, r.revenue])
    );
  };

  const tooltipStyle = { backgroundColor: "#171717", border: "1px solid #262626", color: "#f5f5f5", borderRadius: 8 };

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-[var(--foreground)]">Reports and Analytics</h1>

      <div className="flex flex-col sm:flex-row flex-wrap items-stretch sm:items-end gap-3 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
        <div>
          <label className="text-xs text-[var(--text-muted)]">From</label>
          <input value={from} onChange={(e) => setFrom(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">To</label>
          <input value={to} onChange={(e) => setTo(e.target.value)} type="date"
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
        </div>
      </div>

      <div className="flex gap-2 border-b border-[var(--surface-border)]">
        {(["inventory", "yield", "pnl"] as const).map((key) => (
          <button key={key} onClick={() => setTab(key)}
            className={`px-4 py-2 text-sm font-medium border-b-2 capitalize ${
              tab === key ? "border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"
            }`}>
            {key === "yield" ? "Production Yield" : key === "pnl" ? "P and L" : "Inventory Movement"}
          </button>
        ))}
      </div>

      {tab === "inventory" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={handleInventoryExport}
              className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
              Export CSV
            </button>
          </div>
          <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
            <h2 className="text-sm font-semibold text-[var(--foreground)] mb-4">Stock vs Threshold</h2>
            <ResponsiveContainer width="100%" height={320}>
              <BarChart data={inventoryData} margin={{ top: 5, right: 20, left: 0, bottom: 60 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#262626" />
                <XAxis dataKey="name" tick={{ fill: "#a3a3a3", fontSize: 11 }} angle={-30} textAnchor="end" interval={0} />
                <YAxis tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                <Tooltip contentStyle={tooltipStyle} />
                <Legend wrapperStyle={{ color: "#a3a3a3", paddingTop: 16 }} />
                <Bar dataKey="stock" name="Stock" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                <Bar dataKey="threshold" name="Threshold" fill="#ef4444" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
              <div className="text-xs text-[var(--text-muted)]">Finished Cartons Ready</div>
              <div className="text-2xl font-semibold text-[var(--foreground)] mt-1">{cartonsReady}</div>
            </div>
            <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
              <div className="text-xs text-[var(--text-muted)]">Finished Stock Value (at cost)</div>
              <div className="text-2xl font-semibold text-[var(--foreground)] mt-1">Rs. {cartonsValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</div>
            </div>
          </div>
        </div>
      )}

      {tab === "yield" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={handleYieldExport}
              className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
              Export CSV
            </button>
          </div>
          <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
            <h2 className="text-sm font-semibold text-[var(--foreground)] mb-4">Output Yield, Wastage and Leftover per Batch</h2>
            <ResponsiveContainer width="100%" height={320}>
              <BarChart data={yieldData} margin={{ top: 5, right: 20, left: 0, bottom: 20 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#262626" />
                <XAxis dataKey="batch" tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                <YAxis tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                <Tooltip contentStyle={tooltipStyle} />
                <Legend wrapperStyle={{ color: "#a3a3a3", paddingTop: 8 }} />
                <Bar dataKey="outputYield" name="Output (kg)" fill="#22c55e" radius={[4, 4, 0, 0]} />
                <Bar dataKey="wastage" name="Wastage (kg)" fill="#ef4444" radius={[4, 4, 0, 0]} />
                <Bar dataKey="leftover" name="Leftover (kg)" fill="#f59e0b" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {tab === "pnl" && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button onClick={handlePnlExport}
              className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
              Export CSV
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
              <div className="text-xs text-[var(--text-muted)]">Total Revenue</div>
              <div className="text-2xl font-semibold text-[var(--foreground)] mt-1">Rs. {pnl.totalRevenue.toLocaleString()}</div>
            </div>
            <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
              <div className="text-xs text-[var(--text-muted)]">Est. Production Cost</div>
              <div className="text-2xl font-semibold text-[var(--foreground)] mt-1">Rs. {pnl.totalCost.toLocaleString(undefined, { maximumFractionDigits: 0 })}</div>
            </div>
            <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
              <div className="text-xs text-[var(--text-muted)]">Est. Gross Profit</div>
              <div className={`text-2xl font-semibold mt-1 ${pnl.grossProfit >= 0 ? "text-green-400" : "text-red-400"}`}>
                Rs. {pnl.grossProfit.toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </div>
            </div>
          </div>

          {pnl.lineData.length > 0 && (
            <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
              <h2 className="text-sm font-semibold text-[var(--foreground)] mb-4">Revenue Over Time (selected period)</h2>
              <ResponsiveContainer width="100%" height={280}>
                <LineChart data={pnl.lineData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#262626" />
                  <XAxis dataKey="date" tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                  <YAxis tick={{ fill: "#a3a3a3", fontSize: 11 }} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Line type="monotone" dataKey="revenue" name="Revenue (Rs.)" stroke="#3b82f6" strokeWidth={2} dot={{ fill: "#3b82f6", r: 4 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}

          {pnl.lineData.length === 0 && (
            <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-8 text-center text-[var(--foreground)]0 text-sm">
              No invoices in the selected date range.
            </div>
          )}
        </div>
      )}
    </div>
  );
}