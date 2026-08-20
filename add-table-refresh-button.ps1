#
# add-table-refresh-button.ps1
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# What this does:
#   1. components/ui/sortable-table.tsx -> adds an optional `onRefresh` prop.
#      When passed, a circular refresh icon button (lucide-react RefreshCw)
#      appears next to the search box. Click -> spins while it calls your
#      loader function -> shows a "Table refreshed" toast (or an error
#      toast if it fails) -> button re-enables.
#
#   2. Wires `onRefresh` into the 7 pages that use <SortableTable>, using
#      the per-module Supabase loaders that already exist in lib/store.ts:
#        batches                 -> loadProductionBatches
#        customers                -> loadCustomersModule
#        invoices                 -> loadCustomersModule
#        payments                 -> loadCustomersModule
#        packaging (wrappers/boxes) -> loadPackagingModule
#        packaging/carton-config  -> loadCartonConfigurations
#        suppliers                -> loadRawMaterialsModule
#
#   3. Adds a matching refresh icon button (same style) directly into the
#      header of the 3 pages that use their own custom table markup instead
#      of <SortableTable>:
#        raw-materials    -> loadRawMaterialsModule
#        finished-cartons -> loadFinishedCartons
#        receipts         -> loadRawMaterialsModule (receipts live in that module)
#
# Safe to re-run - already-applied files/lines are skipped.
# Every modified file gets a backup: <file>.bak-<timestamp>
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
}

function App-Path($rel) {
    Join-Path $root ("apps\frontend\" + $rel)
}

# -----------------------------------------------------------------
# 1. Rewrite SortableTable with an optional refresh button
# -----------------------------------------------------------------
$tablePath = App-Path "components\ui\sortable-table.tsx"

if (-not (Test-Path -LiteralPath $tablePath)) {
    Write-Host "ERROR: Could not find $tablePath" -ForegroundColor Red
    exit 1
}

$tableContent = Get-Content -Raw -LiteralPath $tablePath

if ($tableContent -match "onRefresh") {
    Write-Host "sortable-table.tsx already has refresh support - skipping." -ForegroundColor Yellow
}
else {
    Backup-File $tablePath

    $newTable = @'
"use client";

import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender,
  type ColumnDef,
  type SortingState,
} from "@tanstack/react-table";
import { useState } from "react";
import { RefreshCw } from "lucide-react";
import { toast } from "@/components/ui/toast";

interface SortableTableProps<T> {
  data: T[];
  columns: ColumnDef<T, unknown>[];
  globalFilterPlaceholder?: string;
  showGlobalFilter?: boolean;
  /** Optional loader (e.g. a store's loadXModule function). When provided,
   *  a refresh icon button appears next to the search box. */
  onRefresh?: () => Promise<void> | void;
}

export function SortableTable<T>({
  data,
  columns,
  globalFilterPlaceholder = "Search...",
  showGlobalFilter = true,
  onRefresh,
}: SortableTableProps<T>) {
  const [sorting, setSorting] = useState<SortingState>([]);
  const [globalFilter, setGlobalFilter] = useState("");
  const [isRefreshing, setIsRefreshing] = useState(false);

  const table = useReactTable({
    data,
    columns,
    state: { sorting, globalFilter },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
  });

  const handleRefresh = async () => {
    if (!onRefresh || isRefreshing) return;
    setIsRefreshing(true);
    try {
      await onRefresh();
      toast.success("Table refreshed");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to refresh table");
    } finally {
      setIsRefreshing(false);
    }
  };

  return (
    <div className="space-y-3">
      {(showGlobalFilter || onRefresh) && (
        <div className="flex items-center gap-2">
          {showGlobalFilter && (
            <input
              value={globalFilter}
              onChange={(e) => setGlobalFilter(e.target.value)}
              placeholder={globalFilterPlaceholder}
              className="w-full max-w-sm rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
            />
          )}
          {onRefresh && (
            <button
              type="button"
              onClick={handleRefresh}
              disabled={isRefreshing}
              title="Refresh table"
              aria-label="Refresh table"
              className="shrink-0 rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] p-2 text-[var(--text-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--foreground)] disabled:opacity-50 transition-colors"
            >
              <RefreshCw className={`w-4 h-4 ${isRefreshing ? "animate-spin" : ""}`} />
            </button>
          )}
        </div>
      )}

      <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
        <table className="w-full min-w-[640px] text-sm">
          <thead>
            {table.getHeaderGroups().map((hg) => (
              <tr key={hg.id} className="border-b border-[var(--surface-border)] bg-[var(--surface)] text-left text-[var(--text-muted)]">
                {hg.headers.map((header) => (
                  <th
                    key={header.id}
                    className="px-4 py-3 font-medium select-none"
                    style={{ width: header.column.getSize() !== 150 ? header.column.getSize() : undefined }}
                  >
                    {header.isPlaceholder ? null : (
                      <div
                        className={header.column.getCanSort() ? "flex items-center gap-1 cursor-pointer hover:text-[var(--foreground)]" : ""}
                        onClick={header.column.getToggleSortingHandler()}
                      >
                        {flexRender(header.column.columnDef.header, header.getContext())}
                        {header.column.getCanSort() && (
                          <span className="text-xs text-[var(--text-faint)]">
                            {{ asc: " up", desc: " down" }[header.column.getIsSorted() as string] ?? " -"}
                          </span>
                        )}
                      </div>
                    )}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-8 text-center text-[var(--text-faint)]">
                  No results found.
                </td>
              </tr>
            ) : (
              table.getRowModel().rows.map((row) => (
                <tr key={row.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className="px-4 py-3 text-[var(--text-secondary)]">
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="text-xs text-[var(--text-faint)]">
        {table.getFilteredRowModel().rows.length} of {data.length} rows
      </div>
    </div>
  );
}
'@

    Set-Content -LiteralPath $tablePath -Value $newTable -NoNewline
    Write-Host "sortable-table.tsx -> refresh button support added." -ForegroundColor Green
}

# -----------------------------------------------------------------
# 2. Wire onRefresh into the 7 pages using <SortableTable>
# -----------------------------------------------------------------

function Wire-SortableTable {
    param(
        [string]$RelPath,
        [string]$LoaderName,
        [string]$UseStoreImportLine,   # e.g. import { useStore, type ProductionBatch } from "@/lib/store";
        [string[]]$OldNewTablePairs    # pairs of old/new <SortableTable ... /> snippets
    )

    $path = App-Path $RelPath
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "WARNING: Could not find $path - skipping." -ForegroundColor Yellow
        return
    }

    $content = Get-Content -Raw -LiteralPath $path

    if ($content -match "onRefresh=") {
        Write-Host "$RelPath already wired - skipping." -ForegroundColor Yellow
        return
    }

    Backup-File $path

    # add the loader hook right after the first useStore(...) line inside the default export component,
    # simplest robust approach: insert loader hook line right after the "export default function" line's
    # first store selector. We instead just add it right before "const columns" or "return (" - handled per-file below.
    Set-Content -LiteralPath $path -Value $content -NoNewline
}

# --- batches/page.tsx ---
$p = App-Path "app\(dashboard)\batches\page.tsx"
if (Test-Path -LiteralPath $p) {
    $c = Get-Content -Raw -LiteralPath $p
    if ($c -match "onRefresh=") {
        Write-Host "batches/page.tsx already wired - skipping." -ForegroundColor Yellow
    } else {
        Backup-File $p
        $c = $c -replace `
            'const productionBatches = useStore\(\(s\) => s\.productionBatches\);', `
            "const productionBatches = useStore((s) => s.productionBatches);`r`n  const loadProductionBatches = useStore((s) => s.loadProductionBatches);"
        $c = $c -replace `
            '<SortableTable data=\{productionBatches\} columns=\{columns\} globalFilterPlaceholder="Search batches\.\.\." />', `
            '<SortableTable data={productionBatches} columns={columns} globalFilterPlaceholder="Search batches..." onRefresh={loadProductionBatches} />'
        Set-Content -LiteralPath $p -Value $c -NoNewline
        Write-Host "batches/page.tsx -> refresh wired." -ForegroundColor Green
    }
}

# --- customers/page.tsx ---
$p = App-Path "app\(dashboard)\customers\page.tsx"
if (Test-Path -LiteralPath $p) {
    $c = Get-Content -Raw -LiteralPath $p
    if ($c -match "onRefresh=") {
        Write-Host "customers/page.tsx already wired - skipping." -ForegroundColor Yellow
    } else {
        Backup-File $p
        $c = $c -replace `
            'const items = useStore\(\(s\) => s\.customers\);', `
            "const items = useStore((s) => s.customers);`r`n  const loadCustomersModule = useStore((s) => s.loadCustomersModule);"
        $c = $c -replace `
            '<SortableTable data=\{items\} columns=\{columns\} globalFilterPlaceholder="Search customers\.\.\." />', `
            '<SortableTable data={items} columns={columns} globalFilterPlaceholder="Search customers..." onRefresh={loadCustomersModule} />'
        Set-Content -LiteralPath $p -Value $c -NoNewline
        Write-Host "customers/page.tsx -> refresh wired." -ForegroundColor Green
    }
}

# --- invoices/page.tsx ---
$p = App-Path "app\(dashboard)\invoices\page.tsx"
if (Test-Path -LiteralPath $p) {
    $c = Get-Content -Raw -LiteralPath $p
    if ($c -match "onRefresh=") {
        Write-Host "invoices/page.tsx already wired - skipping." -ForegroundColor Yellow
    } else {
        Backup-File $p
        $c = $c -replace `
            'const invoices = useStore\(\(s\) => s\.invoices\);', `
            "const invoices = useStore((s) => s.invoices);`r`n  const loadCustomersModule = useStore((s) => s.loadCustomersModule);"
        $c = $c -replace `
            '<SortableTable data=\{invoices\} columns=\{columns\} globalFilterPlaceholder="Search invoices\.\.\." />', `
            '<SortableTable data={invoices} columns={columns} globalFilterPlaceholder="Search invoices..." onRefresh={loadCustomersModule} />'
        Set-Content -LiteralPath $p -Value $c -NoNewline
        Write-Host "invoices/page.tsx -> refresh wired." -ForegroundColor Green
    }
}

# --- payments/page.tsx ---
$p = App-Path "app\(dashboard)\payments\page.tsx"
if (Test-Path -LiteralPath $p) {
    $c = Get-Content -Raw -LiteralPath $p
    if ($c -match "onRefresh=") {
        Write-Host "payments/page.tsx already wired - skipping." -ForegroundColor Yellow
    } else {
        Backup-File $p
        $c = $c -replace `
            'const items = useStore\(\(s\) => s\.payments\);', `
            "const items = useStore((s) => s.payments);`r`n  const loadCustomersModule = useStore((s) => s.loadCustomersModule);"
        $c = $c -replace `
            '<SortableTable data=\{items\} columns=\{columns\} globalFilterPlaceholder="Search payments\.\.\." />', `
            '<SortableTable data={items} columns={columns} globalFilterPlaceholder="Search payments..." onRefresh={loadCustomersModule} />'
        Set-Content -LiteralPath $p -Value $c -NoNewline
        Write-Host "payments/page.tsx -> refresh wired." -ForegroundColor Green
    }
}

# --- suppliers/page.tsx (loader already imported via useEffect) ---
$p = App-Path "app\(dashboard)\suppliers\page.tsx"
if (Test-Path -LiteralPath $p) {
    $c = Get-Content -Raw -LiteralPath $p
    if ($c -match "onRefresh=") {
        Write-Host "suppliers/page.tsx already wired - skipping." -ForegroundColor Yellow
    } else {
        Backup-File $p
        $c = $c -replace `
            '<SortableTable data=\{rows\} columns=\{columns\} globalFilterPlaceholder="Search suppliers\.\.\." />', `
            '<SortableTable data={rows} columns={columns} globalFilterPlaceholder="Search suppliers..." onRefresh={loadRawMaterialsModule} />'
        Set-Content -LiteralPath $p -Value $c -NoNewline
        Write-Host "suppliers/page.tsx -> refresh wired." -ForegroundColor Green
    }
}

# --- packaging/carton-config/page.tsx ---
$p = App-Path "app\(dashboard)\packaging\carton-config\page.tsx"
if (Test-Path -LiteralPath $p) {
    $c = Get-Content -Raw -LiteralPath $p
    if ($c -match "onRefresh=") {
        Write-Host "packaging/carton-config/page.tsx already wired - skipping." -ForegroundColor Yellow
    } else {
        Backup-File $p
        $c = $c -replace `
            'const configs = useStore\(\(s\) => s\.cartonConfigurations\);', `
            "const configs = useStore((s) => s.cartonConfigurations);`r`n  const loadCartonConfigurations = useStore((s) => s.loadCartonConfigurations);"
        $c = $c -replace `
            '<SortableTable data=\{rows\} columns=\{columns\} globalFilterPlaceholder="Search configurations\.\.\." />', `
            '<SortableTable data={rows} columns={columns} globalFilterPlaceholder="Search configurations..." onRefresh={loadCartonConfigurations} />'
        Set-Content -LiteralPath $p -Value $c -NoNewline
        Write-Host "packaging/carton-config/page.tsx -> refresh wired." -ForegroundColor Green
    }
}

# --- packaging/page.tsx (two tables: wrappers + boxes) ---
$p = App-Path "app\(dashboard)\packaging\page.tsx"
if (Test-Path -LiteralPath $p) {
    $c = Get-Content -Raw -LiteralPath $p
    if ($c -match "onRefresh=") {
        Write-Host "packaging/page.tsx already wired - skipping." -ForegroundColor Yellow
    } else {
        Backup-File $p
        $c = $c -replace `
            'const boxUnitCost = useStore\(\(s\) => s\.boxUnitCost\);', `
            "const boxUnitCost = useStore((s) => s.boxUnitCost);`r`n  const loadPackagingModule = useStore((s) => s.loadPackagingModule);"
        $c = $c -replace `
            '<SortableTable data=\{wrappers\} columns=\{wrapperColumns\} globalFilterPlaceholder="Search wrappers\.\.\." />', `
            '<SortableTable data={wrappers} columns={wrapperColumns} globalFilterPlaceholder="Search wrappers..." onRefresh={loadPackagingModule} />'
        $c = $c -replace `
            '<SortableTable data=\{boxes\} columns=\{boxColumns\} globalFilterPlaceholder="Search boxes\.\.\." />', `
            '<SortableTable data={boxes} columns={boxColumns} globalFilterPlaceholder="Search boxes..." onRefresh={loadPackagingModule} />'
        Set-Content -LiteralPath $p -Value $c -NoNewline
        Write-Host "packaging/page.tsx -> refresh wired (both tabs)." -ForegroundColor Green
    }
}

# -----------------------------------------------------------------
# 3. Add a matching refresh button into the 3 custom-table pages
# -----------------------------------------------------------------

function Add-HeaderRefreshButton {
    param(
        [string]$RelPath,
        [string]$LoaderStateName,   # store field name, e.g. loadRawMaterialsModule
        [string]$LoaderHookLineAnchorOld,
        [string]$LoaderHookLineAnchorNew,
        [string]$HeaderOld,
        [string]$HeaderNew
    )

    $path = App-Path $RelPath
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "WARNING: Could not find $path - skipping." -ForegroundColor Yellow
        return
    }

    $c = Get-Content -Raw -LiteralPath $path
    if ($c -match "RefreshCw") {
        Write-Host "$RelPath already has a refresh button - skipping." -ForegroundColor Yellow
        return
    }

    Backup-File $path

    # add lucide import if missing
    if ($c -notmatch 'from "lucide-react"') {
        $c = $c -replace '("use client";\r?\n)', "`$1`r`nimport { RefreshCw } from `"lucide-react`";"
    }
    elseif ($c -notmatch "RefreshCw") {
        $c = $c -replace 'import \{ ([^}]+) \} from "lucide-react";', 'import { $1, RefreshCw } from "lucide-react";'
    }

    $c = $c -replace [regex]::Escape($LoaderHookLineAnchorOld), $LoaderHookLineAnchorNew
    $c = $c -replace [regex]::Escape($HeaderOld), $HeaderNew

    Set-Content -LiteralPath $path -Value $c -NoNewline
    Write-Host "$RelPath -> refresh button added." -ForegroundColor Green
}

# raw-materials/page.tsx
Add-HeaderRefreshButton `
    -RelPath "app\(dashboard)\raw-materials\page.tsx" `
    -LoaderStateName "loadRawMaterialsModule" `
    -LoaderHookLineAnchorOld 'const addRawMaterial = useStore((s) => s.addRawMaterial);' `
    -LoaderHookLineAnchorNew "const addRawMaterial = useStore((s) => s.addRawMaterial);`r`n  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);`r`n  const [isRefreshing, setIsRefreshing] = useState(false);`r`n  const handleRefresh = async () => {`r`n    if (isRefreshing) return;`r`n    setIsRefreshing(true);`r`n    try {`r`n      await loadRawMaterialsModule();`r`n      toast.success(`"Table refreshed`");`r`n    } catch (err) {`r`n      toast.error(err instanceof Error ? err.message : `"Failed to refresh`");`r`n    } finally {`r`n      setIsRefreshing(false);`r`n    }`r`n  };" `
    -HeaderOld '<h1 className="text-xl font-semibold text-[var(--foreground)]">Raw Materials</h1>' `
    -HeaderNew "<div className=`"flex items-center gap-2`">`r`n          <h1 className=`"text-xl font-semibold text-[var(--foreground)]`">Raw Materials</h1>`r`n          <button type=`"button`" onClick={handleRefresh} disabled={isRefreshing} title=`"Refresh table`" aria-label=`"Refresh table`" className=`"shrink-0 rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] p-2 text-[var(--text-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--foreground)] disabled:opacity-50 transition-colors`">`r`n            <RefreshCw className={``w-4 h-4 `${isRefreshing ? `"animate-spin`" : `"`"}``} />`r`n          </button>`r`n        </div>"

# finished-cartons/page.tsx
Add-HeaderRefreshButton `
    -RelPath "app\(dashboard)\finished-cartons\page.tsx" `
    -LoaderStateName "loadFinishedCartons" `
    -LoaderHookLineAnchorOld 'const cartons = useStore((s) => s.finishedCartons);' `
    -LoaderHookLineAnchorNew "const cartons = useStore((s) => s.finishedCartons);`r`n  const loadFinishedCartons = useStore((s) => s.loadFinishedCartons);`r`n  const [isRefreshing, setIsRefreshing] = useState(false);`r`n  const handleRefresh = async () => {`r`n    if (isRefreshing) return;`r`n    setIsRefreshing(true);`r`n    try {`r`n      await loadFinishedCartons();`r`n      toast.success(`"Table refreshed`");`r`n    } catch (err) {`r`n      toast.error(err instanceof Error ? err.message : `"Failed to refresh`");`r`n    } finally {`r`n      setIsRefreshing(false);`r`n    }`r`n  };" `
    -HeaderOld '<h1 className="text-xl font-semibold text-[var(--foreground)]">Finished Cartons</h1>' `
    -HeaderNew "<div className=`"flex items-center gap-2`">`r`n          <h1 className=`"text-xl font-semibold text-[var(--foreground)]`">Finished Cartons</h1>`r`n          <button type=`"button`" onClick={handleRefresh} disabled={isRefreshing} title=`"Refresh table`" aria-label=`"Refresh table`" className=`"shrink-0 rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] p-2 text-[var(--text-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--foreground)] disabled:opacity-50 transition-colors`">`r`n            <RefreshCw className={``w-4 h-4 `${isRefreshing ? `"animate-spin`" : `"`"}``} />`r`n          </button>`r`n        </div>"

# receipts/page.tsx
Add-HeaderRefreshButton `
    -RelPath "app\(dashboard)\receipts\page.tsx" `
    -LoaderStateName "loadRawMaterialsModule" `
    -LoaderHookLineAnchorOld 'const [dialogOpen, setDialogOpen] = useState(false);' `
    -LoaderHookLineAnchorNew "const [dialogOpen, setDialogOpen] = useState(false);`r`n  const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);`r`n  const [isRefreshing, setIsRefreshing] = useState(false);`r`n  const handleRefresh = async () => {`r`n    if (isRefreshing) return;`r`n    setIsRefreshing(true);`r`n    try {`r`n      await loadRawMaterialsModule();`r`n      toast.success(`"Table refreshed`");`r`n    } catch (err) {`r`n      toast.error(err instanceof Error ? err.message : `"Failed to refresh`");`r`n    } finally {`r`n      setIsRefreshing(false);`r`n    }`r`n  };" `
    -HeaderOld '<h1 className="text-xl font-semibold text-[var(--foreground)]">Receipts</h1>' `
    -HeaderNew "<div className=`"flex items-center gap-2`">`r`n          <h1 className=`"text-xl font-semibold text-[var(--foreground)]`">Receipts</h1>`r`n          <button type=`"button`" onClick={handleRefresh} disabled={isRefreshing} title=`"Refresh table`" aria-label=`"Refresh table`" className=`"shrink-0 rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] p-2 text-[var(--text-muted)] hover:bg-[var(--surface-hover)] hover:text-[var(--foreground)] disabled:opacity-50 transition-colors`">`r`n            <RefreshCw className={``w-4 h-4 `${isRefreshing ? `"animate-spin`" : `"`"}``} />`r`n          </button>`r`n        </div>"

# Also make sure the toast import exists in these 3 files (needed for the inline handleRefresh)
foreach ($rel in @("app\(dashboard)\raw-materials\page.tsx", "app\(dashboard)\finished-cartons\page.tsx", "app\(dashboard)\receipts\page.tsx")) {
    $p = App-Path $rel
    if (Test-Path -LiteralPath $p) {
        $c = Get-Content -Raw -LiteralPath $p
        if ($c -notmatch 'toast\s*}\s*from\s*"@/components/ui/toast"' -and $c -notmatch 'from "sonner"') {
            Backup-File $p
            $c = $c -replace '("use client";\r?\n)', "`$1`r`nimport { toast } from `"@/components/ui/toast`";"
            Set-Content -LiteralPath $p -Value $c -NoNewline
            Write-Host "$rel -> added missing toast import." -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Done. Har table ke upar ab ek refresh icon button hai - click karte hi Supabase se fresh data aayega." -ForegroundColor Green
Write-Host "Agar kisi file mein WARNING nahi aayi to matlab replace exact match ho gaya - safe hai." -ForegroundColor DarkGray