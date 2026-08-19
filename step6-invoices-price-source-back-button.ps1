# step6-invoices-price-source-back-button.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\step6-invoices-price-source-back-button.ps1
#
# STEP 6 of the v1.2/v2.2 gap-closure plan.
# Overwrites:
#   apps\frontend\app\(dashboard)\invoices\page.tsx
#   apps\frontend\app\(dashboard)\invoices\new\page.tsx
#   apps\frontend\app\(dashboard)\invoices\[id]\page.tsx
#
# What changes (BRS v1.2 item 6 / Spec v2.2 revision notes 5 & 6, SSD section 9):
#   - Invoices list: Paid/Unpaid/Partial status column + badge removed.
#     (lib/store.ts's Invoice type has had no status field since Step 1 -
#     this page was still referencing it and would not compile; fixed here.)
#   - New Invoice: each line now shows a live price-source note using
#     s.lastSoldPriceInfo(customerId, itemId) - "First sale of this item to
#     this customer - margin-based price applied." or "Previously sold to
#     this customer on [date] at Rs. [X] - that price applied." The note
#     (and the auto-filled price) now recalculates live off customerId,
#     margin, AND each line's itemId via a useEffect - fixing the
#     "requires a second try" bug where changing the customer after an item
#     was already selected did not refresh the price/note until something
#     else re-rendered. Manually-edited prices are respected: a line is
#     marked "touched" the moment the user edits its price by hand, and the
#     auto-recalc effect skips touched lines (touched resets if the item
#     itself is changed). priceSourceNote is now passed through to
#     createInvoice per line, matching the store's InvoiceLineRecord shape.
#   - Invoice Detail: a "<- Back" button is added at the top of the page,
#     using router.back() when the visit came from within the app (checked
#     via document.referrer) with a same-tab fallback to /invoices
#     otherwise - exactly as specced. The breadcrumb is kept alongside it.
#     (No status badge was present on this page to remove - store.ts
#     already had no status field - but its "Record Payment" dialog was
#     still calling a non-existent s.recordPayment(). That's switched to
#     the real s.recordLedgerEntry(customerId, amount, "received", note)
#     so the page compiles; the full +/- direction selector UI for this
#     dialog is Step 7 scope, not touched here.)
#
# Uses single-quoted PowerShell here-strings (@'...'@) so TSX/TS special
# characters (backticks, ${}, quotes) are written literally with no
# interpolation, then writes UTF8-without-BOM via WriteAllText - same
# encoding-safety goal as export-code.ps1's Read-FileSmart, just for writes.

$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-FileSmart($relativePath, $content) {
    $fullPath = Join-Path $ProjectRoot $relativePath
    $dir = Split-Path $fullPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($fullPath, $content, $Utf8NoBom)
    Write-Host "  Wrote: $relativePath" -ForegroundColor Green
}

Write-Host "=== Step 6: Invoices - live price-source note, remove paid/unpaid badge, Back button (BRS v1.2 / Spec v2.2) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# apps/frontend/app/(dashboard)/invoices/page.tsx
# ---------------------------------------------------------------------------
$invoicesListPageContent = @'
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
'@

Write-FileSmart "apps\frontend\app\(dashboard)\invoices\page.tsx" $invoicesListPageContent

# ---------------------------------------------------------------------------
# apps/frontend/app/(dashboard)/invoices/new/page.tsx
# ---------------------------------------------------------------------------
$newInvoicePageContent = @'
"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { Info } from "lucide-react";
import { useStore } from "@/lib/store";
import { invoiceHeaderSchema, type InvoiceHeaderFormValues } from "@/lib/schemas";

type InvoiceLine = {
  id: string;
  itemId: string;
  qty: string;
  unitPrice: string;
  priceSourceNote: string;
  touched: boolean; // true once the user manually edits the price - stops auto-recalc from overwriting it
};

function buildPriceAndNote(
  itemId: string,
  customerId: string,
  margin: number,
  finishedCartons: { id: string; costPerCarton: number }[],
  lastSoldPriceInfo: (customerId: string, itemId: string) => { price: number; date: string } | undefined,
): { unitPrice: string; priceSourceNote: string } {
  const info = lastSoldPriceInfo(customerId, itemId);
  if (info) {
    return {
      unitPrice: String(info.price),
      priceSourceNote: `Previously sold to this customer on ${info.date} at Rs. ${info.price.toLocaleString()} \u2014 that price applied.`,
    };
  }
  const carton = finishedCartons.find((c) => c.id === itemId);
  const marginMultiplier = 1 + (Number(margin) || 0) / 100;
  const fallback = carton ? Math.round(carton.costPerCarton * marginMultiplier) : 0;
  return {
    unitPrice: String(fallback),
    priceSourceNote: "First sale of this item to this customer \u2014 margin-based price applied.",
  };
}

function NewInvoiceForm() {
  const router = useRouter();
  const { navigate } = useNavigationLoading();
  const searchParams = useSearchParams();
  const preselectedCustomerId = searchParams.get("customerId") ?? "";

  const customers = useStore((s) => s.customers);
  const finishedCartons = useStore((s) => s.finishedCartons);
  const lastSoldPriceInfo = useStore((s) => s.lastSoldPriceInfo);
  const createInvoice = useStore((s) => s.createInvoice);
  const defaultMargin = useStore((s) => s.settings.defaultProfitMarginPercent);

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<InvoiceHeaderFormValues>({
    resolver: zodResolver(invoiceHeaderSchema),
    defaultValues: { customerId: preselectedCustomerId || customers[0]?.id || "", margin: defaultMargin ?? 20 },
  });
  const customerId = watch("customerId");
  const margin = watch("margin");

  const [lines, setLines] = useState<InvoiceLine[]>(() => {
    const firstItemId = finishedCartons[0]?.id ?? "";
    const { unitPrice, priceSourceNote } = buildPriceAndNote(
      firstItemId,
      preselectedCustomerId || customers[0]?.id || "",
      defaultMargin ?? 20,
      finishedCartons,
      lastSoldPriceInfo,
    );
    return [{ id: crypto.randomUUID(), itemId: firstItemId, qty: "1", unitPrice, priceSourceNote, touched: false }];
  });
  const [lineError, setLineError] = useState("");

  // Live recalculation: whenever the customer or the margin changes, refresh
  // the price + price-source note for every line that hasn't been manually
  // edited yet. This is the fix for the "requires a second try" bug - the
  // effect's dependency list includes customerId AND margin AND the set of
  // line itemIds, so a customer swap after an item was already picked
  // recalculates immediately instead of waiting for some other re-render.
  const lineItemIdsKey = lines.map((l) => l.itemId).join("|");
  useEffect(() => {
    if (!customerId) return;
    setLines((prev) =>
      prev.map((line) => {
        if (line.touched || !line.itemId) return line;
        const { unitPrice, priceSourceNote } = buildPriceAndNote(line.itemId, customerId, Number(margin) || 0, finishedCartons, lastSoldPriceInfo);
        return { ...line, unitPrice, priceSourceNote };
      }),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [customerId, margin, lineItemIdsKey]);

  const addLine = () => {
    const firstItemId = finishedCartons[0]?.id ?? "";
    const { unitPrice, priceSourceNote } = buildPriceAndNote(firstItemId, customerId, Number(margin) || 0, finishedCartons, lastSoldPriceInfo);
    setLines((prev) => [...prev, { id: crypto.randomUUID(), itemId: firstItemId, qty: "1", unitPrice, priceSourceNote, touched: false }]);
  };
  const removeLine = (id: string) => setLines((prev) => (prev.length > 1 ? prev.filter((l) => l.id !== id) : prev));
  const updateLine = (id: string, patch: Partial<InvoiceLine>) =>
    setLines((prev) => prev.map((l) => (l.id === id ? { ...l, ...patch } : l)));

  const handleItemChange = (id: string, itemId: string) => {
    const { unitPrice, priceSourceNote } = buildPriceAndNote(itemId, customerId, Number(margin) || 0, finishedCartons, lastSoldPriceInfo);
    updateLine(id, { itemId, unitPrice, priceSourceNote, touched: false });
  };

  const handlePriceChange = (id: string, value: string) => updateLine(id, { unitPrice: value, touched: true });

  const total = useMemo(() => lines.reduce((sum, l) => sum + (Number(l.qty) || 0) * (Number(l.unitPrice) || 0), 0), [lines]);

  const onSubmit = async (values: InvoiceHeaderFormValues) => {
    setLineError("");
    const parsedLines = lines
      .filter((l) => l.itemId && Number(l.qty) > 0)
      .map((l) => ({ itemId: l.itemId, qty: Number(l.qty), unitPrice: Number(l.unitPrice) || 0, priceSourceNote: l.priceSourceNote }));

    if (parsedLines.length === 0) {
      setLineError("Add at least one invoice item with a quantity greater than 0");
      return;
    }
    const insufficient = parsedLines.find((l) => {
      const c = finishedCartons.find((fc) => fc.id === l.itemId);
      return c && l.qty > c.stockQty;
    });
    if (insufficient) {
      setLineError("Not enough finished carton stock for one of the items");
      return;
    }
    const invalidPrice = parsedLines.find((l) => l.unitPrice <= 0);
    if (invalidPrice) {
      setLineError("Every line needs a unit price greater than 0");
      return;
    }

    const newId = createInvoice({ customerId: values.customerId, lines: parsedLines });
    toast.success(`Invoice ${newId} created \u2014 stock deducted, ledger updated`);
    navigate(`/invoices/${newId}`);
  };

  const selectedCustomer = customers.find((c) => c.id === customerId);

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold text-[var(--foreground)]">New Invoice</h1>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <div>
          <label className="text-sm text-[var(--text-muted)]">Customer</label>
          <select {...register("customerId")}
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          {errors.customerId && <p className="text-xs text-red-400 mt-1">{errors.customerId.message}</p>}
          {selectedCustomer && (
            <p className="text-xs text-[var(--text-faint)] mt-1">
              Current balance: Rs. {Math.abs(selectedCustomer.currentBalance).toLocaleString()}{" "}
              {selectedCustomer.currentBalance > 0 ? "(owes)" : "(credit)"}
            </p>
          )}
        </div>

        <div>
          <label className="flex items-center gap-1.5 text-sm text-[var(--text-muted)]">
            Margin % (used only for items with no price history for this customer)
            <span title="Applied when a line item has never been sold to this customer before. Once an item has a prior price for this customer, that price is recalled instead of the margin.">
              <Info size={14} className="text-[var(--text-faint)]" />
            </span>
          </label>
          <input {...register("margin")} type="number" step="any"
            className="mt-1 w-40 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.margin && <p className="text-xs text-red-400 mt-1">{errors.margin.message}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[var(--foreground)]">Invoice Items</h2>
          <button type="button" onClick={addLine} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">+ Add Item</button>
        </div>

        <div className="space-y-3">
          {lines.map((line) => {
            const carton = finishedCartons.find((c) => c.id === line.itemId);
            return (
              <div key={line.id} className="space-y-1">
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
                  <select value={line.itemId} onChange={(e) => handleItemChange(line.id, e.target.value)}
                    className="flex-1 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                    {finishedCartons.map((c) => <option key={c.id} value={c.id}>{c.name} \u2014 {c.stockQty} in stock</option>)}
                  </select>
                  <input value={line.qty} onChange={(e) => updateLine(line.id, { qty: e.target.value })} type="number" placeholder="Qty"
                    className="w-full sm:w-20 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                  <input value={line.unitPrice} onChange={(e) => handlePriceChange(line.id, e.target.value)} type="number" placeholder="Unit Price"
                    className="w-full sm:w-28 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
                  <button type="button" onClick={() => removeLine(line.id)} className="rounded-lg border border-[var(--surface-border)] px-3 py-2 text-sm text-[var(--text-muted)] hover:bg-[var(--surface-hover)]">-</button>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                  {line.priceSourceNote && (
                    <span className="inline-flex items-center gap-1 rounded-full bg-[var(--surface-hover)] px-2.5 py-0.5 text-xs text-[var(--text-secondary)]">
                      {line.priceSourceNote}
                      <span title={line.priceSourceNote}>
                        <Info size={12} className="text-[var(--text-faint)]" />
                      </span>
                    </span>
                  )}
                  {line.touched && (
                    <span className="inline-block rounded-full bg-[var(--surface-hover)] px-2.5 py-0.5 text-xs text-[var(--text-faint)]">
                      Price edited manually
                    </span>
                  )}
                  {carton && Number(line.qty) > carton.stockQty && (
                    <span className="inline-block rounded-full bg-red-950 border border-red-900 px-2.5 py-0.5 text-xs text-red-400">
                      Only {carton.stockQty} in stock
                    </span>
                  )}
                </div>
              </div>
            );
          })}
          {lineError && <p className="text-xs text-red-400">{lineError}</p>}
        </div>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 flex items-center justify-between">
        <span className="text-sm text-[var(--text-muted)]">Total</span>
        <span className="text-2xl font-semibold text-[var(--foreground)]">Rs. {total.toLocaleString()}</span>
      </div>

      <div className="flex justify-end gap-2">
        <button type="button" onClick={() => navigate("/invoices")} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
        <button type="submit" disabled={isSubmitting}
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
          {isSubmitting ? "Saving..." : "Save & Generate Invoice"}
        </button>
      </div>
    </form>
  );
}

export default function NewInvoicePage() {
  return (
    <Suspense fallback={<div className="text-[var(--text-muted)] text-sm">Loading...</div>}>
      <NewInvoiceForm />
    </Suspense>
  );
}
'@

Write-FileSmart "apps\frontend\app\(dashboard)\invoices\new\page.tsx" $newInvoicePageContent

# ---------------------------------------------------------------------------
# apps/frontend/app/(dashboard)/invoices/[id]/page.tsx
# ---------------------------------------------------------------------------
$invoiceDetailPageContent = @'
"use client";

import { use, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { NavLink } from "@/components/ui/nav-link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { z } from "zod";

const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
});
type PaymentAmountValues = z.infer<typeof paymentAmountSchema>;

function RecordPaymentDialog({ open, onClose, customerId, customerName }: { open: boolean; onClose: () => void; customerId: string; customerName: string }) {
  // NOTE: this dialog still only records a "received" payment with no
  // direction selector. The full +/- direction UI (BRS v1.2 item 6 /
  // Spec v2.2 5.12) is Step 7 scope. This wiring is switched from the
  // removed s.recordPayment() to the real s.recordLedgerEntry() so the
  // page compiles against the current store in the meantime.
  const recordLedgerEntry = useStore((s) => s.recordLedgerEntry);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PaymentAmountValues>({ resolver: zodResolver(paymentAmountSchema) });

  if (!open) return null;

  const onSubmit = async (values: PaymentAmountValues) => {
    recordLedgerEntry(customerId, values.amount, "received", "Payment against invoice");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded for ${customerName}`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Payment \u2014 {customerName}</h2>
        <div>
          <label className="text-sm text-[var(--text-muted)]">Amount</label>
          <input {...register("amount")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

// "<- Back" (Spec v2.2 5.10): router.back() when we can tell the visit came
// from within this app (document.referrer on the same origin), otherwise a
// same-tab fallback push to /invoices. document.referrer is only available
// client-side, so this is computed in an effect and defaults to the safe
// fallback (push) until it resolves.
function BackButton() {
  const router = useRouter();
  const [cameFromApp, setCameFromApp] = useState(false);

  useEffect(() => {
    try {
      setCameFromApp(Boolean(document.referrer) && document.referrer.startsWith(window.location.origin));
    } catch {
      setCameFromApp(false);
    }
  }, []);

  const handleBack = () => {
    if (cameFromApp) {
      router.back();
    } else {
      router.push("/invoices");
    }
  };

  return (
    <button
      type="button"
      onClick={handleBack}
      className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)] print:hidden"
    >
      &larr; Back
    </button>
  );
}

export default function InvoiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const invoice = useStore((s) => s.invoices.find((i) => i.id === id));
  const settings = useStore((s) => s.settings);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [generatingPdf, setGeneratingPdf] = useState(false);

  if (!invoice) {
    return (
      <div className="space-y-4">
        <NavLink href="/invoices" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Invoices</NavLink>
        <p className="text-[var(--text-muted)]">Invoice not found.</p>
      </div>
    );
  }

  const handleDownloadPDF = async () => {
    setGeneratingPdf(true);
    try {
      const { jsPDF } = await import("jspdf");
      const doc = new jsPDF({ unit: "pt", format: "a4" });

      const marginX = 48;
      let y = 56;

      doc.setFontSize(18);
      doc.setFont("helvetica", "bold");
      doc.text(settings.businessName || "GhaniFoods", marginX, y);

      doc.setFontSize(9);
      doc.setFont("helvetica", "normal");
      y += 16;
      doc.text(settings.address || "", marginX, y);

      doc.setFontSize(20);
      doc.setFont("helvetica", "bold");
      doc.text("INVOICE", 595 - marginX, 56, { align: "right" });
      doc.setFontSize(10);
      doc.setFont("helvetica", "normal");
      doc.text(invoice.id, 595 - marginX, 74, { align: "right" });
      doc.text(invoice.invoiceDate, 595 - marginX, 88, { align: "right" });

      y += 32;
      doc.setDrawColor(200);
      doc.line(marginX, y, 595 - marginX, y);

      y += 24;
      doc.setFontSize(9);
      doc.setTextColor(120);
      doc.text("BILLED TO", marginX, y);
      y += 14;
      doc.setFontSize(12);
      doc.setTextColor(20);
      doc.setFont("helvetica", "bold");
      doc.text(invoice.customerName, marginX, y);
      doc.setFont("helvetica", "normal");

      y += 30;
      const colItem = marginX;
      const colQty = 330;
      const colPrice = 400;
      const colSubtotal = 500;

      doc.setFillColor(23, 23, 23);
      doc.rect(marginX, y - 14, 595 - marginX * 2, 22, "F");
      doc.setTextColor(255);
      doc.setFontSize(9);
      doc.setFont("helvetica", "bold");
      doc.text("ITEM", colItem + 6, y + 1);
      doc.text("QTY", colQty, y + 1);
      doc.text("UNIT PRICE", colPrice, y + 1);
      doc.text("SUBTOTAL", colSubtotal, y + 1);

      y += 22;
      doc.setTextColor(30);
      doc.setFont("helvetica", "normal");
      doc.setFontSize(10);

      const lines = invoice.items.length > 0
        ? invoice.items
        : [{ itemName: "Nimko Carton (legacy record)", qty: 0, unitPrice: 0, subtotal: invoice.totalAmount, itemId: "" }];

      for (const line of lines) {
        doc.text(String(line.itemName), colItem + 6, y);
        doc.text(line.qty ? String(line.qty) : "-", colQty, y);
        doc.text(line.unitPrice ? `Rs. ${line.unitPrice.toLocaleString()}` : "-", colPrice, y);
        doc.text(`Rs. ${line.subtotal.toLocaleString()}`, colSubtotal, y);
        y += 20;
        doc.setDrawColor(230);
        doc.line(marginX, y - 6, 595 - marginX, y - 6);
      }

      y += 20;
      doc.setFont("helvetica", "bold");
      doc.setFontSize(12);
      doc.text("Total:", colPrice, y);
      doc.text(`Rs. ${invoice.totalAmount.toLocaleString()}`, colSubtotal, y);

      y += 50;
      doc.setFont("helvetica", "normal");
      doc.setFontSize(9);
      doc.setTextColor(120);
      doc.text(settings.invoiceFooterText || "Thank you for your business!", marginX, y);

      doc.save(`${invoice.id}.pdf`);
      toast.success(`Invoice ${invoice.id} downloaded as PDF`);
    } catch (err) {
      toast.error("Could not generate PDF. Please try again.");
      console.error(err);
    } finally {
      setGeneratingPdf(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between print:hidden">
        <div className="text-sm text-[var(--text-muted)]">
          <NavLink href="/invoices" className="hover:underline text-[var(--text-secondary)]">Invoices</NavLink>{" "}
          / <span className="text-[var(--foreground)]">{invoice.id}</span>
        </div>
        <BackButton />
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-6 print:border-0">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-[var(--foreground)]">Invoice {invoice.id}</h1>
            <p className="text-sm text-[var(--text-muted)] mt-1">{invoice.invoiceDate}</p>
          </div>
          <div className="text-right">
            <div className="text-[var(--text-muted)] text-xs">Billed To</div>
            <div className="text-[var(--foreground)] font-medium">{invoice.customerName}</div>
          </div>
        </div>

        <div className="mt-6 rounded-lg border border-[var(--surface-border)] overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--surface-border)] bg-[var(--background)] text-left text-[var(--text-muted)]">
                <th className="px-4 py-2 font-medium">Item</th>
                <th className="px-4 py-2 font-medium">Qty</th>
                <th className="px-4 py-2 font-medium">Unit Price</th>
                <th className="px-4 py-2 font-medium">Subtotal</th>
              </tr>
            </thead>
            <tbody>
              {invoice.items.length > 0 ? (
                invoice.items.map((line, idx) => (
                  <tr key={idx}>
                    <td className="px-4 py-2 text-[var(--text-secondary)]">
                      {line.itemName}
                      {line.priceSourceNote && (
                        <div className="mt-0.5 text-xs text-[var(--text-faint)]">{line.priceSourceNote}</div>
                      )}
                    </td>
                    <td className="px-4 py-2 text-[var(--text-secondary)]">{line.qty}</td>
                    <td className="px-4 py-2 text-[var(--text-secondary)]">Rs. {line.unitPrice.toLocaleString()}</td>
                    <td className="px-4 py-2 text-[var(--text-secondary)]">Rs. {line.subtotal.toLocaleString()}</td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td className="px-4 py-2 text-[var(--text-secondary)]">Nimko Carton (legacy record)</td>
                  <td className="px-4 py-2 text-[var(--text-secondary)]">-</td>
                  <td className="px-4 py-2 text-[var(--text-secondary)]">-</td>
                  <td className="px-4 py-2 text-[var(--text-secondary)]">Rs. {invoice.totalAmount.toLocaleString()}</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex justify-end">
          <div className="text-lg font-semibold text-[var(--foreground)]">Total: Rs. {invoice.totalAmount.toLocaleString()}</div>
        </div>
      </div>

      <div className="flex gap-2 print:hidden">
        <button onClick={() => window.print()} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">Print</button>
        <button
          onClick={handleDownloadPDF}
          disabled={generatingPdf}
          className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)] disabled:opacity-50"
        >
          {generatingPdf ? "Generating..." : "Download PDF"}
        </button>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          Record Payment
        </button>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={invoice.customerId} customerName={invoice.customerName} />
    </div>
  );
}
'@

Write-FileSmart "apps\frontend\app\(dashboard)\invoices\[id]\page.tsx" $invoiceDetailPageContent

Write-Host ""
Write-Host "=== Step 6 complete ===" -ForegroundColor Cyan
Write-Host "Invoices list: Paid/Unpaid/Partial column and badge removed (store.ts's Invoice type has had no status field since Step 1)." -ForegroundColor Yellow
Write-Host "New Invoice: price + price-source note now live-recalculate off customer, margin, and each line's item together - manual price edits are respected and no longer get clobbered." -ForegroundColor Yellow
Write-Host "Invoice Detail: '<- Back' button added (router.back() with same-tab fallback to /invoices); Record Payment now calls the real s.recordLedgerEntry() (hardcoded 'received' direction for now)." -ForegroundColor Yellow
Write-Host "Next: cd into apps\frontend and run your dev server to verify, then proceed to step 7 (Customer Ledger/Payments - full +/- direction UI)." -ForegroundColor Yellow