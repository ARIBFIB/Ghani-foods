# fix-code-errors.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#   cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
#   .\fix-code-errors.ps1

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendDir = Join-Path $Root "apps\frontend"

$SidebarFile = Join-Path $FrontendDir "components\ui\sidebar-component.tsx"
$PageFile    = Join-Path $FrontendDir "app\(dashboard)\page.tsx"

Write-Host "=== Fixing code errors ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------
# 1. Fix "Grain" -> "Gradient" in sidebar-component.tsx
#    (@carbon/icons-react has no "Grain" export, only "Gradient")
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "[1/2] Fixing sidebar-component.tsx (Grain -> Gradient)..." -ForegroundColor Yellow

if (Test-Path $SidebarFile) {
    $sidebarContent = Get-Content $SidebarFile -Raw
    if ($sidebarContent -match '\bGrain\b') {
        $newSidebarContent = $sidebarContent -replace '\bGrain\b', 'Gradient'
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($SidebarFile, $newSidebarContent, $utf8NoBom)
        Write-Host "  Replaced all 'Grain' with 'Gradient'." -ForegroundColor Green
    } else {
        Write-Host "  No 'Grain' references found (already fixed?)." -ForegroundColor Gray
    }
} else {
    Write-Host "  File not found: $SidebarFile" -ForegroundColor Red
}

# ---------------------------------------------------------------------
# 2. Fix kpis import mismatch in app/(dashboard)/page.tsx
#    kpis.ts exports "dashboardKpis", not "kpis"
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "[2/2] Fixing page.tsx kpis import (dashboardKpis as kpis)..." -ForegroundColor Yellow

if (Test-Path $PageFile) {
    $pageContent = Get-Content $PageFile -Raw
    $oldImport = 'import { kpis } from "@/lib/mock-data/kpis";'
    $newImport = 'import { dashboardKpis as kpis } from "@/lib/mock-data/kpis";'

    if ($pageContent -match [regex]::Escape($oldImport)) {
        $newPageContent = $pageContent -replace [regex]::Escape($oldImport), $newImport
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($PageFile, $newPageContent, $utf8NoBom)
        Write-Host "  Import line fixed." -ForegroundColor Green
    } else {
        Write-Host "  Exact import line not found - checking loosely..." -ForegroundColor Yellow
        if ($pageContent -match 'import\s*\{\s*kpis\s*\}\s*from\s*"@/lib/mock-data/kpis";') {
            $newPageContent = $pageContent -replace 'import\s*\{\s*kpis\s*\}\s*from\s*"@/lib/mock-data/kpis";', $newImport
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($PageFile, $newPageContent, $utf8NoBom)
            Write-Host "  Import line fixed (loose match)." -ForegroundColor Green
        } else {
            Write-Host "  Could not find the kpis import line automatically. Please fix manually:" -ForegroundColor Red
            Write-Host "  Change:  import { kpis } from `"@/lib/mock-data/kpis`";" -ForegroundColor Gray
            Write-Host "  To:      import { dashboardKpis as kpis } from `"@/lib/mock-data/kpis`";" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  File not found: $PageFile" -ForegroundColor Red
}

# ---------------------------------------------------------------------
# 3. Rebuild locally to confirm
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "Running local build to confirm fixes..." -ForegroundColor Yellow
Push-Location $FrontendDir
npm run build
$buildExitCode = $LASTEXITCODE
Pop-Location

if ($buildExitCode -ne 0) {
    Write-Host ""
    Write-Host "Build STILL failing (exit code $buildExitCode). See errors above - there may be more mismatches to fix." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Build SUCCEEDED locally!" -ForegroundColor Green

# ---------------------------------------------------------------------
# 4. Commit and push
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "Committing and pushing..." -ForegroundColor Yellow
$statusOutput = git status --porcelain
if ($statusOutput) {
    git add $SidebarFile
    git add $PageFile
    git commit -m "fix: correct Carbon icon name (Grain -> Gradient) and kpis import mismatch"
    git push origin main
    Write-Host "Pushed to origin/main. Vercel should now build successfully." -ForegroundColor Green
} else {
    Write-Host "Nothing to commit." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan