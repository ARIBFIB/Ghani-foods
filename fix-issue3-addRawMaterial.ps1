<#
  fix-issue3-addRawMaterial.ps1

  Kya karta hai:
  - apps/frontend/lib/store.ts mein addRawMaterial function ko find karta hai
  - Direct table insert (jo duplicate-name check bypass karta tha) ko
    hata kar raw-materials-create edge function ke through route karta hai
  - Original file ki backup (.bak) banata hai
  - Result / log ek .txt file mein likhta hai (results\fix-issue3-log.txt)

  Run karne ka tareeqa:
  1. Is script ko project root mein rakhein (ya path neeche adjust kar dein)
  2. PowerShell open karein us folder mein jahan ye script hai
  3. Run karein:  .\fix-issue3-addRawMaterial.ps1

  Agar project root script ke folder se alag hai to neeche $ProjectRoot
  variable manually set kar dein.
#>

# ---- Config ----
# Default: is script ke folder ko hi project root maan lo.
# Agar zaroorat ho to yahan hardcode kar dein, e.g.:
# $ProjectRoot = "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
$ProjectRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Get-Location).Path
}

$TargetFile = Join-Path $ProjectRoot "apps\frontend\lib\store.ts"
$ResultsDir = Join-Path $ProjectRoot "results"
$LogFile    = Join-Path $ResultsDir "fix-issue3-log.txt"

$LogLines = New-Object System.Collections.Generic.List[string]
function Log($msg) {
    Write-Host $msg
    $LogLines.Add($msg)
}

Log "===== fix-issue3-addRawMaterial.ps1 ====="
Log "Run time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log "Project root: $ProjectRoot"
Log "Target file:  $TargetFile"
Log ""

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    Log "FAIL: Project root nahi mila: $ProjectRoot"
    Log "Script ke top mein `$ProjectRoot ko sahi path pe set karein."
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
    $LogLines | Set-Content -LiteralPath $LogFile -Encoding UTF8
    exit 1
}

if (-not (Test-Path -LiteralPath $TargetFile)) {
    Log "FAIL: store.ts nahi mili: $TargetFile"
    Log "Confirm karein ke `$ProjectRoot sahi GhaniFoods root hai."
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
    $LogLines | Set-Content -LiteralPath $LogFile -Encoding UTF8
    exit 1
}

$content = Get-Content -LiteralPath $TargetFile -Raw -Encoding UTF8

# ---- Old block (jo dhoondna/replace karna hai) ----
$oldBlock = @'
  addRawMaterial: async (item) => {
    const { data, error } = await supabase
      .from("raw_materials")
      .insert({ name: item.name, unit: item.unit, low_stock_threshold: item.lowStockThreshold, category: item.category?.trim() || null })
      .select()
      .single();
    if (error || !data) throw new Error(error?.message ?? "Failed to add raw material");
    const material = mapRawMaterialRow(data);
    set((s) => ({ rawMaterials: [...s.rawMaterials, material] }));
    return material.id;
  },
'@

# ---- New block ----
$newBlock = @'
  addRawMaterial: async (item) => {
    // Routed through the raw-materials-create edge function (not a direct
    // table insert) so the server-side case-insensitive duplicate-name
    // check (e.g. "Atta" vs "atta") actually runs.
    const { data, error } = await supabase.functions.invoke("raw-materials-create", {
      body: {
        name: item.name,
        unit: item.unit,
        lowStockThreshold: item.lowStockThreshold,
        category: item.category?.trim() || undefined,
      },
    });
    if (error || !data?.data) {
      // supabase-js puts the actual JSON error body (our envelope) on
      // error.context for non-2xx responses; error.message itself is
      // just a generic "non-2xx status code" string.
      let message = "Failed to add raw material";
      const ctx = (error as any)?.context;
      if (ctx && typeof ctx.json === "function") {
        try {
          const body = await ctx.json();
          if (body?.error?.message) message = body.error.message;
        } catch {
          // ignore parse failure, fall back to default message
        }
      }
      throw new Error(message);
    }
    const material = mapRawMaterialRow(data.data);
    set((s) => ({ rawMaterials: [...s.rawMaterials, material] }));
    return material.id;
  },
'@

# Normalize line endings for reliable matching (file may use CRLF)
$contentNormalized = $content -replace "`r`n", "`n"
$oldNormalized = $oldBlock -replace "`r`n", "`n"
$oldNormalized = $oldNormalized.Trim("`n")

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

if ($contentNormalized -notmatch [regex]::Escape($oldNormalized)) {
    Log "FAIL: Expected addRawMaterial block nahi mila store.ts mein."
    Log "Wajah ye ho sakti hai ke file already fix ho chuki hai, ya file structure"
    Log "iske baad se badal chuka hai. Koi change nahi kiya gaya — file untouched hai."
    $LogLines | Set-Content -LiteralPath $LogFile -Encoding UTF8
    Write-Host ""
    Write-Host "Log file yahan hai: $LogFile"
    exit 1
}

# Backup original
$backupFile = "$TargetFile.bak"
Copy-Item -LiteralPath $TargetFile -Destination $backupFile -Force
Log "Backup ban gayi: $backupFile"

# Replace (on normalized \n content) then restore CRLF for the whole file
$newNormalized = $newBlock -replace "`r`n", "`n"
$newNormalized = $newNormalized.Trim("`n")

# Plain string replace (safe here since $oldNormalized is a unique block)
$updatedNormalized = $contentNormalized.Replace($oldNormalized, $newNormalized)

$updatedContent = $updatedNormalized -replace "`n", "`r`n"

Set-Content -LiteralPath $TargetFile -Value $updatedContent -Encoding UTF8 -NoNewline

Log "SUCCESS: addRawMaterial function update ho gaya hai:"
Log "  $TargetFile"
Log ""
Log "Kya badla:"
Log "- addRawMaterial ab raw-materials-create edge function ko call karta hai"
Log "  (direct table insert ki jagah), taake case-insensitive duplicate-name"
Log "  check (Atta / atta) bypass na ho."
Log "- Duplicate honay par edge function ka asli Urdu message"
Log "  ('Is naam ka raw material pehle se maujood hai: X') ab UI toast mein"
Log "  dikhega, generic error ki jagah."
Log ""
Log "Agar kuch galat ho to original file yahan se restore kar sakte hain:"
Log "  Copy-Item -LiteralPath `"$backupFile`" -Destination `"$TargetFile`" -Force"

$LogLines | Set-Content -LiteralPath $LogFile -Encoding UTF8

Write-Host ""
Write-Host "Done. Log file yahan hai: $LogFile"