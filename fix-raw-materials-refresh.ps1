#
# fix-raw-materials-refresh.ps1  (v2 - regex based, whitespace-tolerant)
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes: apps/frontend/app/(dashboard)/raw-materials/page.tsx
#
#   isRefreshing/handleRefresh were declared inside AddRawMaterialMasterDialog
#   but the <button onClick={handleRefresh}> that needs them lives in the
#   RawMaterialsPage component -> "Cannot find name 'handleRefresh'" build error.
#
#   This version uses regex (not exact string match) so it isn't thrown off by
#   extra blank lines / CRLF differences introduced by other scripts.
#
# Safe to re-run - already-applied files are skipped.
# Backup made before any edit: <file>.bak-<timestamp>
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
}

$pagePath = Join-Path $root "apps\frontend\app\(dashboard)\raw-materials\page.tsx"

if (-not (Test-Path -LiteralPath $pagePath)) {
    Write-Host "ERROR: Could not find $pagePath" -ForegroundColor Red
    exit 1
}

$content = Get-Content -Raw -LiteralPath $pagePath

# -----------------------------------------------------------------
# Idempotency check: does RawMaterialsPage already declare isRefreshing?
# (i.e. does "const [isRefreshing" appear AFTER "export default function RawMaterialsPage")
# -----------------------------------------------------------------
$pageMarkerIdx = $content.IndexOf("export default function RawMaterialsPage")
if ($pageMarkerIdx -ge 0) {
    $afterPageMarker = $content.Substring($pageMarkerIdx)
    if ($afterPageMarker -match "const\s*\[\s*isRefreshing") {
        Write-Host "raw-materials/page.tsx already fixed - skipping." -ForegroundColor Yellow
        exit 0
    }
}
else {
    Write-Host "ERROR: Could not find 'export default function RawMaterialsPage' in the file - aborting." -ForegroundColor Red
    exit 1
}

Backup-File $pagePath

# -----------------------------------------------------------------
# 1. Remove the stray isRefreshing/handleRefresh block from
#    AddRawMaterialMasterDialog (only search BEFORE the page marker).
# -----------------------------------------------------------------
$beforePage = $content.Substring(0, $pageMarkerIdx)
$afterPageFull = $content.Substring($pageMarkerIdx)

$strayPattern = '(?s)\s*const\s*\[\s*isRefreshing\s*,\s*setIsRefreshing\s*\]\s*=\s*useState\(false\);\s*const\s+handleRefresh\s*=\s*async\s*\(\)\s*=>\s*\{.*?\};\s*(?=const\s*\{\s*register)'

$newBeforePage = [regex]::Replace($beforePage, $strayPattern, "`n  ")

if ($newBeforePage -eq $beforePage) {
    Write-Host "  WARNING: Stray block in AddRawMaterialMasterDialog not matched (may already differ) - continuing." -ForegroundColor Yellow
} else {
    Write-Host "  Removed stray isRefreshing/handleRefresh from AddRawMaterialMasterDialog." -ForegroundColor Green
    $beforePage = $newBeforePage
}

# -----------------------------------------------------------------
# 2. Insert isRefreshing + handleRefresh into RawMaterialsPage, right
#    after its "loadRawMaterialsModule(); }, [loadRawMaterialsModule]);"
#    useEffect block.
# -----------------------------------------------------------------
$anchorPattern = '(?s)(useEffect\(\(\)\s*=>\s*\{\s*loadRawMaterialsModule\(\);\s*\},\s*\[loadRawMaterialsModule\]\);)'

if ($afterPageFull -notmatch $anchorPattern) {
    Write-Host "ERROR: Could not find the loadRawMaterialsModule useEffect inside RawMaterialsPage - aborting without changes." -ForegroundColor Red
    exit 1
}

$insertion = @"
`$1

  const [isRefreshing, setIsRefreshing] = useState(false);
  const handleRefresh = async () => {
    if (isRefreshing) return;
    setIsRefreshing(true);
    try {
      await loadRawMaterialsModule();
      toast.success("Table refreshed");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to refresh");
    } finally {
      setIsRefreshing(false);
    }
  };
"@

$newAfterPageFull = [regex]::Replace($afterPageFull, $anchorPattern, $insertion, 1)

$finalContent = $beforePage + $newAfterPageFull

Set-Content -LiteralPath $pagePath -Value $finalContent -NoNewline

Write-Host ""
Write-Host "Done. raw-materials/page.tsx patched:" -ForegroundColor Green
Write-Host "  - isRefreshing/handleRefresh now live in RawMaterialsPage (used by the button)." -ForegroundColor Green
Write-Host "  - Stray unused copy removed from AddRawMaterialMasterDialog (if present)." -ForegroundColor Green
Write-Host ""
Write-Host "Now run: npm run build   (or push to trigger the Vercel build) to verify." -ForegroundColor Cyan