<#
  add-vercel-analytics.ps1
  Purpose: Add @vercel/analytics package + <Analytics /> component to
           apps/frontend/app/layout.tsx for GhaniFoods project.

  Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>
#>

function Write-FileUtf8NoBom {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host '  -> Wrote' $Path -ForegroundColor Green
}

$root = (Get-Location).Path
Write-Host 'Repo root:' $root -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# STEP 1: Install @vercel/analytics in apps/frontend
# ---------------------------------------------------------------------------
$frontendPath = Join-Path $root 'apps\frontend'

if (-not (Test-Path $frontendPath)) {
    Write-Host 'ERROR: apps\frontend not found at' $frontendPath -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '[1/2] Installing @vercel/analytics...' -ForegroundColor Yellow
Push-Location $frontendPath
try {
    npm i '@vercel/analytics'
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'ERROR: npm install failed.' -ForegroundColor Red
        Pop-Location
        exit 1
    }
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# STEP 2: Patch apps/frontend/app/layout.tsx
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[2/2] Patching layout.tsx...' -ForegroundColor Yellow

$layoutPath = Join-Path $frontendPath 'app\layout.tsx'

if (-not (Test-Path $layoutPath)) {
    Write-Host 'ERROR: layout.tsx not found at' $layoutPath -ForegroundColor Red
    exit 1
}

$content = Get-Content -Path $layoutPath -Raw -Encoding UTF8

if ($content.Contains('@vercel/analytics')) {
    Write-Host '  layout.tsx already contains @vercel/analytics -- skipping patch.' -ForegroundColor DarkYellow
}
else {
    # Anchors defined as here-strings so quote characters never need escaping.
    $importAnchor = @'
import { NetworkStatus } from "@/components/ui/network-status";
'@
    $importAnchor = $importAnchor.TrimEnd("`r","`n")

    $importReplacement = @'
import { NetworkStatus } from "@/components/ui/network-status";
import { Analytics } from "@vercel/analytics/next";
'@
    $importReplacement = $importReplacement.TrimEnd("`r","`n")

    if (-not $content.Contains($importAnchor)) {
        Write-Host 'ERROR: Could not find NetworkStatus import anchor in layout.tsx. No changes made.' -ForegroundColor Red
        exit 1
    }
    $content = $content.Replace($importAnchor, $importReplacement)

    $bodyAnchorOpen  = [char]60 + 'NetworkStatus /' + [char]62
    $bodyReplacement = $bodyAnchorOpen + "`r`n        " + [char]60 + 'Analytics /' + [char]62

    if (-not $content.Contains($bodyAnchorOpen)) {
        Write-Host 'ERROR: Could not find NetworkStatus tag anchor in layout.tsx. No changes made.' -ForegroundColor Red
        exit 1
    }
    $content = $content.Replace($bodyAnchorOpen, $bodyReplacement)

    Write-FileUtf8NoBom -Path $layoutPath -Content $content
}

Write-Host ''
Write-Host 'Done. Summary:' -ForegroundColor Cyan
Write-Host '  - @vercel/analytics installed in apps/frontend'
Write-Host '  - Analytics component added to apps/frontend/app/layout.tsx'
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host '  git add .'
Write-Host '  git commit -m "feat: add vercel web analytics"'
Write-Host '  git push origin main'