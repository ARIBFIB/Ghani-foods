# fix-login-navigation.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\fix-login-navigation.ps1
#
# Fixes build error: "useNavigationLoading must be used within NavigationLoadingProvider"
# Root cause: app/(auth)/login/page.tsx uses useNavigationLoading, but that
# provider only wraps app/(dashboard)/layout.tsx - the (auth) route group
# never gets wrapped in it. Fix: login page uses plain router.push instead.

$ErrorActionPreference = "Stop"

$loginPagePath = Join-Path (Get-Location) "apps\frontend\app\(auth)\login\page.tsx"

if (-not (Test-Path $loginPagePath)) {
    Write-Host "ERROR: Could not find $loginPagePath" -ForegroundColor Red
    Write-Host "Make sure you're running this from the GhaniFoods root folder." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Fixing login page navigation ===" -ForegroundColor Cyan

$content = Get-Content -Path $loginPagePath -Raw -Encoding UTF8

$originalContent = $content

# 1. Remove the useNavigationLoading import
$content = $content -replace 'import\s*\{\s*useNavigationLoading\s*\}\s*from\s*"@/lib/navigation-loading-context";\r?\n', ''

# 2. Remove the `const { navigate } = useNavigationLoading();` line
$content = $content -replace '\s*const\s*\{\s*navigate\s*\}\s*=\s*useNavigationLoading\(\);\r?\n', "`n"

# 3. Replace navigate("/") call with router.push("/")
$content = $content -replace 'navigate\("/"\);', 'router.push("/");'

if ($content -eq $originalContent) {
    Write-Host "No changes were made - file may already be fixed, or patterns didn't match." -ForegroundColor Yellow
} else {
    # Write back without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($loginPagePath, $content, $utf8NoBom)
    Write-Host "Patched: $loginPagePath" -ForegroundColor Green
}

Write-Host "`n=== Verifying ===" -ForegroundColor Cyan
$check = Get-Content -Path $loginPagePath -Raw -Encoding UTF8
if ($check -match 'useNavigationLoading') {
    Write-Host "WARNING: 'useNavigationLoading' still found in file - please check manually." -ForegroundColor Red
} else {
    Write-Host "OK: No more useNavigationLoading references in login page." -ForegroundColor Green
}
if ($check -match 'router\.push\("/"\)') {
    Write-Host "OK: router.push(`"/`") is now used for redirect after login." -ForegroundColor Green
} else {
    Write-Host "WARNING: router.push(`"/`") not found - please check the file manually." -ForegroundColor Red
}

Write-Host "`nDone. Now run:" -ForegroundColor Cyan
Write-Host "  npm run build:frontend" -ForegroundColor White
Write-Host "or push to trigger a new Vercel deploy." -ForegroundColor White