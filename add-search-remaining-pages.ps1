#
# add-search-remaining-pages.ps1
# ---------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Client requested a search bar on EVERY screen. Turns out most screens
# already have one - they use a shared <SortableTable> component which
# has a search box built in by default:
#   Suppliers, Customers, Batches, Invoices, Payments, Packaging
#   (both the wrapper/box list and Carton Configurations list)
# Raw Materials has its own custom search box too.
#
# That left exactly two screens with no search:
#   1. Finished Cartons (Ready for Sale tab) - adds a search box that
#      filters by carton name or source batch id.
#   2. Receipts - adds a free-text search box (in addition to the existing
#      Supplier/Material/Date dropdown filters) that matches supplier name
#      or any raw material name on the receipt.
#
# Safe to re-run - already-applied files are skipped.
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Normalize([string]$s) { return $s -replace "`r`n", "`n" }

function Apply-Fix {
    param([string]$RelativePath, [string]$OldBlock, [string]$NewBlock, [string]$AlreadyFixedMarker)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "ERROR: Could not find $path" -ForegroundColor Red
        return
    }
    $raw = Get-Content -Raw -LiteralPath $path
    $usesCrlf = $raw -match "`r`n"
    $norm = Normalize $raw
    if ($norm -match [regex]::Escape($AlreadyFixedMarker)) {
        Write-Host "$RelativePath already has search - skipping." -ForegroundColor Yellow
        return
    }
    $oldNorm = (Normalize $OldBlock).Trim()
    $newNorm = (Normalize $NewBlock).Trim()
    if ($norm -notmatch [regex]::Escape($oldNorm)) {
        Write-Host "ERROR: Expected block not found in $RelativePath - skipping (check by hand)." -ForegroundColor Red
        return
    }
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    $fixed = $norm.Replace($oldNorm, $newNorm)
    if ($usesCrlf) { $fixed = $fixed -replace "`n", "`r`n" }
    Set-Content -LiteralPath $path -Value $fixed -NoNewline
    Write-Host "Fixed: $RelativePath" -ForegroundColor Green
}

# ---------------------------------------------------------------------
# 1) Finished Cartons - add search
# ---------------------------------------------------------------------
$fcPath = 'apps\frontend\app\(dashboard)\finished-cartons\page.tsx'

$fc_old1 = @'
  const [tab, setTab] = useState<"ready" | "leftover">("ready");
  const [dialogOpen, setDialogOpen] = useState(false);

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);
'@
$fc_new1 = @'
  const [tab, setTab] = useState<"ready" | "leftover">("ready");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [search, setSearch] = useState("");

  const leftoverBatches = productionBatches.filter((b) => b.leftoverQtyKg > 0);
  const filteredCartons = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return cartons;
    return cartons.filter(
      (c) => c.name.toLowerCase().includes(q) || String(c.sourceBatchId).toLowerCase().includes(q)
    );
  }, [cartons, search]);
'@

$fc_old2 = @'
      {tab === "ready" ? (
        <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
          <table className="w-full text-sm">
'@
$fc_new2 = @'
      {tab === "ready" && (
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search finished cartons..."
          className="w-full max-w-sm rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
        />
      )}

      {tab === "ready" ? (
        <div className="overflow-x-auto rounded-xl border border-[var(--surface-border)]">
          <table className="w-full text-sm">
'@

$fc_old3 = @'
              {cartons.map((c) => (
                <tr key={c.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
'@
$fc_new3 = @'
              {filteredCartons.map((c) => (
                <tr key={c.id} className="border-b border-[var(--surface-border)] last:border-0 hover:bg-[var(--surface)]/60">
'@

$fc_old4 = @'
              {cartons.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-[var(--text-faint)]">No finished cartons yet.</td></tr>
              )}
'@
$fc_new4 = @'
              {filteredCartons.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-[var(--text-faint)]">
                  {search ? "No finished cartons match your search." : "No finished cartons yet."}
                </td></tr>
              )}
'@

$fcFull = Join-Path $root $fcPath
if (-not (Test-Path -LiteralPath $fcFull)) {
    Write-Host "ERROR: Could not find $fcFull" -ForegroundColor Red
} else {
    $raw = Get-Content -Raw -LiteralPath $fcFull
    $usesCrlf = $raw -match "`r`n"
    $norm = Normalize $raw
    if ($norm -match [regex]::Escape('Search finished cartons')) {
        Write-Host "$fcPath already has search - skipping." -ForegroundColor Yellow
    } else {
        $blocks = @(
            @{ old = $fc_old1; new = $fc_new1 },
            @{ old = $fc_old2; new = $fc_new2 },
            @{ old = $fc_old3; new = $fc_new3 },
            @{ old = $fc_old4; new = $fc_new4 }
        )
        $missing = $false
        foreach ($b in $blocks) {
            if ($norm -notmatch [regex]::Escape((Normalize $b.old).Trim())) { $missing = $true }
        }
        if ($missing) {
            Write-Host "ERROR: Expected blocks not found in $fcPath - skipping (check by hand)." -ForegroundColor Red
        } else {
            Copy-Item -LiteralPath $fcFull -Destination "$fcFull.bak-$stamp"
            foreach ($b in $blocks) {
                $norm = $norm.Replace((Normalize $b.old).Trim(), (Normalize $b.new).Trim())
            }
            if ($usesCrlf) { $norm = $norm -replace "`n", "`r`n" }
            Set-Content -LiteralPath $fcFull -Value $norm -NoNewline
            Write-Host "Fixed: $fcPath (added search)" -ForegroundColor Green
        }
    }
}

# ---------------------------------------------------------------------
# 2) Receipts - add free-text search
# ---------------------------------------------------------------------
$rcPath = 'apps\frontend\app\(dashboard)\receipts\page.tsx'

$rc_old1 = @'
  const [supplierFilter, setSupplierFilter] = useState("");
  const [materialFilter, setMaterialFilter] = useState("");
'@
$rc_new1 = @'
  const [search, setSearch] = useState("");
  const [supplierFilter, setSupplierFilter] = useState("");
  const [materialFilter, setMaterialFilter] = useState("");
'@

$rc_old2 = @'
      .filter(({ receipt, lines }) => {
        if (supplierFilter && receipt.supplierId !== supplierFilter) return false;
        if (materialFilter && !lines.some((l) => l.rawMaterialId === materialFilter)) return false;
        if (fromDate && receipt.purchaseDate < fromDate) return false;
        if (toDate && receipt.purchaseDate > toDate) return false;
        return true;
      })
'@
$rc_new2 = @'
      .filter(({ receipt, lines, supplier, itemNames }) => {
        if (supplierFilter && receipt.supplierId !== supplierFilter) return false;
        if (materialFilter && !lines.some((l) => l.rawMaterialId === materialFilter)) return false;
        if (fromDate && receipt.purchaseDate < fromDate) return false;
        if (toDate && receipt.purchaseDate > toDate) return false;
        if (search.trim()) {
          const q = search.trim().toLowerCase();
          const haystack = `${supplier?.name ?? ""} ${itemNames.join(" ")}`.toLowerCase();
          if (!haystack.includes(q)) return false;
        }
        return true;
      })
'@

$rc_old3 = @'
      <div className="flex flex-col sm:flex-row flex-wrap items-stretch sm:items-end gap-3 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
        <div>
          <label className="text-xs text-[var(--text-muted)]">Supplier</label>
'@
$rc_new3 = @'
      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search receipts by supplier or raw material..."
        className="w-full max-w-sm rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
      />

      <div className="flex flex-col sm:flex-row flex-wrap items-stretch sm:items-end gap-3 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4">
        <div>
          <label className="text-xs text-[var(--text-muted)]">Supplier</label>
'@

$rcFull = Join-Path $root $rcPath
if (-not (Test-Path -LiteralPath $rcFull)) {
    Write-Host "ERROR: Could not find $rcFull" -ForegroundColor Red
} else {
    $raw = Get-Content -Raw -LiteralPath $rcFull
    $usesCrlf = $raw -match "`r`n"
    $norm = Normalize $raw
    if ($norm -match [regex]::Escape('Search receipts by supplier')) {
        Write-Host "$rcPath already has search - skipping." -ForegroundColor Yellow
    } else {
        $blocks = @(
            @{ old = $rc_old1; new = $rc_new1 },
            @{ old = $rc_old2; new = $rc_new2 },
            @{ old = $rc_old3; new = $rc_new3 }
        )
        $missing = $false
        foreach ($b in $blocks) {
            if ($norm -notmatch [regex]::Escape((Normalize $b.old).Trim())) { $missing = $true }
        }
        if ($missing) {
            Write-Host "ERROR: Expected blocks not found in $rcPath - skipping (check by hand). This can happen if your receipts page differs from the version created by add-receipt-delete-edit.ps1 - let me know and I'll adjust." -ForegroundColor Red
        } else {
            Copy-Item -LiteralPath $rcFull -Destination "$rcFull.bak-$stamp"
            foreach ($b in $blocks) {
                $norm = $norm.Replace((Normalize $b.old).Trim(), (Normalize $b.new).Trim())
            }
            if ($usesCrlf) { $norm = $norm -replace "`n", "`r`n" }
            Set-Content -LiteralPath $rcFull -Value $norm -NoNewline
            Write-Host "Fixed: $rcPath (added search)" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd apps\frontend; npm run dev"
Write-Host "  2. Finished Cartons -> Ready for Sale tab -> try the new search box."
Write-Host "  3. Receipts -> try the new search box (type a supplier or material name)."
Write-Host ""
Write-Host "Search bar coverage across the app is now complete:" -ForegroundColor Cyan
Write-Host "  Suppliers, Customers, Batches, Invoices, Payments, Packaging," -ForegroundColor Cyan
Write-Host "  Carton Configurations, Raw Materials, Finished Cartons, Receipts."