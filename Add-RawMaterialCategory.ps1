<#
  Add-RawMaterialCategory.ps1
  -----------------------------------------------------------------------
  ISSUE 7: No category system for raw materials.

  This version reads all the actual code text (anchors/replacements/SQL/
  TS content) from edits.json sitting next to this script, and only uses
  plain ASCII for its own PowerShell logic. This avoids the quoting/
  encoding problems that broke the previous inline version.

  IMPORTANT NOTE ON THE "MIXED DROPDOWN" SYMPTOM:
  The "Underlying Raw Material" (packaging/page.tsx), "Raw Material
  Consumption" (batches/new/page.tsx) and PO line item (purchase-order-
  dialog.tsx) pickers already pull strictly from the rawMaterials store
  array, which is loaded only from the raw_materials table - packaging
  items (wrappers/boxes) live in separate tables and are never queried
  there. So at the CODE level these dropdowns cannot show packaging rows.
  If "Box Paper" / "carton big" / "Wrapper PAPER" are showing up in that
  list, those specific rows were created THROUGH the Add Raw Material
  form and saved into the raw_materials table by mistake (a data-entry
  issue, not a filtering bug). This script still fixes the request in
  full:
    - adds category so those rows can be labelled/grouped (making
      misfiled packaging items obvious and fixable),
    - and makes every raw-material option label show the category, so
      it is now visually obvious in the dropdown if something does not
      belong there.
  Once this is applied, open the Raw Materials list, use the new
  Category filter, and manually re-categorize or delete anything that
  was filed there by mistake (e.g. "Box Paper") - that part is a data
  cleanup step this script can't safely automate for you.

  USAGE:
    cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
    .\Add-RawMaterialCategory.ps1

  Requires edits.json to be in the SAME FOLDER as this script.
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

function ConvertTo-LF([string]$text) { return $text -replace "`r`n", "`n" }
function ConvertTo-CRLF([string]$text) { return $text -replace "`n", "`r`n" }

function Apply-Edit {
    param([string]$content, [string]$anchor, [string]$replacement, [string]$description)
    $anchorLF = ConvertTo-LF $anchor
    $replacementLF = ConvertTo-LF $replacement
    if ($content.Contains($replacementLF)) {
        Write-Ok "$description - already applied, skipping."
        return @($content, $false)
    }
    $idx = $content.IndexOf($anchorLF)
    if ($idx -lt 0) {
        Write-Warn2 "$description - anchor not found. Paste this file and I will give the exact edit."
        return @($content, $false)
    }
    $newContent = $content.Substring(0, $idx) + $replacementLF + $content.Substring($idx + $anchorLF.Length)
    Write-Ok "$description - wired."
    return @($newContent, $true)
}

function Edit-FileWithSteps {
    param([string]$Path, [array]$Steps)
    if (-not (Test-Path $Path)) { Write-Warn2 "$Path not found - skipping."; return }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    $usesCRLF = $raw -match "`r`n"
    $content = ConvertTo-LF $raw
    $anyChange = $false
    foreach ($step in $Steps) {
        $result = Apply-Edit -content $content -anchor $step.anchor -replacement $step.replacement -description $step.description
        $content = $result[0]
        if ($result[1]) { $anyChange = $true }
    }
    if ($anyChange) {
        $final = if ($usesCRLF) { ConvertTo-CRLF $content } else { $content }
        Set-Content -Path $Path -Value $final -Encoding UTF8 -NoNewline
        Write-Ok "Saved: $Path"
    }
    else {
        Write-Ok "No changes needed for: $Path"
    }
}

# -------------------------------------------------------------------------
# 0. Locate project root and edits.json
# -------------------------------------------------------------------------
Write-Step "Locating project..."

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EditsJsonPath = Join-Path $ScriptDir "edits.json"
if (-not (Test-Path $EditsJsonPath)) {
    throw "edits.json not found next to the script at: $EditsJsonPath . Make sure both files are in the same folder."
}
$Edits = Get-Content -Path $EditsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

$candidatePaths = @($ProjectRoot, "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods")
$resolvedRoot = $null
foreach ($p in $candidatePaths) {
    if (Test-Path (Join-Path $p "apps\frontend\lib\store.ts")) { $resolvedRoot = $p; break }
}
if (-not $resolvedRoot) {
    Write-Warn2 "Could not auto-detect the project. Run this script FROM the project root."
    throw "Project root not found."
}
$ProjectRoot   = $resolvedRoot
$BackendDir    = Join-Path $ProjectRoot "apps\backend"
$MigrationsDir = Join-Path $BackendDir "supabase\migrations"
$FrontendDir   = Join-Path $ProjectRoot "apps\frontend"

$StorePath            = Join-Path $FrontendDir "lib\store.ts"
$SchemasPath          = Join-Path $FrontendDir "lib\schemas.ts"
$CategoriesConstPath  = Join-Path $FrontendDir "lib\constants\raw-material-categories.ts"
$RawMaterialsPagePath = Join-Path $FrontendDir "app\(dashboard)\raw-materials\page.tsx"
$PackagingPagePath    = Join-Path $FrontendDir "app\(dashboard)\packaging\page.tsx"
$BatchesNewPagePath   = Join-Path $FrontendDir "app\(dashboard)\batches\new\page.tsx"
$PODialogPath         = Join-Path $FrontendDir "components\ui\purchase-order-dialog.tsx"

Write-Ok "Project root: $ProjectRoot"

# -------------------------------------------------------------------------
# 1. SQL migration
# -------------------------------------------------------------------------
Write-Step "Checking SQL migration (category columns)..."

if (-not (Test-Path $MigrationsDir)) { New-Item -ItemType Directory -Force -Path $MigrationsDir | Out-Null }

$existingMigration = Get-ChildItem -Path $MigrationsDir -Filter "*_add_category_to_materials.sql" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existingMigration) {
    Write-Ok "Migration already exists: $($existingMigration.FullName) - skipping."
    $migrationFile = $existingMigration.FullName
    $migrationIsNew = $false
}
else {
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $migrationFile = Join-Path $MigrationsDir "${timestamp}_add_category_to_materials.sql"
    Set-Content -Path $migrationFile -Value $Edits.migrationSql -Encoding UTF8
    Write-Ok "Migration written: $migrationFile"
    $migrationIsNew = $true
}

# -------------------------------------------------------------------------
# 2. Category suggestions constant
# -------------------------------------------------------------------------
Write-Step "Creating category suggestions constant..."

$constDir = Split-Path $CategoriesConstPath -Parent
if (-not (Test-Path $constDir)) { New-Item -ItemType Directory -Force -Path $constDir | Out-Null }

if (Test-Path $CategoriesConstPath) {
    Write-Ok "raw-material-categories.ts already exists - leaving it as-is."
}
else {
    Set-Content -Path $CategoriesConstPath -Value $Edits.categoriesTs -Encoding UTF8
    Write-Ok "Created: $CategoriesConstPath"
}

# -------------------------------------------------------------------------
# 3. lib/schemas.ts
# -------------------------------------------------------------------------
Write-Step "Updating lib/schemas.ts..."
Edit-FileWithSteps -Path $SchemasPath -Steps $Edits.schemasSteps

# -------------------------------------------------------------------------
# 4. lib/store.ts
# -------------------------------------------------------------------------
Write-Step "Updating lib/store.ts..."
Edit-FileWithSteps -Path $StorePath -Steps $Edits.storeSteps

# -------------------------------------------------------------------------
# 5. raw-materials/page.tsx
# -------------------------------------------------------------------------
Write-Step "Updating raw-materials/page.tsx..."
Edit-FileWithSteps -Path $RawMaterialsPagePath -Steps $Edits.rawMaterialsPageSteps

# -------------------------------------------------------------------------
# 6. Picker labels: show category
# -------------------------------------------------------------------------
Write-Step "Updating picker option labels to include category..."
Edit-FileWithSteps -Path $PackagingPagePath -Steps $Edits.packagingSteps
Edit-FileWithSteps -Path $BatchesNewPagePath -Steps $Edits.batchesNewSteps
Edit-FileWithSteps -Path $PODialogPath -Steps $Edits.poDialogSteps

# -------------------------------------------------------------------------
# 7. Apply the SQL migration
# -------------------------------------------------------------------------
Write-Step "Applying migration..."

if (-not $migrationIsNew) {
    Write-Ok "Migration already existed - skipping push. If you haven't pushed it yet, run supabase db push manually."
}
else {
    $supabaseCli = Get-Command supabase -ErrorAction SilentlyContinue
    if ($supabaseCli) {
        Push-Location $BackendDir
        try {
            Write-Host "    Running: supabase db push" -ForegroundColor DarkGray
            supabase db push
            if ($LASTEXITCODE -ne 0) { throw "supabase db push failed with exit code $LASTEXITCODE" }
            Write-Ok "Migration pushed to linked Supabase project."
        }
        catch {
            Write-Warn2 "Automatic push failed: $($_.Exception.Message)"
            Write-Warn2 "Open the SQL file below in Supabase Studio -> SQL Editor and run it manually:"
            Write-Warn2 "SQL file: $migrationFile"
        }
        finally { Pop-Location }
    }
    else {
        Write-Warn2 "Supabase CLI not found in PATH."
        Write-Warn2 "MANUAL STEP: open your Supabase project -> SQL Editor, paste and run: $migrationFile"
    }
}

Write-Step "Done."
Write-Host "Test karo:" -ForegroundColor Magenta
Write-Host "  1. Raw Materials -> + Add Raw Material -> Category field dikhna chahiye (free text, suggestions ke sath)." -ForegroundColor Magenta
Write-Host "  2. Raw Materials list -> Category column + All categories filter dropdown dikhna chahiye." -ForegroundColor Magenta
Write-Host "  3. Define Wrapper/Box, New Batch, New Purchase Order -> raw material option labels ab category dikhayenge, e.g. Atta - Flour (kg)." -ForegroundColor Magenta
Write-Host "  4. Un dropdowns mein category naam type karke bhi filter hona chahiye (SearchableSelect label match karta hai)." -ForegroundColor Magenta
Write-Host "" -ForegroundColor Magenta
Write-Host "MANUAL STEP (data cleanup, script isay automate nahi kar sakti):" -ForegroundColor Magenta
Write-Host "  Raw Materials list mein jo bhi galti se packaging items (Box Paper, carton big, Wrapper PAPER) waha bane hain," -ForegroundColor Magenta
Write-Host "  unko category Packaging assign kar do taake list mein pehchane jaa saken, ya unhe delete kar ke sahi jagah (Packaging module) dobara add karo." -ForegroundColor Magenta
Write-Host "" -ForegroundColor Magenta
Write-Host "Agar koi WARNING anchor not found dikhaye, wo file paste kar dena - exact edit de dunga." -ForegroundColor Magenta