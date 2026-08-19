"use client";

import { useMemo } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Invoice } from "@/lib/store";
import { SortableTable } from "@/components/ui/sortable-table";

export default function InvoicesPage() {
  const invoices = useStore((s) => s.invoices);

  const columns = useMemo<ColumnDef<Invoice, unknown>[]>(() => [
    {
      accessorKey: "id", header: "Invoice #",
      cell: ({ row }) => <NavLink href={`/invoices/${row.original.id}`} className="text-[var(--foreground)] hover:underline">{row.original.id}</NavLink>,
    },
    { accessorKey: "customerName", header: "Customer" },
    { accessorKey: "invoiceDate", header: "Date" },
    {
      accessorKey: "totalAmount", header: "Total",
      cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}`,
    },
    {
      id: "items", header: "Items", enableSorting: false,
      cell: ({ row }) => `${row.original.items.length} line${row.original.items.length === 1 ? "" : "s"}`,
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Invoices</h1>
        <NavLink href="/invoices/new" className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + New Invoice
        </NavLink>
      </div>
      <p className="text-xs text-[var(--text-faint)]">
        Invoices no longer carry a Paid / Unpaid / Partial status. Payment tracking happens on each customer&apos;s ledger - open a customer to record or review payments.
      </p>
      <SortableTable data={invoices} columns={columns} globalFilterPlaceholder="Search invoices..." />
    </div>
  );
}