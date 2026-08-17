# fix-tailwind-issue.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#   cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
#   .\fix-tailwind-issue.ps1

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendDir = Join-Path $Root "apps\frontend"
$AppDir      = Join-Path $FrontendDir "app"

$RootLayout   = Join-Path $AppDir "layout.tsx"
$GlobalsCss   = Join-Path $AppDir "globals.css"
$PostcssCfg   = Join-Path $FrontendDir "postcss.config.mjs"
$PackageJson  = Join-Path $FrontendDir "package.json"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Backup-IfExists($path) {
    if (Test-Path $path) {
        $backup = "$path.bak"
        Copy-Item $path $backup -Force
        Write-Host "  Backed up existing file -> $backup" -ForegroundColor DarkGray
    }
}

Write-Host "=== Fixing Tailwind CSS / Root Layout issue ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------
# 1. Ensure root app/layout.tsx exists (Next.js requires this)
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "[1/4] Checking root app/layout.tsx..." -ForegroundColor Yellow

if (-not (Test-Path $RootLayout)) {
    $layoutContent = @'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "GhaniFoods",
  description: "Nimko / Snack Foods Production & Distribution System",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
'@
    [System.IO.File]::WriteAllText($RootLayout, $layoutContent, $utf8NoBom)
    Write-Host "  Created missing app/layout.tsx (imports globals.css)." -ForegroundColor Green
} else {
    $existing = Get-Content $RootLayout -Raw
    if ($existing -notmatch 'globals\.css') {
        Backup-IfExists $RootLayout
        $newContent = 'import "./globals.css";' + "`r`n" + $existing
        [System.IO.File]::WriteAllText($RootLayout, $newContent, $utf8NoBom)
        Write-Host "  layout.tsx existed but did not import globals.css - import added." -ForegroundColor Green
    } else {
        Write-Host "  app/layout.tsx already exists and imports globals.css. Skipping." -ForegroundColor Gray
    }
}

# ---------------------------------------------------------------------
# 2. Fix globals.css for Tailwind v4 (CSS-first, no tailwind.config.js needed)
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "[2/4] Fixing app/globals.css for Tailwind v4..." -ForegroundColor Yellow

$needsFix = $true
if (Test-Path $GlobalsCss) {
    $cssContent = Get-Content $GlobalsCss -Raw
    if ($cssContent -match '@import\s+"tailwindcss"') {
        Write-Host "  globals.css already uses Tailwind v4 '@import tailwindcss'. Skipping overwrite." -ForegroundColor Gray
        $needsFix = $false
    } else {
        Backup-IfExists $GlobalsCss
    }
}

if ($needsFix) {
    $cssNew = @'
@import "tailwindcss";

:root {
  --background: #ffffff;
  --foreground: #171717;
}

body {
  background: var(--background);
  color: var(--foreground);
  font-family: Arial, Helvetica, sans-serif;
}
'@
    [System.IO.File]::WriteAllText($GlobalsCss, $cssNew, $utf8NoBom)
    Write-Host "  globals.css rewritten with Tailwind v4 CSS-first import." -ForegroundColor Green
}

# ---------------------------------------------------------------------
# 3. Ensure postcss.config.mjs exists (required for Tailwind v4)
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "[3/4] Checking postcss.config.mjs..." -ForegroundColor Yellow

if (-not (Test-Path $PostcssCfg)) {
    $postcssContent = @'
const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;
'@
    [System.IO.File]::WriteAllText($PostcssCfg, $postcssContent, $utf8NoBom)
    Write-Host "  Created postcss.config.mjs with @tailwindcss/postcss plugin." -ForegroundColor Green
} else {
    Write-Host "  postcss.config.mjs already exists. Skipping." -ForegroundColor Gray
}

# ---------------------------------------------------------------------
# 4. Ensure correct Tailwind v4 packages are installed
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Checking Tailwind v4 dependencies in package.json..." -ForegroundColor Yellow

Push-Location $FrontendDir

$pkgRaw = Get-Content $PackageJson -Raw | ConvertFrom-Json
$hasTailwind      = $false
$hasTailwindPostcss = $false

foreach ($depSet in @("dependencies", "devDependencies")) {
    if ($pkgRaw.$depSet) {
        if ($pkgRaw.$depSet.PSObject.Properties.Name -contains "tailwindcss") { $hasTailwind = $true }
        if ($pkgRaw.$depSet.PSObject.Properties.Name -contains "@tailwindcss/postcss") { $hasTailwindPostcss = $true }
    }
}

if (-not $hasTailwind -or -not $hasTailwindPostcss) {
    Write-Host "  Installing missing Tailwind v4 packages (tailwindcss, @tailwindcss/postcss)..." -ForegroundColor Yellow
    npm install tailwindcss@latest @tailwindcss/postcss@latest --save
} else {
    Write-Host "  tailwindcss and @tailwindcss/postcss already present." -ForegroundColor Gray
}

# ---------------------------------------------------------------------
# 5. Local build test
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "Running local build to confirm fixes..." -ForegroundColor Yellow
npm run build
$buildExitCode = $LASTEXITCODE
Pop-Location

if ($buildExitCode -ne 0) {
    Write-Host ""
    Write-Host "Build STILL failing (exit code $buildExitCode). See errors above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Build SUCCEEDED locally!" -ForegroundColor Green

# ---------------------------------------------------------------------
# 6. Commit and push
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "Committing and pushing..." -ForegroundColor Yellow
$statusOutput = git status --porcelain
if ($statusOutput) {
    git add $RootLayout
    git add $GlobalsCss
    git add $PostcssCfg
    git add $PackageJson
    $lockFile = Join-Path $FrontendDir "package-lock.json"
    if (Test-Path $lockFile) { git add $lockFile }
    git commit -m "fix: add root layout, Tailwind v4 CSS-first config, postcss config"
    git push origin main
    Write-Host "Pushed to origin/main. Vercel will redeploy automatically." -ForegroundColor Green
} else {
    Write-Host "Nothing to commit." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan