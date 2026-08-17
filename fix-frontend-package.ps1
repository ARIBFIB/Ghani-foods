# fix-frontend-package.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\fix-frontend-package.ps1

$ErrorActionPreference = "Stop"
$Root = Get-Location
$frontendDir = Join-Path $Root "apps\frontend"
$pkgPath = Join-Path $frontendDir "package.json"

Write-Host "=== Fixing apps/frontend/package.json ===" -ForegroundColor Cyan

if (-not (Test-Path $frontendDir)) {
    Write-Host "ERROR: apps\frontend not found. Run this from the GhaniFoods root folder." -ForegroundColor Red
    exit 1
}

# New correct package.json content (Next.js + React + all existing deps)
$newPkg = @'
{
  "name": "ghanifoods-frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build --turbopack",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.4.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "@ant-design/icons": "^6.3.2",
    "@ant-design/nextjs-registry": "^1.3.0",
    "@hookform/resolvers": "^5.9.1",
    "@tanstack/react-query": "^5.101.4",
    "@tanstack/react-table": "^9.1.2",
    "antd": "^6.6.1",
    "dayjs": "^1.11.23",
    "react-hook-form": "^7.85.0",
    "recharts": "^3.10.1",
    "zod": "^4.4.3"
  },
  "devDependencies": {
    "typescript": "^5.6.3",
    "@types/node": "^22.7.5",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "eslint": "^9.15.0",
    "eslint-config-next": "^15.4.0"
  }
}
'@

# Write file as UTF-8 WITHOUT BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pkgPath, $newPkg, $utf8NoBom)
Write-Host "  package.json rewritten (UTF-8, no BOM)." -ForegroundColor Green

# Remove stale node_modules / lockfile inside apps/frontend so install is clean
$frontendNodeModules = Join-Path $frontendDir "node_modules"
$frontendLock = Join-Path $frontendDir "package-lock.json"

if (Test-Path $frontendNodeModules) {
    Write-Host "  Removing apps\frontend\node_modules ..." -ForegroundColor Yellow
    Remove-Item -Path $frontendNodeModules -Recurse -Force
}
if (Test-Path $frontendLock) {
    Write-Host "  Removing apps\frontend\package-lock.json ..." -ForegroundColor Yellow
    Remove-Item -Path $frontendLock -Force
}

# Reinstall dependencies for the frontend workspace
Write-Host "`n=== Installing frontend dependencies ===" -ForegroundColor Cyan
Push-Location $frontendDir
npm install
Pop-Location



Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Test locally:  cd apps\frontend && npm run build" -ForegroundColor Gray
Write-Host "  2. If build succeeds, commit and push:" -ForegroundColor Gray
Write-Host "       git add apps/frontend/package.json apps/frontend/package-lock.json" -ForegroundColor Gray
Write-Host "       git commit -m `"fix: add missing next/react deps, remove BOM from package.json`"" -ForegroundColor Gray
Write-Host "       git push" -ForegroundColor Gray