# fix-navlink-outside-provider.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\fix-navlink-outside-provider.ps1
#
# The previous script swapped Link -> NavLink everywhere under app/ and
# components/, but NavLink depends on NavigationLoadingProvider, which is
# only mounted inside app/(dashboard)/layout.tsx. Files outside that route
# group (not-found.tsx, the (auth)/login page, root layout, etc.) must keep
# using plain next/link. This script reverts NavLink back to Link in those
# specific out-of-provider files.

$ProjectRoot = Get-Location
$FrontendRoot = Join-Path $ProjectRoot "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: Could not find apps\frontend under $(Get-Location)" -ForegroundColor Red
    exit 1
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom($Path, $Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Read-FileSmart($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -eq 0) { return "" }
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
    $text = $reader.ReadToEnd()
    $reader.Close()
    return ($text -replace "`0", "")
}

# Files/paths that live OUTSIDE app/(dashboard) and must NOT use NavLink,
# since NavigationLoadingProvider only wraps the (dashboard) route group.
$outsideProviderFiles = @(
    (Join-Path $FrontendRoot "app\not-found.tsx"),
    (Join-Path $FrontendRoot "app\error.tsx"),
    (Join-Path $FrontendRoot "app\global-error.tsx"),
    (Join-Path $FrontendRoot "app\layout.tsx")
)

# Also revert every page/component under app\(auth)\ if it exists
$authDir = Join-Path $FrontendRoot "app\(auth)"
if (Test-Path $authDir) {
    $outsideProviderFiles += (Get-ChildItem -Path $authDir -Recurse -Filter "*.tsx" -File | Select-Object -ExpandProperty FullName)
}

$revertedCount = 0

foreach ($path in ($outsideProviderFiles | Sort-Object -Unique)) {
    if (-not (Test-Path $path)) { continue }

    $original = Read-FileSmart $path
    $content = $original

    if ($content -match 'NavLink') {
        # Revert the import
        $content = [regex]::Replace(
            $content,
            'import\s+\{\s*NavLink\s*\}\s+from\s+["'']@/components/ui/nav-link["''];?',
            'import Link from "next/link";'
        )
        # Revert JSX usage
        $content = [regex]::Replace($content, '<NavLink\b', '<Link')
        $content = [regex]::Replace($content, '</NavLink>', '</Link>')

        if ($content -ne $original) {
            Write-Utf8NoBom $path $content
            $revertedCount++
            $rel = $path.Substring($FrontendRoot.Length).TrimStart('\')
            Write-Host "  Reverted to Link: $rel" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Files reverted: $revertedCount" -ForegroundColor Green
Write-Host "Please review with 'git diff', then commit and redeploy to Vercel." -ForegroundColor Yellow