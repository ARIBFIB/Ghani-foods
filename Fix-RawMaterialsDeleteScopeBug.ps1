<#
  Fix-RawMaterialsDeleteScopeBug.ps1
  -----------------------------------------------------------------------
  VERCEL BUILD ERROR:
    ./app/(dashboard)/raw-materials/page.tsx:136:13
    Type error: Cannot find name 'deleteRawMaterial'.

  ROOT CAUSE:
  This file has two separate components:
    - AddRawMaterialMasterDialog (line ~26) - pulls deleteRawMaterial
      from the store, but never actually calls it.
    - RawMaterialsPage (line ~100, the default export) - USES
      deleteRawMaterial at line 136 in its delete handler, but never
      declares it in its own scope. Each component has its own local
      variables - one component pulling a value from useStore does not
      make it visible inside a different, unrelated component.

  FIX:
  Add the same line RawMaterialsPage's sibling hooks already use
  (rawMaterials, receipts, receiptLines, suppliers, loadRawMaterialsModule)
  so deleteRawMaterial is pulled from the store inside RawMaterialsPage
  itself, right where it's actually used.

  USAGE
    cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
    .\Fix-RawMaterialsDeleteScopeBug.ps1

  Idempotent - safe to re-run.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    WARNING: $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "    FAILED: $msg" -ForegroundColor Red }

# -------------------------------------------------------------------------
# 0. Locate project root
# -------------------------------------------------------------------------
Write-Step "Locating project..."

$candidatePaths = @($ProjectRoot, "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods")
$resolvedRoot = $null
foreach ($p in $candidatePaths) {
    if (Test-Path (Join-Path $p "apps\frontend\lib\store.ts")) { $resolvedRoot = $p; break }
}
if (-not $resolvedRoot) {
    Write-Warn2 "Could not auto-detect the project. Run this script FROM the project root."
    throw "Project root not found."
}
$ProjectRoot = $resolvedRoot
$PageFile = Join-Path $ProjectRoot "apps\frontend\app\(dashboard)\raw-materials\page.tsx"

Write-Ok "Project root: $ProjectRoot"

# -------------------------------------------------------------------------
# 1. Fix the scope bug
# -------------------------------------------------------------------------
Write-Step "Fixing deleteRawMaterial scope bug in raw-materials/page.tsx..."

if (-not (Test-Path -LiteralPath $PageFile)) {
    Write-Fail "Could not find $PageFile"
    throw "File not found."
}

$content = Get-Content -LiteralPath $PageFile -Raw

# Anchor on a line we know is inside RawMaterialsPage (not the dialog
# component above it), so we add the missing hook call in the right scope.
$anchor    = 'const loadRawMaterialsModule = useStore((s) => s.loadRawMaterialsModule);'
$anchorIdx = $content.IndexOf($anchor)
# There are two occurrences of a line assigning loadRawMaterialsModule
# (one per component per the bug report) - we want the SECOND one,
# which lives inside RawMaterialsPage.
$secondAnchorIdx = $content.IndexOf($anchor, $anchorIdx + 1)

$deleteOccurrences = [regex]::Matches($content, [regex]::Escape('const deleteRawMaterial = useStore((s) => s.deleteRawMaterial);')).Count

if ($deleteOccurrences -ge 2) {
    Write-Ok "deleteRawMaterial already declared in both components - no change needed."
}
elseif ($secondAnchorIdx -lt 0) {
    Write-Fail "Could not find the expected second occurrence of the loadRawMaterialsModule line to anchor on - the file may have changed since the code export. Open it manually and add:"
    Write-Warn2 "  const deleteRawMaterial = useStore((s) => s.deleteRawMaterial);"
    Write-Warn2 "inside RawMaterialsPage (the default-exported component), alongside its other useStore(...) calls."
}
else {
    $insertion = $anchor + "`r`n  const deleteRawMaterial = useStore((s) => s.deleteRawMaterial);"
    $content = $content.Remove($secondAnchorIdx, $anchor.Length).Insert($secondAnchorIdx, $insertion)
    Set-Content -LiteralPath $PageFile -Value $content -Encoding UTF8 -NoNewline
    Write-Ok "Added 'const deleteRawMaterial = useStore((s) => s.deleteRawMaterial);' inside RawMaterialsPage."
}

# -------------------------------------------------------------------------
# 2. Local build check (catches this class of error before you push again)
# -------------------------------------------------------------------------
Write-Step "Running a local type-check so you don't find out from Vercel again..."

$FrontendDir = Join-Path $ProjectRoot "apps\frontend"
if (Test-Path $FrontendDir) {
    Push-Location $FrontendDir
    try {
        Write-Host "    Running: npx tsc --noEmit" -ForegroundColor Gray
        $tscOutput = cmd.exe /c "npx tsc --noEmit 2>&1"
        $tscOutput = $tscOutput | Out-String
        Write-Host $tscOutput
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "TypeScript still reports errors (shown above) - fix these before pushing/redeploying."
        }
        else {
            Write-Ok "No TypeScript errors found."
        }
    }
    catch {
        Write-Warn2 "Could not run tsc locally: $($_.Exception.Message). Push and let Vercel re-check instead."
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Warn2 "Could not find apps/frontend - skipping local type-check."
}

Write-Step "Done. Commit and push this change, then re-deploy on Vercel."