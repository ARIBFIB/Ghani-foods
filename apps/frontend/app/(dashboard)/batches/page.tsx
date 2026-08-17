"use client";

import Link from "next/link";
import { useStore } from "@/lib/store";

function StatusBadge({ status }: { status: "in_progress" | "completed" }) {
  const isDone = status === "completed";
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isDone ? "bg-green-950 text-green-400 border border-green-900" : "bg-amber-950 text-amber-400 border border-amber-900"
    }`}>
      {isDone ? "Completed" : "In Progress"}
    </span>
  );
}

export default function BatchesPage() {
  const productionBatches = useStore((s) => s.productionBatches);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-neutral-50">Production Batches</h1>
        <Link href="/batches/new" className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + New Batch
        </Link>
      </div>

      <div className="overflow-hidden rounded-xl border border-neutral-800">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-neutral-800 bg-neutral-900 text-left text-neutral-400">
              <th className="px-4 py-3 font-medium">Batch ID</th>
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Output Yield (kg)</th>
              <th className="px-4 py-3 font-medium">Wastage (kg)</th>
              <th className="px-4 py-3 font-medium">Leftover (kg)</th>
              <th className="px-4 py-3 font-medium">Bulk Cost/Kg</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {productionBatches.map((b) => (
              <tr key={b.id} className="border-b border-neutral-900 last:border-0 hover:bg-neutral-900/60">
                <td className="px-4 py-3">
                  <Link href={`/batches/${b.id}`} className="text-neutral-50 hover:underline">{b.id}</Link>
                </td>
                <td className="px-4 py-3 text-neutral-300">{b.batchDate}</td>
                <td className="px-4 py-3 text-neutral-300">{b.outputYieldKg}</td>
                <td className="px-4 py-3 text-neutral-300">{b.wastageKg}</td>
                <td className="px-4 py-3 text-neutral-300">{b.leftoverQtyKg}</td>
                <td className="px-4 py-3 text-neutral-300">{b.bulkCostPerKg > 0 ? `Rs. ${b.bulkCostPerKg.toLocaleString()}` : "-"}</td>
                <td className="px-4 py-3"><StatusBadge status={b.status} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}