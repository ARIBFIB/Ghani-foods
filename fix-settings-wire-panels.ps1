#
# fix-settings-wire-panels.ps1
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# The previous script added the ExportDataPanel/DangerZonePanel imports to
# settings/page.tsx but could not insert the JSX, because the page's root
# returned element is a <form>...</form>, not a <div>...</div> as assumed.
#
# This script:
#   1. Wraps the returned <form> in a React fragment (<> ... </>)
#   2. Adds <ExportDataPanel /> and <DangerZonePanel /> as siblings after
#      the closing </form>, inside the fragment.
#
# Safe to re-run - skipped if already applied.
# Backup made before edit: <file>.bak-<timestamp>
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
}

$settingsPath = Join-Path $root "apps\frontend\app\(dashboard)\settings\page.tsx"

if (-not (Test-Path -LiteralPath $settingsPath)) {
    Write-Host "ERROR: Could not find $settingsPath" -ForegroundColor Red
    exit 1
}

$content = Get-Content -Raw -LiteralPath $settingsPath

if ($content -match '<ExportDataPanel') {
    Write-Host "Settings page already has ExportDataPanel wired in - skipping." -ForegroundColor Yellow
    exit 0
}

if ($content -notmatch 'import \{ ExportDataPanel \}') {
    Write-Host "ERROR: ExportDataPanel import not found. Run add-export-and-delete-data-feature.ps1 first." -ForegroundColor Red
    exit 1
}

Backup-File $settingsPath

# -----------------------------------------------------------------
# 1. Wrap "return ( <form ...>" with a fragment opener
# -----------------------------------------------------------------
$returnAnchor = "return (`r`n    <form onSubmit={handleSubmit(onSubmit)} className=`"space-y-6 max-w-2xl`">"
$returnReplacement = "return (`r`n    <>`r`n    <form onSubmit={handleSubmit(onSubmit)} className=`"space-y-6 max-w-2xl`">"

if (-not $content.Contains($returnAnchor)) {
    Write-Host "ERROR: Could not find the return/<form> anchor - aborting without changes." -ForegroundColor Red
    exit 1
}
$content = $content.Replace($returnAnchor, $returnReplacement)

# -----------------------------------------------------------------
# 2. Close the </form>, add the panels, close the fragment
# -----------------------------------------------------------------
$closeAnchor = "    </form>`r`n  );`r`n}"
$closeReplacement = @"
    </form>

      <ExportDataPanel />
      <DangerZonePanel />
    </>
  );
}
"@

if (-not $content.Contains($closeAnchor)) {
    Write-Host "ERROR: Could not find the closing </form> anchor - aborting without changes." -ForegroundColor Red
    exit 1
}
$content = $content.Replace($closeAnchor, $closeReplacement)

Set-Content -LiteralPath $settingsPath -Value $content -NoNewline

Write-Host ""
Write-Host "Done. Settings page now renders ExportDataPanel and DangerZonePanel." -ForegroundColor Green
Write-Host "Run: npm run build   to verify, then commit + push to deploy." -ForegroundColor Cyan