import { kpis } from "@/lib/mock-data/kpis";

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-4">
      <div className="text-neutral-400 text-sm">{label}</div>
      <div className="text-2xl font-semibold text-neutral-50 mt-1">{value}</div>
    </div>
  );
}

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">Dashboard</h1>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Total Raw Material Value" value={`Rs. ${kpis.totalRawMaterialValue.toLocaleString()}`} />
        <KpiCard label="Batches This Month" value={kpis.batchesThisMonth} />
        <KpiCard label="Finished Cartons Ready" value={kpis.finishedCartonsReady} />
        <KpiCard label="Total Receivables" value={`Rs. ${kpis.totalReceivables.toLocaleString()}`} />
      </div>
    </div>
  );
}