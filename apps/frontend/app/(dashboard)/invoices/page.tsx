"use client";

import { useMemo } from "react";
import Link from "next/link";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Invoice } from "@/lib/store";
import { SortableTable } from "@/components/ui/sortable-table";

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

export default function InvoicesPage() {
  const invoices = useStore((s) => s.invoices);

  const columns = useMemo<ColumnDef<Invoice, unknown>[]>(() => [
    {
      accessorKey: "id", header: "Invoice #",
      cell: ({ row }) => <Link href={`/invoices/${row.original.id}`} className="text-[var(--foreground)] hover:underline">{row.original.id}</Link>,
    },
    { accessorKey: "customerName", header: "Customer" },
    { accessorKey: "invoiceDate", header: "Date" },
    {
      accessorKey: "totalAmount", header: "Total",
      cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}`,
    },
    {
      accessorKey: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge status={row.original.status} />,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Invoices</h1>
        <Link href="/invoices/new" className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          + New Invoice
        </Link>
      </div>
      <SortableTable data={invoices} columns={columns} globalFilterPlaceholder="Search invoices..." />
    </div>
  );
}