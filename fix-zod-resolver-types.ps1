# fix-zod-resolver-types.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-zod-resolver-types.ps1
#
# Fixes the build error:
#   Type error: Type 'Resolver<{ electricity: unknown; gas: unknown;
#   rent: unknown; }, any, ...>' is not assignable to type
#   'Resolver<{ electricity: number; gas: number; rent: number; }, ...>'.
#     Type 'unknown' is not assignable to type 'number'.
#
# Root cause: package.json has "zod": "^4.4.3". In Zod v4, schemas built
# with z.coerce.number() (and similar coercions) have an "input" type of
# `unknown` and an "output" type of `number`. @hookform/resolvers'
# zodResolver() infers the form's input type from the schema, but
# useForm<FormValues>() in this project only declares a single (output)
# type. That mismatch (unknown vs number) is exactly what TypeScript is
# rejecting here - and it affects EVERY form in this project that uses
# z.coerce.number()/z.coerce (overheadSchema, batchSchema, purchaseSchema,
# restockSchema, customerSchema, paymentSchema, invoiceHeaderSchema,
# rawMaterialSchema, packagingMaterialSchema, and the inline settings
# schema in app/(dashboard)/settings/page.tsx).
#
# Rather than rewriting every useForm<...> call with separate input/output
# generics, this script pins "zod" back to the widely-used v3.23.x line,
# where z.coerce schemas do not have this split-generic behavior and
# @hookform/resolvers' zodResolver() works with a single generic exactly
# the way this project's forms are written.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"
$pkgPath = Join-Path $FrontendRoot "package.json"

if (-not (Test-Path $pkgPath)) {
    Write-Host "ERROR: $pkgPath not found." -ForegroundColor Red
    Write-Host "Make sure you're running this from the GhaniFoods root folder." -ForegroundColor Red
    exit 1
}

Write-Host "=== Fixing Zod v4 / @hookform/resolvers type mismatch ===" -ForegroundColor Cyan

$text = [System.IO.File]::ReadAllText($pkgPath, [System.Text.Encoding]::UTF8)
$pkgJson = $text | ConvertFrom-Json

$targetZodVersion = "^3.23.8"
$currentZod = $pkgJson.dependencies."zod"

if ($null -eq $currentZod) {
    Write-Host "  'zod' not found in dependencies - adding it at $targetZodVersion" -ForegroundColor Yellow
    $pkgJson.dependencies | Add-Member -MemberType NoteProperty -Name "zod" -Value $targetZodVersion
} else {
    Write-Host "  Current: zod $currentZod" -ForegroundColor Gray
    $pkgJson.dependencies."zod" = $targetZodVersion
    Write-Host "  Pinned:  zod $targetZodVersion (v3 - avoids the coerce input/output generic split)" -ForegroundColor Green
}

# Write back as clean UTF-8 WITHOUT BOM
$outText = $pkgJson | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pkgPath, $outText, $utf8NoBom)

Write-Host "  Updated: apps\frontend\package.json" -ForegroundColor Green

# --------------------------------------------------------------------------
# Reinstall so the lockfile / node_modules actually reflect zod v3
# --------------------------------------------------------------------------

Write-Host ""
Write-Host "=== Reinstalling dependencies ===" -ForegroundColor Cyan
Push-Location $FrontendRoot
try {
    npm install
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Verifying local build ===" -ForegroundColor Cyan
Push-Location $FrontendRoot
$buildFailed = $false
try {
    npm run build
    if ($LASTEXITCODE -ne 0) { $buildFailed = $true }
} catch {
    $buildFailed = $true
} finally {
    Pop-Location
}

Write-Host ""
if ($buildFailed) {
    Write-Host "Local build FAILED - do not push yet. Check the errors above." -ForegroundColor Red
    Write-Host "If a NEW/different error shows up now, share that build log and we'll fix the next one." -ForegroundColor Yellow
} else {
    Write-Host "Local build succeeded." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  git add -A" -ForegroundColor Gray
    Write-Host "  git commit -m `"fix: pin zod to v3 to resolve @hookform/resolvers type mismatch`"" -ForegroundColor Gray
    Write-Host "  git push origin main" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Vercel will auto-redeploy on push." -ForegroundColor Gray
}