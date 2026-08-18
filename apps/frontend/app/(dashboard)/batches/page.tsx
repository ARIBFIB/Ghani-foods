"use client";

import { useMemo } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type ProductionBatch } from "@/lib/store";
import { SortableTable } from "@/components/ui/sortable-table";

function StatusBadge({ status }: { status: "in_progress" | "completed" }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      status === "completed" ? "bg-green-950 text-green-400 border border-green-900" : "bg-amber-950 text-amber-400 border border-amber-900"
    }`}>
      {status === "completed" ? "Completed" : "In Progress"}
    </span>
  );
}

export default function BatchesPage() {
  const productionBatches = useStore((s) => s.productionBatches);

  const columns = useMemo<ColumnDef<ProductionBatch, unknown>[]>(() => [
    {
      accessorKey: "id", header: "Batch ID",
      cell: ({ row }) => <NavLink href={`/batches/${row.original.id}`} className="text-[var(--foreground)] hover:underline">{row.original.id}</NavLink>,
    },
    { accessorKey: "batchDate", header: "Date" },
    { accessorKey: "outputYieldKg", header: "Output Yield (kg)" },
    { accessorKey: "wastageKg", header: "Wastage (kg)" },
    { accessorKey: "leftoverQtyKg", header: "Leftover (kg)" },
    {
      accessorKey: "bulkCostPerKg", header: "Bulk Cost/Kg",
      cell: ({ getValue }) => {
        const v = getValue() as number;
        return v > 0 ? `Rs. ${v.toLocaleString()}` : "-";
      },
    },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Production Batches</h1>
        <NavLink href="/batches/new" className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + New Batch
        </NavLink>
      </div>
      <SortableTable data={productionBatches} columns={columns} globalFilterPlaceholder="Search batches..." />
    </div>
  );
}