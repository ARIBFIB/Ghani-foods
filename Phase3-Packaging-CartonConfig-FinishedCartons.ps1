# Phase3-Packaging-CartonConfig-FinishedCartons.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\Phase3-Packaging-CartonConfig-FinishedCartons.ps1
#
# PHASE 3 of 5 - Packaging (Wrappers/Boxes) + Carton Configurations + Finished Cartons
#
# Adds:
#   - app/(dashboard)/packaging/carton-config/page.tsx  (NEW - config list + create form)
# Rewrites:
#   - app/(dashboard)/packaging/page.tsx                (Wrappers / Boxes tabs, replaces old packagingMaterials)
#   - app/(dashboard)/finished-cartons/page.tsx          (Packing Run simplified to batchId+configId+cartonsProduced)
# Updates:
#   - app/(dashboard)/page.tsx (Dashboard)                (low-stock alerts: wrappers+boxes instead of packagingMaterials)
#   - components/ui/topbar.tsx                            (notification bell: wrappers+boxes)
#   - app/(dashboard)/reports/page.tsx                    (inventory chart: wrappers+boxes)
#   - components/ui/sidebar-component.tsx                 (adds "Carton Configurations" nav link)
#
# Still pending after this: none from the original gap list - Phase 3 closes out
# all remaining packagingMaterials references. Project should build cleanly after this.

$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$AppDash = Join-Path $ProjectRoot "apps\frontend\app\(dashboard)"
$Components = Join-Path $ProjectRoot "apps\frontend\components\ui"

if (-not (Test-Path $AppDash)) {
    Write-Host "ERROR: apps\frontend\app\(dashboard) not found. Run this script from the GhaniFoods root." -ForegroundColor Red
    exit 1
}

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Host "=== Phase 3: Packaging (Wrappers/Boxes) + Carton Config + Finished Cartons ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. app/(dashboard)/packaging/page.tsx  (REWRITE - Wrappers / Boxes tabs)
# ---------------------------------------------------------------------------
$packagingContent = @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Wrapper, type Box } from "@/lib/store";
import { wrapperSchema, boxSchema, restockSchema, type WrapperFormValues, type BoxFormValues, type RestockFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function AddWrapperDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addWrapper = useStore((s) => s.addWrapper);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<WrapperFormValues>({
    resolver: zodResolver(wrapperSchema),
    defaultValues: { name: "", unitCost: 0, lowStockThreshold: 500 },
  });
  if (!open) return null;
  const onSubmit = async (values: WrapperFormValues) => {
    addWrapper(values);
    toast.success(`Wrapper "${values.name}" added`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Wrapper</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Rs. 5 Wrapper"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Unit Cost</label>
            <input {...register("unitCost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.unitCost && <p className="text-xs text-red-400 mt-1">{errors.unitCost.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Low Stock Threshold</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>
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

function AddBoxDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const addBox = useStore((s) => s.addBox);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<BoxFormValues>({
    resolver: zodResolver(boxSchema),
    defaultValues: { name: "", unitCost: 0, lowStockThreshold: 100 },
  });
  if (!open) return null;
  const onSubmit = async (values: BoxFormValues) => {
    addBox(values);
    toast.success(`Box "${values.name}" added`);
    reset(); onClose();
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Add Box</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder="e.g. Box (12 packets)"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Unit Cost</label>
            <input {...register("unitCost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.unitCost && <p className="text-xs text-red-400 mt-1">{errors.unitCost.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Low Stock Threshold</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>
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

type RestockTarget = { kind: "wrapper" | "box"; item: Wrapper | Box } | null;

function RestockDialog({ target, onClose }: { target: RestockTarget; onClose: () => void }) {
  const restockWrapper = useStore((s) => s.restockWrapper);
  const restockBox = useStore((s) => s.restockBox);
  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<RestockFormValues>({ resolver: zodResolver(restockSchema) });

  if (!target) return null;
  const { kind, item } = target;

  const onSubmit = async (values: RestockFormValues) => {
    if (kind === "wrapper") restockWrapper(item.id, values.qty, values.cost ?? 0);
    else restockBox(item.id, values.qty, values.cost ?? 0);
    toast.success(`Restocked ${item.name}`);
    reset(); onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Restock: {item.name}</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Quantity to Add</label>
            <input {...register("qty")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.qty && <p className="text-xs text-red-400 mt-1">{errors.qty.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Cost per unit (optional)</label>
            <input {...register("cost")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          </div>
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

export default function PackagingPage() {
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const [tab, setTab] = useState<"wrappers" | "boxes">("wrappers");
  const [addWrapperOpen, setAddWrapperOpen] = useState(false);
  const [addBoxOpen, setAddBoxOpen] = useState(false);
  const [restockTarget, setRestockTarget] = useState<RestockTarget>(null);

  const wrapperColumns = useMemo<ColumnDef<Wrapper, unknown>[]>(() => [
    { accessorKey: "name", header: "Name", cell: ({ getValue }) => <span className="text-[var(--foreground)]">{getValue() as string}</span> },
    { accessorKey: "unitCost", header: "Unit Cost", cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}` },
    { accessorKey: "stockQty", header: "Stock Qty", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    { accessorKey: "lowStockThreshold", header: "Threshold", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge isLow={row.original.stockQty < row.original.lowStockThreshold} />,
    },
    {
      id: "action", header: "", enableSorting: false,
      cell: ({ row }) => (
        <button onClick={() => setRestockTarget({ kind: "wrapper", item: row.original })}
          className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Restock
        </button>
      ),
    },
  ], []);

  const boxColumns = useMemo<ColumnDef<Box, unknown>[]>(() => [
    { accessorKey: "name", header: "Name", cell: ({ getValue }) => <span className="text-[var(--foreground)]">{getValue() as string}</span> },
    { accessorKey: "unitCost", header: "Unit Cost", cell: ({ getValue }) => `Rs. ${(getValue() as number).toLocaleString()}` },
    { accessorKey: "stockQty", header: "Stock Qty", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    { accessorKey: "lowStockThreshold", header: "Threshold", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge isLow={row.original.stockQty < row.original.lowStockThreshold} />,
    },
    {
      id: "action", header: "", enableSorting: false,
      cell: ({ row }) => (
        <button onClick={() => setRestockTarget({ kind: "box", item: row.original })}
          className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Restock
        </button>
      ),
    },
  ], []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Packaging Materials</h1>
        <div className="flex items-center gap-2">
          <Link href="/packaging/carton-config" className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
            Carton Configurations
          </Link>
          {tab === "wrappers" ? (
            <button onClick={() => setAddWrapperOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
              + Add Wrapper
            </button>
          ) : (
            <button onClick={() => setAddBoxOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
              + Add Box
            </button>
          )}
        </div>
      </div>

      <div className="flex gap-2 border-b border-[var(--surface-border)]">
        <button onClick={() => setTab("wrappers")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "wrappers" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Wrappers
        </button>
        <button onClick={() => setTab("boxes")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "boxes" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Boxes
        </button>
      </div>

      {tab === "wrappers" ? (
        <SortableTable data={wrappers} columns={wrapperColumns} globalFilterPlaceholder="Search wrappers..." />
      ) : (
        <SortableTable data={boxes} columns={boxColumns} globalFilterPlaceholder="Search boxes..." />
      )}

      <AddWrapperDialog open={addWrapperOpen} onClose={() => setAddWrapperOpen(false)} />
      <AddBoxDialog open={addBoxOpen} onClose={() => setAddBoxOpen(false)} />
      <RestockDialog target={restockTarget} onClose={() => setRestockTarget(null)} />
    </div>
  );
}
'@

$packagingPath = Join-Path $AppDash "packaging\page.tsx"
Write-Utf8NoBom -Path $packagingPath -Content $packagingContent
Write-Host "  [1/6] Rewrote app\(dashboard)\packaging\page.tsx (Wrappers / Boxes tabs)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. app/(dashboard)/packaging/carton-config/page.tsx  (NEW)
# ---------------------------------------------------------------------------
$cartonConfigContent = @'
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
    defaultValues: { wrapperId: wrappers[0]?.id ?? "", packetsPerBox: 12, boxId: boxes[0]?.id ?? "", boxesPerCarton: 4 },
  });

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
              This configuration yields <span className="text-[var(--foreground)] font-medium">{totalPacketsPerCarton} packets</span> per carton.
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
    { accessorKey: "wrapperName", header: "Wrapper", cell: ({ getValue }) => <span className="text-[var(--foreground)]">{getValue() as string}</span> },
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

$cartonConfigPath = Join-Path $AppDash "packaging\carton-config\page.tsx"
Write-Utf8NoBom -Path $cartonConfigPath -Content $cartonConfigContent
Write-Host "  [2/6] Wrote app\(dashboard)\packaging\carton-config\page.tsx (NEW)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. app/(dashboard)/finished-cartons/page.tsx  (REWRITE - simplified packing run)
# ---------------------------------------------------------------------------
$finishedCartonsContent = @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

function NewPackingRunDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const productionBatches = useStore((s) => s.productionBatches);
  const cartonConfigurations = useStore((s) => s.cartonConfigurations);
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const createPackingRun = useStore((s) => s.createPackingRun);

  const [step, setStep] = useState(1);
  const [batchId, setBatchId] = useState(productionBatches.find((b) => b.leftoverQtyKg > 0)?.id ?? productionBatches[0]?.id ?? "");
  const [configId, setConfigId] = useState(cartonConfigurations[0]?.id ?? "");
  const [cartonsProduced, setCartonsProduced] = useState("10");

  if (!open) return null;

  const batch = productionBatches.find((b) => b.id === batchId);
  const config = cartonConfigurations.find((c) => c.id === configId);
  const wrapper = wrappers.find((w) => w.id === config?.wrapperId);
  const box = boxes.find((b) => b.id === config?.boxId);

  const cartons = Number(cartonsProduced) || 0;
  const boxesNeeded = config ? cartons * config.boxesPerCarton : 0;
  const packetsNeeded = config ? boxesNeeded * config.packetsPerBox : 0;

  const insufficientWrapper = wrapper ? packetsNeeded > wrapper.stockQty : false;
  const insufficientBox = box ? boxesNeeded > box.stockQty : false;

  // Preview estimate - mirrors the store's internal calculation
  const preview = useMemo(() => {
    if (!batch || !config || !wrapper || !box || cartons <= 0) return null;
    const nominalKgPerPacket = 0.05;
    const estimatedKgNeeded = packetsNeeded * nominalKgPerPacket;
    const bulkKgUsed = Math.min(estimatedKgNeeded, batch.leftoverQtyKg);
    const bulkCostShare = batch.bulkCostPerKg * bulkKgUsed;
    const costPerPacket = packetsNeeded > 0 ? bulkCostShare / packetsNeeded + wrapper.unitCost : wrapper.unitCost;
    const costPerBox = config.packetsPerBox * costPerPacket + box.unitCost;
    const costPerCarton = config.boxesPerCarton * costPerBox;
    return { bulkKgUsed, costPerPacket, costPerBox, costPerCarton };
  }, [batch, config, wrapper, box, cartons, packetsNeeded]);

  const reset = () => {
    setStep(1);
    setCartonsProduced("10");
  };

  const handleConfirm = () => {
    if (!batch || !config) return;
    if (cartons <= 0) {
      toast.error("Enter a valid number of cartons");
      return;
    }
    if (insufficientWrapper) {
      toast.error(`Not enough ${wrapper?.name} in stock`);
      return;
    }
    if (insufficientBox) {
      toast.error(`Not enough ${box?.name} in stock`);
      return;
    }
    createPackingRun({ batchId, configId, cartonsProduced: cartons });
    toast.success(`Packing run confirmed - ${cartons} cartons added to ready stock`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <div className="w-full max-w-md rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">New Packing Run - Step {step} of 3</h2>

        {step === 1 && (
          <div>
            <label className="text-sm text-[var(--text-muted)]">Select Batch</label>
            <select value={batchId} onChange={(e) => setBatchId(e.target.value)}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
              {productionBatches.map((b) => (
                <option key={b.id} value={b.id}>{b.id} - {b.leftoverQtyKg} kg available</option>
              ))}
            </select>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-3">
            <div>
              <label className="text-sm text-[var(--text-muted)]">Carton Configuration</label>
              <select value={configId} onChange={(e) => setConfigId(e.target.value)}
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                {cartonConfigurations.length === 0 && <option value="">No configurations available</option>}
                {cartonConfigurations.map((c) => {
                  const w = wrappers.find((wr) => wr.id === c.wrapperId);
                  const b = boxes.find((bx) => bx.id === c.boxId);
                  return (
                    <option key={c.id} value={c.id}>
                      {w?.name ?? "?"} x {c.packetsPerBox}/box - {b?.name ?? "?"} x {c.boxesPerCarton}/carton
                    </option>
                  );
                })}
              </select>
              {cartonConfigurations.length === 0 && (
                <p className="text-xs text-red-400 mt-1">
                  No carton configurations exist yet. Create one under{" "}
                  <Link href="/packaging/carton-config" className="underline">Packaging &rarr; Carton Configurations</Link>.
                </p>
              )}
            </div>
            <div>
              <label className="text-sm text-[var(--text-muted)]">Number of Cartons Produced</label>
              <input value={cartonsProduced} onChange={(e) => setCartonsProduced(e.target.value)} type="number"
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            </div>
            {config && (
              <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 space-y-1 text-xs text-[var(--text-muted)]">
                <div>Boxes needed: <span className="text-[var(--foreground)]">{boxesNeeded}</span> {insufficientBox && <span className="text-red-400">(only {box?.stockQty} in stock)</span>}</div>
                <div>Wrappers/packets needed: <span className="text-[var(--foreground)]">{packetsNeeded}</span> {insufficientWrapper && <span className="text-red-400">(only {wrapper?.stockQty} in stock)</span>}</div>
              </div>
            )}
          </div>
        )}

        {step === 3 && (
          <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-4 space-y-2">
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Source Batch</span><span className="text-[var(--foreground)]">{batchId}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Wrapper</span><span className="text-[var(--foreground)]">{wrapper?.name ?? "-"}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Box</span><span className="text-[var(--foreground)]">{box?.name ?? "-"}</span></div>
            <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Cartons Produced</span><span className="text-[var(--foreground)]">{cartons}</span></div>
            {preview && (
              <>
                <div className="flex justify-between text-sm"><span className="text-[var(--text-muted)]">Bulk Product Used</span><span className="text-[var(--foreground)]">{preview.bulkKgUsed.toFixed(2)} kg</span></div>
                <div className="flex justify-between text-sm pt-2 border-t border-[var(--surface-border)]">
                  <span className="text-[var(--text-muted)]">Est. Cost / Packet</span>
                  <span className="text-[var(--foreground)]">Rs. {preview.costPerPacket.toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-[var(--text-muted)]">Est. Cost / Box</span>
                  <span className="text-[var(--foreground)]">Rs. {preview.costPerBox.toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-[var(--text-muted)]">Est. Cost / Carton</span>
                  <span className="text-[var(--foreground)] font-semibold">Rs. {preview.costPerCarton.toFixed(2)}</span>
                </div>
              </>
            )}
          </div>
        )}

        <div className="flex justify-between pt-2">
          <button onClick={() => (step === 1 ? onClose() : setStep(step - 1))} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">
            {step === 1 ? "Cancel" : "Back"}
          </button>
          {step < 3 ? (
            <button
              onClick={() => setStep(step + 1)}
              disabled={step === 2 && (!config || cartons <= 0)}
              className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50"
            >
              Next
            </button>
          ) : (
            <button onClick={handleConfirm} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
              Confirm Packing
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export default function FinishedCartonsPage() {
  const cartons = useStore((s) => s.finishedCartons);
  const productionBatches = useStore((s) => s.productionBatches);
  const [tab, setTab] = useState<"ready" | "leftover">("ready");
  const [dialogOpen, setDialogOpen] = useState(false);

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Finished Cartons</h1>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
          + New Packing Run
        </button>
      </div>

      <div className="flex gap-2 border-b border-[var(--surface-border)]">
        <button onClick={() => setTab("ready")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "ready" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Ready for Sale
        </button>
        <button onClick={() => setTab("leftover")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "leftover" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Unpacked / Leftover
        </button>
      </div>

      {tab === "ready" ? (
        <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
                <th className="px-4 py-3 font-medium">Carton</th>
                <th className="px-4 py-3 font-medium">Source Batch</th>
                <th className="px-4 py-3 font-medium">Cartons Produced</th>
                <th className="px-4 py-3 font-medium">Packets/Carton</th>
                <th className="px-4 py-3 font-medium">Cost/Packet</th>
                <th className="px-4 py-3 font-medium">Cost/Box</th>
                <th className="px-4 py-3 font-medium">Cost/Carton</th>
                <th className="px-4 py-3 font-medium">Stock Qty</th>
              </tr>
            </thead>
            <tbody>
              {cartons.map((c) => (
                <tr key={c.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--foreground)]">{c.name}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.sourceBatchId}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.cartonsProduced}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.packetsPerCarton}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {c.costPerPacket.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {c.costPerBox.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {c.costPerCarton.toLocaleString()}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{c.stockQty}</td>
                </tr>
              ))}
              {cartons.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-[var(--text-faint)]">No finished cartons yet.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
                <th className="px-4 py-3 font-medium">Batch</th>
                <th className="px-4 py-3 font-medium">Leftover Bulk (kg)</th>
                <th className="px-4 py-3 font-medium">Bulk Cost/Kg</th>
              </tr>
            </thead>
            <tbody>
              {leftoverBatches.map((b) => (
                <tr key={b.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  <td className="px-4 py-3 text-[var(--foreground)]">{b.id}</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">{b.leftoverQtyKg} kg</td>
                  <td className="px-4 py-3 text-[var(--text-secondary)]">Rs. {b.bulkCostPerKg.toLocaleString()}</td>
                </tr>
              ))}
              {leftoverBatches.length === 0 && (
                <tr><td colSpan={3} className="px-4 py-8 text-center text-[var(--text-faint)]">No leftover bulk product.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      <NewPackingRunDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}
'@

$finishedCartonsPath = Join-Path $AppDash "finished-cartons\page.tsx"
Write-Utf8NoBom -Path $finishedCartonsPath -Content $finishedCartonsContent
Write-Host "  [3/6] Rewrote app\(dashboard)\finished-cartons\page.tsx (simplified Packing Run)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. app/(dashboard)/page.tsx  (UPDATE - Dashboard low stock: wrappers+boxes)
# ---------------------------------------------------------------------------
$dashboardPath = Join-Path $AppDash "page.tsx"
if (Test-Path $dashboardPath) {
    $dashboardText = [System.IO.File]::ReadAllText($dashboardPath)

    $oldDashHook = 'const packagingMaterials = useStore((s) => s.packagingMaterials);'
    $newDashHook = "const wrappers = useStore((s) => s.wrappers);`r`n  const boxes = useStore((s) => s.boxes);"
    if ($dashboardText.Contains($oldDashHook)) {
        $dashboardText = $dashboardText.Replace($oldDashHook, $newDashHook)
    }

    $oldLowStockBlock = @'
  const lowStockItems = useMemo(() => {
    const rawAlerts = rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold }));
    const packagingAlerts = packagingMaterials
      .filter((p) => p.stockQty < p.lowStockThreshold)
      .map((p) => ({ id: p.id, name: p.name, href: `/packaging`, qty: p.stockQty, threshold: p.lowStockThreshold }));
    return [...rawAlerts, ...packagingAlerts];
  }, [rawMaterials, packagingMaterials]);
'@
    $newLowStockBlock = @'
  const lowStockItems = useMemo(() => {
    const rawAlerts = rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold }));
    const wrapperAlerts = wrappers
      .filter((w) => w.stockQty < w.lowStockThreshold)
      .map((w) => ({ id: w.id, name: w.name, href: `/packaging`, qty: w.stockQty, threshold: w.lowStockThreshold }));
    const boxAlerts = boxes
      .filter((b) => b.stockQty < b.lowStockThreshold)
      .map((b) => ({ id: b.id, name: b.name, href: `/packaging`, qty: b.stockQty, threshold: b.lowStockThreshold }));
    return [...rawAlerts, ...wrapperAlerts, ...boxAlerts];
  }, [rawMaterials, wrappers, boxes]);
'@
    if ($dashboardText.Contains($oldLowStockBlock)) {
        $dashboardText = $dashboardText.Replace($oldLowStockBlock, $newLowStockBlock)
        Write-Host "  [4/6] Updated app\(dashboard)\page.tsx (Dashboard low-stock now uses wrappers+boxes)" -ForegroundColor Green
    } else {
        Write-Host "  [4/6] WARNING: could not find exact lowStockItems block in dashboard page.tsx - please check manually" -ForegroundColor Yellow
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($dashboardPath, $dashboardText, $utf8NoBom)
} else {
    Write-Host "  [4/6] WARNING: dashboard page.tsx not found, skipped" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 5. components/ui/topbar.tsx  (UPDATE - notification bell: wrappers+boxes)
# ---------------------------------------------------------------------------
$topbarPath = Join-Path $Components "topbar.tsx"
if (Test-Path $topbarPath) {
    $topbarText = [System.IO.File]::ReadAllText($topbarPath)

    $oldTopbarHook = 'const packagingMaterials = useStore((s) => s.packagingMaterials);'
    $newTopbarHook = "const wrappers = useStore((s) => s.wrappers);`r`n  const boxes = useStore((s) => s.boxes);"
    if ($topbarText.Contains($oldTopbarHook)) {
        $topbarText = $topbarText.Replace($oldTopbarHook, $newTopbarHook)
    }

    $oldAlertsBlock = @'
  const alerts = [
    ...rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold })),
    ...packagingMaterials
      .filter((p) => p.stockQty < p.lowStockThreshold)
      .map((p) => ({ id: p.id, name: p.name, href: `/packaging`, qty: p.stockQty, threshold: p.lowStockThreshold })),
  ];
'@
    $newAlertsBlock = @'
  const alerts = [
    ...rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold })),
    ...wrappers
      .filter((w) => w.stockQty < w.lowStockThreshold)
      .map((w) => ({ id: w.id, name: w.name, href: `/packaging`, qty: w.stockQty, threshold: w.lowStockThreshold })),
    ...boxes
      .filter((b) => b.stockQty < b.lowStockThreshold)
      .map((b) => ({ id: b.id, name: b.name, href: `/packaging`, qty: b.stockQty, threshold: b.lowStockThreshold })),
  ];
'@
    if ($topbarText.Contains($oldAlertsBlock)) {
        $topbarText = $topbarText.Replace($oldAlertsBlock, $newAlertsBlock)
        Write-Host "  [5/6] Updated components\ui\topbar.tsx (notification bell now uses wrappers+boxes)" -ForegroundColor Green
    } else {
        Write-Host "  [5/6] WARNING: could not find exact alerts block in topbar.tsx - please check manually" -ForegroundColor Yellow
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($topbarPath, $topbarText, $utf8NoBom)
} else {
    Write-Host "  [5/6] WARNING: topbar.tsx not found, skipped" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 6. app/(dashboard)/reports/page.tsx  (UPDATE - inventory chart: wrappers+boxes)
# ---------------------------------------------------------------------------
$reportsPath = Join-Path $AppDash "reports\page.tsx"
if (Test-Path $reportsPath) {
    $reportsText = [System.IO.File]::ReadAllText($reportsPath)

    $oldReportsHook = 'const packagingMaterials = useStore((s) => s.packagingMaterials);'
    $newReportsHook = "const wrappers = useStore((s) => s.wrappers);`r`n  const boxes = useStore((s) => s.boxes);"
    if ($reportsText.Contains($oldReportsHook)) {
        $reportsText = $reportsText.Replace($oldReportsHook, $newReportsHook)
    }

    $oldInventoryData = @'
  const inventoryData = useMemo(() => [
    ...rawMaterials.map((m) => ({ name: m.name, stock: m.quantityInStock, threshold: m.lowStockThreshold, type: "Raw" })),
    ...packagingMaterials.map((p) => ({ name: p.name, stock: p.stockQty, threshold: p.lowStockThreshold, type: "Packaging" })),
  ], [rawMaterials, packagingMaterials]);
'@
    $newInventoryData = @'
  const inventoryData = useMemo(() => [
    ...rawMaterials.map((m) => ({ name: m.name, stock: m.quantityInStock, threshold: m.lowStockThreshold, type: "Raw" })),
    ...wrappers.map((w) => ({ name: w.name, stock: w.stockQty, threshold: w.lowStockThreshold, type: "Wrapper" })),
    ...boxes.map((b) => ({ name: b.name, stock: b.stockQty, threshold: b.lowStockThreshold, type: "Box" })),
  ], [rawMaterials, wrappers, boxes]);
'@
    if ($reportsText.Contains($oldInventoryData)) {
        $reportsText = $reportsText.Replace($oldInventoryData, $newInventoryData)
        Write-Host "  [6/6] Updated app\(dashboard)\reports\page.tsx (inventory chart now uses wrappers+boxes)" -ForegroundColor Green
    } else {
        Write-Host "  [6/6] WARNING: could not find exact inventoryData block in reports\page.tsx - please check manually" -ForegroundColor Yellow
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($reportsPath, $reportsText, $utf8NoBom)
} else {
    Write-Host "  [6/6] WARNING: reports\page.tsx not found, skipped" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 7. components/ui/sidebar-component.tsx  (UPDATE - add Carton Config link)
# ---------------------------------------------------------------------------
$sidebarPath = Join-Path $Components "sidebar-component.tsx"
if (Test-Path $sidebarPath) {
    $sidebarText = [System.IO.File]::ReadAllText($sidebarPath)

    if ($sidebarText.Contains('"/packaging/carton-config"')) {
        Write-Host "  [extra] Sidebar already has a carton-config link - skipped" -ForegroundColor Yellow
    } else {
        $oldRawMatPrefix = '["/packaging", "raw-materials"],'
        $newRawMatPrefix = "[`"/packaging`", `"raw-materials`"],`r`n  [`"/packaging/carton-config`", `"raw-materials`"],"
        if ($sidebarText.Contains($oldRawMatPrefix)) {
            $sidebarText = $sidebarText.Replace($oldRawMatPrefix, $newRawMatPrefix)
        }

        $oldPackagingNavItem = '{ icon: <FolderOpen size={16} className="text-[var(--foreground)]" />, label: "Packaging Materials", href: "/packaging" },'
        $newPackagingNavItem = "{ icon: <FolderOpen size={16} className=`"text-[var(--foreground)]`" />, label: `"Packaging Materials`", href: `"/packaging`" },`r`n            { icon: <Archive size={16} className=`"text-[var(--foreground)]`" />, label: `"Carton Configurations`", href: `"/packaging/carton-config`" },"
        if ($sidebarText.Contains($oldPackagingNavItem)) {
            $sidebarText = $sidebarText.Replace($oldPackagingNavItem, $newPackagingNavItem)
            Write-Host "  [extra] Added 'Carton Configurations' link to sidebar under Raw Materials section" -ForegroundColor Green
        } else {
            Write-Host "  [extra] WARNING: could not find Packaging Materials nav item in sidebar - skipped" -ForegroundColor Yellow
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($sidebarPath, $sidebarText, $utf8NoBom)
    }
} else {
    Write-Host "  [extra] WARNING: sidebar-component.tsx not found, skipped" -ForegroundColor Yellow
}

Write-Host "`n=== Phase 3 complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "DONE in this script:" -ForegroundColor Yellow
Write-Host "  - packaging/page.tsx           : REWRITTEN - Wrappers / Boxes tabs, Add + Restock dialogs" -ForegroundColor Gray
Write-Host "  - packaging/carton-config/page.tsx : NEW - list + create Carton Configuration form" -ForegroundColor Gray
Write-Host "  - finished-cartons/page.tsx    : REWRITTEN - Packing Run now only asks Batch + Config + Cartons Produced," -ForegroundColor Gray
Write-Host "                                    shows live preview of cost/packet, cost/box, cost/carton" -ForegroundColor Gray
Write-Host "  - dashboard page.tsx           : low-stock alerts now check wrappers + boxes" -ForegroundColor Gray
Write-Host "  - topbar.tsx                   : notification bell now checks wrappers + boxes" -ForegroundColor Gray
Write-Host "  - reports/page.tsx             : inventory movement chart now includes wrappers + boxes" -ForegroundColor Gray
Write-Host "  - sidebar-component.tsx        : added 'Carton Configurations' link under Raw Materials section" -ForegroundColor Gray
Write-Host ""
Write-Host "If any [WARNING] lines appeared above, that specific block did not match exactly" -ForegroundColor Yellow
Write-Host "(likely due to manual edits already made) - open that file and check manually." -ForegroundColor Yellow
Write-Host ""
Write-Host "Next: run 'npm run build --workspace=apps/frontend' (or npm run dev) to confirm a clean build." -ForegroundColor Cyan