"use client";

import { useState } from "react";
import { rawMaterials } from "@/lib/mock-data/raw-materials";
import { productionBatches } from "@/lib/mock-data/batches";
import { invoices } from "@/lib/mock-data/invoices";

function SimpleBar({ label, value, max, colorClass }: { label: string; value: number; max: number; colorClass: string }) {
  const pct = max > 0 ? Math.min(100, (value / max) * 100) : 0;
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs text-neutral-400">
        <span>{label}</span>
        <span>{value.toLocaleString()}</span>
      </div>
      <div className="h-2 w-full rounded-full bg-neutral-800 overflow-hidden">
        <div className={`h-full rounded-full ${colorClass}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

export default function ReportsPage() {
  const [tab, setTab] = useState<"inventory" | "yield" | "pnl">("inventory");
  const [from, setFrom] = useState("2026-08-01");
  const [to, setTo] = useState("2026-08-18");

  const maxStock = Math.max(...rawMaterials.map((m) => m.quantityInStock), 1);
  const maxYield = Math.max(...productionBatches.map((b) => b.outputYieldKg), 1);
  const totalRevenue = invoices.reduce((sum, i) => sum + i.totalAmount, 0);
  const totalCostEstimate = productionBatches.reduce((sum, b) => sum + b.outputYieldKg * b.bulkCostPerKg, 0);

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-neutral-50">Reports & Analytics</h1>

      <div className="flex flex-wrap items-end gap-3 rounded-xl border border-neutral-800 bg-neutral-900 p-4">
        <div>
          <label className="text-xs text-neutral-400">From</label>
          <input
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            type="date"
            className="mt-1 block rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
        <div>
          <label className="text-xs text-neutral-400">To</label>
          <input
            value={to}
            onChange={(e) => setTo(e.target.value)}
            type="date"
            className="mt-1 block rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
        <button className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          Apply
        </button>
        <button className="ml-auto rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">
          Export CSV
        </button>
      </div>

      <div className="flex gap-2 border-b border-neutral-800">
        {(
          [
            ["inventory", "Inventory Movement"],
            ["yield", "Production Yield"],
            ["pnl", "P&L"],
          ] as const
        ).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`px-4 py-2 text-sm font-medium border-b-2 ${
              tab === key ? "border-neutral-50 text-neutral-50" : "border-transparent text-neutral-400"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === "inventory" && (
        <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
          <h2 className="text-sm font-semibold text-neutral-200">Raw Material Stock Levels</h2>
          {rawMaterials.map((m) => (
            <SimpleBar key={m.id} label={m.name} value={m.quantityInStock} max={maxStock} colorClass="bg-blue-500" />
          ))}
        </div>
      )}

      {tab === "yield" && (
        <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
          <h2 className="text-sm font-semibold text-neutral-200">Output Yield per Batch</h2>
          {productionBatches.map((b) => (
            <SimpleBar key={b.id} label={b.id} value={b.outputYieldKg} max={maxYield} colorClass="bg-green-500" />
          ))}
        </div>
      )}

      {tab === "pnl" && (
        <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-neutral-400 text-xs">Total Revenue (Invoices)</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">Rs. {totalRevenue.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Est. Production Cost</div>
            <div className="text-lg font-semibold text-neutral-50 mt-1">
              Rs. {totalCostEstimate.toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
          </div>
          <div>
            <div className="text-neutral-400 text-xs">Est. Gross Profit</div>
            <div className="text-lg font-semibold text-green-400 mt-1">
              Rs. {(totalRevenue - totalCostEstimate).toLocaleString(undefined, { maximumFractionDigits: 0 })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}