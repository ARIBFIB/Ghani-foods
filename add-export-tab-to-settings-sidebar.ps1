#
# add-export-tab-to-settings-sidebar.ps1
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Adds a new "Export & Data" item under the Settings > Workspace sidebar
# list (below "Notifications"), linking to /settings - where the
# ExportDataPanel and DangerZonePanel already render.
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

$sidebarPath = Join-Path $root "apps\frontend\components\ui\sidebar-component.tsx"

if (-not (Test-Path -LiteralPath $sidebarPath)) {
    Write-Host "ERROR: Could not find $sidebarPath" -ForegroundColor Red
    exit 1
}

$content = Get-Content -Raw -LiteralPath $sidebarPath

if ($content -match 'label: "Export & Data"') {
    Write-Host "Sidebar already has the Export & Data tab - skipping." -ForegroundColor Yellow
    exit 0
}

Backup-File $sidebarPath

# -----------------------------------------------------------------
# 1. Add a Download icon import (Carbon icons)
# -----------------------------------------------------------------
$importAnchor = "  Notification,`r`n  Close as CloseIcon,`r`n} from `"@carbon/icons-react`";"
$importReplacement = "  Notification,`r`n  Download,`r`n  Close as CloseIcon,`r`n} from `"@carbon/icons-react`";"

if (-not $content.Contains($importAnchor)) {
    Write-Host "ERROR: Could not find the icon import anchor - aborting without changes." -ForegroundColor Red
    exit 1
}
$content = $content.Replace($importAnchor, $importReplacement)

# -----------------------------------------------------------------
# 2. Add the "Export & Data" item after "Notifications"
# -----------------------------------------------------------------
$itemsAnchor = '{ icon: <Notification size={16} className="text-[var(--foreground)]" />, label: "Notifications" },' + "`r`n          ],"
$itemsReplacement = '{ icon: <Notification size={16} className="text-[var(--foreground)]" />, label: "Notifications" },' + "`r`n            " + '{ icon: <Download size={16} className="text-[var(--foreground)]" />, label: "Export & Data", href: "/settings" },' + "`r`n          ],"

if (-not $content.Contains($itemsAnchor)) {
    Write-Host "ERROR: Could not find the Workspace items anchor - aborting without changes." -ForegroundColor Red
    exit 1
}
$content = $content.Replace($itemsAnchor, $itemsReplacement)

Set-Content -LiteralPath $sidebarPath -Value $content -NoNewline

Write-Host ""
Write-Host "Done. Sidebar now has an 'Export & Data' item under Settings > Workspace," -ForegroundColor Green
Write-Host "linking to /settings (where Export and Danger Zone panels already render)." -ForegroundColor Green
Write-Host ""
Write-Host "Now run: npm run build   to verify." -ForegroundColor Cyan