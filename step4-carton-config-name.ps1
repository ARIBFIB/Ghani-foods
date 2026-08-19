# step4-carton-config-name.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\step4-carton-config-name.ps1
#
# STEP 4 of the v1.2/v2.2 gap-closure plan.
# Overwrites:
#   apps\frontend\app\(dashboard)\packaging\carton-config\page.tsx
#
# What changes:
#   - "New Carton Configuration" dialog gains a required "Configuration Name"
#     text input (first field in the form), wired to the already-updated
#     cartonConfigSchema.name (lib/schemas.ts) and store.addCartonConfiguration
#     (lib/store.ts) - both already accept/require `name` as of step1, this
#     script only adds the missing UI input + table column.
#   - Table gains a "Name" column (shown first) so configurations are listed
#     by their client-given name instead of only by Wrapper/Box combo.
#   - Live preview line under the form now also echoes the name back, e.g.
#     "Carton A - 48pk" yields 48 packets per carton, so the client can
#     sanity-check the name against the combo before saving.
#
# This script only touches the Carton Configuration page. lib/store.ts and
# lib/schemas.ts already expose `name` on CartonConfiguration / cartonConfigSchema
# / addCartonConfiguration (done in step1) - nothing there needs to change.
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

Write-Host "=== Step 4: Carton Configuration Name field (BRS v1.2 / Spec v2.2) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# apps/frontend/app/(dashboard)/packaging/carton-config/page.tsx
# ---------------------------------------------------------------------------
$cartonConfigPageContent = @'
"use client";

import { useMemo, useState } from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type CartonConfiguration } from "@/lib/store";
import { cartonConfigSchema, type CartonConfigFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function StatusBadge({ used }: { used: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      used ? "bg-amber-950 text-amber-400 border border-amber-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {used ? "Used in Packing Run" : "Available"}
    </span>
  );
}

function AddConfigDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const addCartonConfiguration = useStore((s) => s.addCartonConfiguration);

  const { register, handleSubmit, control, watch, reset, formState: { errors, isSubmitting } } = useForm<CartonConfigFormValues>({
    resolver: zodResolver(cartonConfigSchema),
    defaultValues: { name: "", wrapperId: wrappers[0]?.id ?? "", packetsPerBox: 12, boxId: boxes[0]?.id ?? "", boxesPerCarton: 4 },
  });

  const name = watch("name");
  const wrapperId = watch("wrapperId");
  const boxId = watch("boxId");
  const packetsPerBox = watch("packetsPerBox");
  const boxesPerCarton = watch("boxesPerCarton");

  if (!open) return null;

  const totalPacketsPerCarton = (Number(packetsPerBox) || 0) * (Number(boxesPerCarton) || 0);

  const onSubmit = async (values: CartonConfigFormValues) => {
    addCartonConfiguration(values);
    toast.success("Carton configuration created");
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">New Carton Configuration</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Configuration Name</label>
            <input {...register("name")} type="text" placeholder='e.g. "Carton A" or "Rs.5 Nimko 48pk"'
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Wrapper</label>
            <Controller
              control={control}
              name="wrapperId"
              render={({ field }) => (
                <select {...field}
                  className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                  <option value="">Select wrapper...</option>
                  {wrappers.map((w) => <option key={w.id} value={w.id}>{w.name}</option>)}
                </select>
              )}
            />
            {errors.wrapperId && <p className="text-xs text-red-400 mt-1">{errors.wrapperId.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Packets per Box</label>
            <input {...register("packetsPerBox")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.packetsPerBox && <p className="text-xs text-red-400 mt-1">{errors.packetsPerBox.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Box</label>
            <Controller
              control={control}
              name="boxId"
              render={({ field }) => (
                <select {...field}
                  className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                  <option value="">Select box...</option>
                  {boxes.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
                </select>
              )}
            />
            {errors.boxId && <p className="text-xs text-red-400 mt-1">{errors.boxId.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Boxes per Carton</label>
            <input {...register("boxesPerCarton")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.boxesPerCarton && <p className="text-xs text-red-400 mt-1">{errors.boxesPerCarton.message}</p>}
          </div>

          {wrapperId && boxId && totalPacketsPerCarton > 0 && (
            <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 text-xs text-[var(--text-muted)]">
              {name?.trim() ? <span className="text-[var(--foreground)] font-medium">"{name.trim()}"</span> : "This configuration"} yields{" "}
              <span className="text-[var(--foreground)] font-medium">{totalPacketsPerCarton} packets</span> per carton.
            </div>
          )}
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function CartonConfigPage() {
  const configs = useStore((s) => s.cartonConfigurations);
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const [dialogOpen, setDialogOpen] = useState(false);

  type Row = CartonConfiguration & { wrapperName: string; boxName: string; packetsPerCarton: number };

  const rows = useMemo<Row[]>(() => {
    return configs.map((c) => {
      const wrapper = wrappers.find((w) => w.id === c.wrapperId);
      const box = boxes.find((b) => b.id === c.boxId);
      return {
        ...c,
        wrapperName: wrapper?.name ?? "Unknown Wrapper",
        boxName: box?.name ?? "Unknown Box",
        packetsPerCarton: c.packetsPerBox * c.boxesPerCarton,
      };
    });
  }, [configs, wrappers, boxes]);

  const columns = useMemo<ColumnDef<Row, unknown>[]>(() => [
    { accessorKey: "name", header: "Name", cell: ({ getValue }) => <span className="text-[var(--foreground)] font-medium">{getValue() as string}</span> },
    { accessorKey: "wrapperName", header: "Wrapper" },
    { accessorKey: "packetsPerBox", header: "Packets / Box" },
    { accessorKey: "boxName", header: "Box" },
    { accessorKey: "boxesPerCarton", header: "Boxes / Carton" },
    { accessorKey: "packetsPerCarton", header: "Packets / Carton" },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge used={row.original.usedInPackingRun} />,
    },
  ], []);

  const canCreate = wrappers.length > 0 && boxes.length > 0;

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <a href="/packaging" className="hover:underline text-[var(--text-secondary)]">Packaging Materials</a>{" "}
        / <span className="text-[var(--foreground)]">Carton Configurations</span>
      </div>

      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Carton Configurations</h1>
        <button
          onClick={() => setDialogOpen(true)}
          disabled={!canCreate}
          title={canCreate ? undefined : "Add at least one Wrapper and one Box first"}
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50"
        >
          + New Configuration
        </button>
      </div>

      {!canCreate && (
        <div className="rounded-xl border border-amber-900 bg-amber-950 p-4 text-sm text-amber-400">
          You need at least one Wrapper and one Box before creating a carton configuration.
        </div>
      )}

      <SortableTable data={rows} columns={columns} globalFilterPlaceholder="Search configurations..." />
      <AddConfigDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

Write-FileSmart "apps\frontend\app\(dashboard)\packaging\carton-config\page.tsx" $cartonConfigPageContent

Write-Host ""
Write-Host "=== Step 4 complete ===" -ForegroundColor Cyan
Write-Host "Carton Configuration form + table now include the Name field (BRS v1.2 item 1 / Spec v2.2 revision note 1)." -ForegroundColor Yellow
Write-Host 'This relies on lib/store.ts + lib/schemas.ts already being at v1.2/v2.2 (step1) - both already have `name`.' -ForegroundColor Yellow
Write-Host "Next: cd into apps\frontend and run your dev server to verify, then proceed to step 5 (Packing Run Needed vs Available preview)." -ForegroundColor Yellow