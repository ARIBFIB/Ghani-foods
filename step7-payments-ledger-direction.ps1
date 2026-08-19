<#
  step7-payments-ledger-direction.ps1
  ------------------------------------------------------------------
  Step 7 of 7: Customer Ledger / Payments — explicit +/- direction
  requirement (BRS v1.2 change #6, section 10; Frontend spec v2.2
  section 5.12, 6).

  What this does:
    - apps/frontend/app/(dashboard)/payments/page.tsx
        * Replaces the broken call to the removed `s.recordPayment`
          with `s.recordLedgerEntry(customerId, amount, direction, note)`.
        * Adds the required Direction segmented control
          ("+ Received from customer" / "− Given to customer / credit
          adjustment") with an info "i" tooltip, wired to the
          `direction` field already present in lib/schemas.ts's
          paymentSchema.
        * Adds a Direction column + signed/coloured Amount column to
          the Payments table.

    - apps/frontend/app/(dashboard)/customers/[id]/page.tsx
        * Same fix for the "Record Payment" dialog on the Customer
          detail page (was using a local schema with no direction
          field and calling the removed `recordPayment`).
        * Ledger History table gains a Direction column and correct
          sign/colour per entry type (invoice = debit; payment/
          adjustment = reduces balance, coloured by direction).

  Run from the project root:
    PS D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods> .\step7-payments-ledger-direction.ps1

  Safe to re-run: it overwrites the two target files with the final
  versions below (idempotent), and takes a .bak copy on first run.
#>

$ErrorActionPreference = "Stop"

$root = Get-Location
Write-Host "Running Step 7 in: $root" -ForegroundColor Cyan

$paymentsPagePath = Join-Path $root "apps/frontend/app/(dashboard)/payments/page.tsx"
$customerDetailPath = Join-Path $root "apps/frontend/app/(dashboard)/customers/[id]/page.tsx"

foreach ($p in @($paymentsPagePath, $customerDetailPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host "ERROR: Expected file not found: $p" -ForegroundColor Red
        Write-Host "Make sure you are running this script from the GhaniFoods project root." -ForegroundColor Red
        exit 1
    }
}

function Backup-File($path) {
    $bak = "$path.step7.bak"
    if (-not (Test-Path -LiteralPath $bak)) {
        Copy-Item -LiteralPath $path -Destination $bak -Force
        Write-Host "Backed up: $path -> $bak" -ForegroundColor DarkGray
    }
}

Backup-File $paymentsPagePath
Backup-File $customerDetailPath

# ---------------------------------------------------------------------------
# 1) apps/frontend/app/(dashboard)/payments/page.tsx
# ---------------------------------------------------------------------------

$paymentsPageContent = @'
"use client";

import { useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Payment } from "@/lib/store";
import { paymentSchema, type PaymentFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function RecordPaymentDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const customers = useStore((s) => s.customers);
  const recordLedgerEntry = useStore((s) => s.recordLedgerEntry);
  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<PaymentFormValues>({
    resolver: zodResolver(paymentSchema),
    defaultValues: { customerId: customers[0]?.id ?? "", amount: 0, direction: "received", note: "" },
  });
  const direction = watch("direction");

  if (!open) return null;

  const onSubmit = async (values: PaymentFormValues) => {
    recordLedgerEntry(values.customerId, values.amount, values.direction, values.note ?? "");
    toast.success(
      values.direction === "received"
        ? `Payment of Rs. ${values.amount.toLocaleString()} received`
        : `Rs. ${values.amount.toLocaleString()} recorded as given / credit adjustment`
    );
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Customer</label>
            <select {...register("customerId")}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
              {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            {errors.customerId && <p className="text-xs text-red-400 mt-1">{errors.customerId.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Amount</label>
            <input {...register("amount")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <label className="text-sm text-[var(--text-muted)]">Direction</label>
              <span
                title='Received = payment received from customer, reduces what they owe. Given = amount given to customer (refund) or a credit adjustment in their favor.'
                className="flex h-3.5 w-3.5 cursor-help items-center justify-center rounded-full border border-[var(--text-faint)] text-[9px] leading-none text-[var(--text-faint)]"
              >
                i
              </span>
            </div>
            <div className="mt-1 grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setValue("direction", "received", { shouldValidate: true })}
                className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors ${
                  direction === "received"
                    ? "border-green-500 bg-green-500/10 text-green-400"
                    : "border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
                }`}
              >
                + Received from customer
              </button>
              <button
                type="button"
                onClick={() => setValue("direction", "given", { shouldValidate: true })}
                className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors ${
                  direction === "given"
                    ? "border-red-500 bg-red-500/10 text-red-400"
                    : "border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
                }`}
              >
                − Given / credit adjustment
              </button>
            </div>
            <input type="hidden" {...register("direction")} />
            {errors.direction && <p className="text-xs text-red-400 mt-1">{errors.direction.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Note</label>
            <input {...register("note")} placeholder='e.g. "cash refund", "damaged stock credit"'
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function PaymentsPage() {
  const items = useStore((s) => s.payments);
  const [dialogOpen, setDialogOpen] = useState(false);

  const columns = useMemo<ColumnDef<Payment, unknown>[]>(() => [
    { accessorKey: "paidAt", header: "Date" },
    { accessorKey: "customerName", header: "Customer", cell: ({ getValue }) => <span className="text-[var(--foreground)]">{getValue() as string}</span> },
    {
      accessorKey: "direction", header: "Direction",
      cell: ({ getValue }) => {
        const dir = getValue() as Payment["direction"];
        return dir === "received" ? (
          <span className="rounded-full bg-green-500/10 px-2 py-0.5 text-xs font-medium text-green-400">+ Received</span>
        ) : (
          <span className="rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-medium text-red-400">− Given</span>
        );
      },
    },
    {
      accessorKey: "amount", header: "Amount",
      cell: ({ row }) => (
        <span className={row.original.direction === "received" ? "text-green-400" : "text-red-400"}>
          {row.original.direction === "received" ? "+" : "−"} Rs. {(row.original.amount as number).toLocaleString()}
        </span>
      ),
    },
    { accessorKey: "note", header: "Note" },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Payments</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + Record Payment
        </button>
      </div>
      <SortableTable data={items} columns={columns} globalFilterPlaceholder="Search payments..." />
      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

[System.IO.File]::WriteAllText($paymentsPagePath, $paymentsPageContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Updated: $paymentsPagePath" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2) apps/frontend/app/(dashboard)/customers/[id]/page.tsx
# ---------------------------------------------------------------------------

$customerDetailContent = @'
"use client";

import { use, useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useRouter } from "next/navigation";
import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore, type LedgerDirection } from "@/lib/store";
import { z } from "zod";

const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  direction: z.enum(["received", "given"], {
    required_error: "Select a direction",
  }),
  note: z.string().trim().optional(),
});
type PaymentAmountValues = z.infer<typeof paymentAmountSchema>;

function RecordPaymentDialog({ open, onClose, customerId }: { open: boolean; onClose: () => void; customerId: string }) {
  const recordLedgerEntry = useStore((s) => s.recordLedgerEntry);
  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<PaymentAmountValues>({
    resolver: zodResolver(paymentAmountSchema),
    defaultValues: { amount: 0, direction: "received", note: "" },
  });
  const direction = watch("direction");

  if (!open) return null;

  const onSubmit = async (values: PaymentAmountValues) => {
    recordLedgerEntry(customerId, values.amount, values.direction, values.note ?? "");
    toast.success(
      values.direction === "received"
        ? `Payment of Rs. ${values.amount.toLocaleString()} received`
        : `Rs. ${values.amount.toLocaleString()} recorded as given / credit adjustment`
    );
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Record Payment</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Amount</label>
            <input {...register("amount")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <label className="text-sm text-[var(--text-muted)]">Direction</label>
              <span
                title='Received = payment received from customer, reduces what they owe. Given = amount given to customer (refund) or a credit adjustment in their favor.'
                className="flex h-3.5 w-3.5 cursor-help items-center justify-center rounded-full border border-[var(--text-faint)] text-[9px] leading-none text-[var(--text-faint)]"
              >
                i
              </span>
            </div>
            <div className="mt-1 grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setValue("direction", "received", { shouldValidate: true })}
                className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors ${
                  direction === "received"
                    ? "border-green-500 bg-green-500/10 text-green-400"
                    : "border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
                }`}
              >
                + Received from customer
              </button>
              <button
                type="button"
                onClick={() => setValue("direction", "given", { shouldValidate: true })}
                className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors ${
                  direction === "given"
                    ? "border-red-500 bg-red-500/10 text-red-400"
                    : "border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
                }`}
              >
                − Given / credit adjustment
              </button>
            </div>
            <input type="hidden" {...register("direction")} />
            {errors.direction && <p className="text-xs text-red-400 mt-1">{errors.direction.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Note</label>
            <input {...register("note")} placeholder='e.g. "cash refund", "damaged stock credit"'
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
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

function DirectionBadge({ direction }: { direction: LedgerDirection | null }) {
  if (!direction) return <span className="text-[var(--text-faint)]">—</span>;
  return direction === "received" ? (
    <span className="rounded-full bg-green-500/10 px-2 py-0.5 text-xs font-medium text-green-400">+ Received</span>
  ) : (
    <span className="rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-medium text-red-400">− Given</span>
  );
}

export default function CustomerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const { navigate } = useNavigationLoading();
  const customer = useStore((s) => s.customers.find((c) => c.id === id));
  const allLedger = useStore((s) => s.ledgerEntries);
  const [dialogOpen, setDialogOpen] = useState(false);

  const ledger = useMemo(() => allLedger.filter((l) => l.customerId === id), [allLedger, id]);

  if (!customer) {
    return (
      <div className="space-y-4">
        <NavLink href="/customers" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Customers</NavLink>
        <p className="text-[var(--text-muted)]">Customer not found.</p>
      </div>
    );
  }

  const totalInvoiced = ledger.filter((l) => l.type === "invoice").reduce((sum, l) => sum + l.amount, 0);
  const totalPaid = ledger.filter((l) => l.type === "payment").reduce((sum, l) => sum + Math.abs(l.amount), 0);

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <NavLink href="/customers" className="hover:underline text-[var(--text-secondary)]">Customers</NavLink>{" "}
        / <span className="text-[var(--foreground)]">{customer.name}</span>
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">{customer.name}</h1>
        <p className="text-sm text-[var(--text-muted)] mt-1">{customer.phone}</p>

        <div className="mt-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <div className="text-[var(--text-muted)] text-xs">Current Balance</div>
            <div className={`text-lg font-semibold mt-1 ${customer.currentBalance > 0 ? "text-red-400" : "text-green-400"}`}>
              Rs. {Math.abs(customer.currentBalance).toLocaleString()}
            </div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Invoiced</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {totalInvoiced.toLocaleString()}</div>
          </div>
          <div>
            <div className="text-[var(--text-muted)] text-xs">Total Paid</div>
            <div className="text-lg font-semibold text-[var(--foreground)] mt-1">Rs. {totalPaid.toLocaleString()}</div>
          </div>
        </div>
      </div>

      <div className="flex gap-2">
        <button onClick={() => setDialogOpen(true)} className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          + Record Payment
        </button>
        <button onClick={() => navigate(`/invoices/new?customerId=${customer.id}`)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          New Invoice for this Customer
        </button>
      </div>

      <h2 className="text-lg font-semibold text-[var(--foreground)]">Ledger History</h2>
      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
              <th className="px-4 py-3 font-medium">Date</th>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Direction</th>
              <th className="px-4 py-3 font-medium">Note</th>
              <th className="px-4 py-3 font-medium">Amount</th>
              <th className="px-4 py-3 font-medium">Running Balance</th>
            </tr>
          </thead>
          <tbody>
            {ledger.map((l) => {
              const isDebit = l.type === "invoice";
              return (
                <tr key={l.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{l.date}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)] capitalize">{l.type}</td>
                  <td className="px-4 py-3"><DirectionBadge direction={l.direction} /></td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{l.note}</td>
                  <td className={`px-4 py-3 ${isDebit ? "text-red-400" : "text-green-400"}`}>
                    {isDebit ? "+" : "−"} Rs. {l.amount.toLocaleString()}
                  </td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {l.runningBalance.toLocaleString()}</td>
                </tr>
              );
            })}
            {ledger.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[var(--text-faint)]">No ledger entries yet.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={customer.id} />
    </div>
  );
}
'@

[System.IO.File]::WriteAllText($customerDetailPath, $customerDetailContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Updated: $customerDetailPath" -ForegroundColor Green

Write-Host ""
Write-Host "Step 7 complete." -ForegroundColor Cyan
Write-Host "  - Payments page: direction toggle (+ Received / - Given) wired to recordLedgerEntry, table shows Direction + signed Amount." -ForegroundColor Cyan
Write-Host "  - Customer detail page: Record Payment dialog now requires direction; Ledger History table shows a Direction column." -ForegroundColor Cyan
Write-Host "  - Fixed broken calls to the removed 's.recordPayment' (now 's.recordLedgerEntry')." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: run 'npm run dev' (or your usual dev command) inside apps/frontend and verify /payments and /customers/[id]." -ForegroundColor Yellow