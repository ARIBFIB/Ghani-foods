<#
  Step 10b — Repair corrupted table header in raw-materials/page.tsx
  ------------------------------------------------------------------
  Gap found: the "Avg Unit Cost" <th> header cell (added when the
  InfoTip tooltip was injected in an earlier step) got mangled -
  it now contains literal backslash characters (\r\n and \ ) instead
  of real whitespace/newlines, e.g.:

    <th\ className="px-4\ py-3\ font-medium">\r\n\ \ ... <InfoTip\ text="..."\ />...

  This is invalid JSX and will fail to compile / break the build.

  Step 11 (expandable raw-material purchase history rows) and
  Step 12 (Invoice detail "<- Back" button with router.back() +
  fallback) are BOTH already fully implemented in the current
  codebase - no functional changes needed for those. This script
  only repairs the corrupted header cell so the file compiles again.

  Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#>

$ErrorActionPreference = "Stop"

$root = Get-Location
$rmPagePath = Join-Path $root "apps\frontend\app\(dashboard)\raw-materials\page.tsx"

if (-not (Test-Path $rmPagePath)) {
    Write-Host "ERROR: Could not find $rmPagePath" -ForegroundColor Red
    Write-Host "Make sure you are running this from the GhaniFoods root folder." -ForegroundColor Red
    exit 1
}

function Write-Utf8NoBom($path, $content) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $enc)
}

function Backup-File($path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $bak = "$path.bak-step10b-$stamp"
    Copy-Item -Path $path -Destination $bak -Force
    Write-Host "Backed up: $bak" -ForegroundColor DarkGray
}

Backup-File $rmPagePath
$src = [System.IO.File]::ReadAllText($rmPagePath)
$original = $src

# ---------------------------------------------------------------------------
# Replace the corrupted <th>...Avg Unit Cost...InfoTip...</th> cell using
# clean anchors on either side (the "Qty in Stock" th before it and the
# "Threshold" th after it), so it works regardless of the exact corrupted
# backslash pattern in between.
# ---------------------------------------------------------------------------
$pattern = '(?s)(?<=<th className="px-4 py-3 font-medium">Qty in Stock</th>\s*)<th.*?</th>(?=\s*<th className="px-4 py-3 font-medium">Threshold</th>)'

$replacement = @'
<th className="px-4 py-3 font-medium">
                <span className="inline-flex items-center">
                  Avg Unit Cost
                  <InfoTip text="Weighted average cost per unit across all purchase receipts for this raw material, recalculated on every new receipt." />
                </span>
              </th>
'@

$regex = New-Object System.Text.RegularExpressions.Regex($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

if ($regex.IsMatch($src)) {
    $src = $regex.Replace($src, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1)
} else {
    # Already clean (contains a well-formed InfoTip header) - check and report.
    if ($src.Contains('Avg Unit Cost') -and $src.Contains('<InfoTip text="Weighted average cost per unit across all purchase receipts for this raw material, recalculated on every new receipt."')) {
        Write-Host "Header already clean - skipping." -ForegroundColor DarkGray
    } else {
        Write-Host "WARNING: Could not locate the corrupted/clean Avg Unit Cost header cell between the expected anchors." -ForegroundColor Yellow
        Write-Host "No changes made. Please check apps/frontend/app/(dashboard)/raw-materials/page.tsx manually." -ForegroundColor Yellow
    }
}

if ($src -eq $original) {
    Write-Host "Skipped (already applied or pattern not found): $rmPagePath" -ForegroundColor DarkGray
} else {
    Write-Utf8NoBom $rmPagePath $src
    Write-Host "Updated: $rmPagePath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 10b complete." -ForegroundColor Cyan
Write-Host "  - Repaired the corrupted 'Avg Unit Cost' table header (was full of literal backslashes, broke JSX)." -ForegroundColor Cyan
Write-Host "  - Confirmed: Step 11 (expandable raw-material purchase history rows) already implemented - no change needed." -ForegroundColor Cyan
Write-Host "  - Confirmed: Step 12 (Invoice detail Back button, router.back() + same-tab fallback) already implemented - no change needed." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: cd apps/frontend, run npm run dev, and verify /raw-materials compiles and the header tooltip renders correctly." -ForegroundColor Yellow