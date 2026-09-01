#
# fix-issue3-addRawMaterial.ps1
#
# Kya karta hai:
# - apps/frontend/lib/store.ts mein addRawMaterial function ko find karta hai
# - Direct table insert (jo duplicate-name check bypass karta tha) ko
#   hata kar raw-materials-create edge function ke through route karta hai
# - Original file ki backup (.bak) banata hai
# - Result / log ek .txt file mein likhta hai (results\fix-issue3-log.txt)
#
# Run karne ka tareeqa:
# 1. Is script ko project root mein rakhein
# 2. PowerShell open karein us folder mein
# 3. Run karein:  .\fix-issue3-addRawMaterial.ps1

$ProjectRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Get-Location).Path
}

$TargetFile = Join-Path $ProjectRoot 'apps\frontend\lib\store.ts'
$ResultsDir = Join-Path $ProjectRoot 'results'
$LogFile    = Join-Path $ResultsDir 'fix-issue3-log.txt'

$LogLines = New-Object System.Collections.Generic.List[string]

function Add-Log {
    param([string]$Message)
    Write-Host $Message
    $LogLines.Add($Message)
}

Add-Log '===== fix-issue3-addRawMaterial.ps1 ====='
Add-Log ('Run time: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Add-Log ('Project root: ' + $ProjectRoot)
Add-Log ('Target file: ' + $TargetFile)
Add-Log ''

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

if (-not (Test-Path -LiteralPath $TargetFile)) {
    Add-Log ('FAIL: store.ts nahi mili at: ' + $TargetFile)
    Add-Log 'Confirm karein ke ye script GhaniFoods project root mein rakhi gayi hai.'
    Set-Content -LiteralPath $LogFile -Value $LogLines -Encoding UTF8
    exit 1
}

$content = Get-Content -LiteralPath $TargetFile -Raw -Encoding UTF8

# ---- Old block lines (line-by-line array, taake quote-escaping ka masla na ho) ----
$oldLines = @(
    '  addRawMaterial: async (item) => {',
    '    const { data, error } = await supabase',
    '      .from("raw_materials")',
    '      .insert({ name: item.name, unit: item.unit, low_stock_threshold: item.lowStockThreshold, category: item.category?.trim() || null })',
    '      .select()',
    '      .single();',
    '    if (error || !data) throw new Error(error?.message ?? "Failed to add raw material");',
    '    const material = mapRawMaterialRow(data);',
    '    set((s) => ({ rawMaterials: [...s.rawMaterials, material] }));',
    '    return material.id;',
    '  },'
)

$newLines = @(
    '  addRawMaterial: async (item) => {',
    '    // Routed through the raw-materials-create edge function (not a direct',
    '    // table insert) so the server-side case-insensitive duplicate-name',
    '    // check (e.g. "Atta" vs "atta") actually runs.',
    '    const { data, error } = await supabase.functions.invoke("raw-materials-create", {',
    '      body: {',
    '        name: item.name,',
    '        unit: item.unit,',
    '        lowStockThreshold: item.lowStockThreshold,',
    '        category: item.category?.trim() || undefined,',
    '      },',
    '    });',
    '    if (error || !data?.data) {',
    '      // supabase-js puts the actual JSON error body (our envelope) on',
    '      // error.context for non-2xx responses; error.message itself is',
    '      // just a generic "non-2xx status code" string.',
    '      let message = "Failed to add raw material";',
    '      const ctx = (error as any)?.context;',
    '      if (ctx && typeof ctx.json === "function") {',
    '        try {',
    '          const body = await ctx.json();',
    '          if (body?.error?.message) message = body.error.message;',
    '        } catch {',
    '          // ignore parse failure, fall back to default message',
    '        }',
    '      }',
    '      throw new Error(message);',
    '    }',
    '    const material = mapRawMaterialRow(data.data);',
    '    set((s) => ({ rawMaterials: [...s.rawMaterials, material] }));',
    '    return material.id;',
    '  },'
)

$oldBlock = [string]::Join("`n", $oldLines)
$newBlock = [string]::Join("`n", $newLines)

$contentNormalized = $content -replace "`r`n", "`n"

if (-not $contentNormalized.Contains($oldBlock)) {
    Add-Log 'FAIL: Expected addRawMaterial block nahi mila store.ts mein.'
    Add-Log 'Wajah ye ho sakti hai ke file already fix ho chuki hai, ya file'
    Add-Log 'structure iske baad se badal chuka hai. Koi change nahi kiya gaya.'
    Set-Content -LiteralPath $LogFile -Value $LogLines -Encoding UTF8
    Write-Host ''
    Write-Host ('Log file: ' + $LogFile)
    exit 1
}

$occurrences = ([regex]::Matches($contentNormalized, [regex]::Escape($oldBlock))).Count
if ($occurrences -ne 1) {
    Add-Log ('FAIL: Block ' + $occurrences + ' jagah mila (1 expect tha). Safety ke liye koi change nahi kiya gaya.')
    Set-Content -LiteralPath $LogFile -Value $LogLines -Encoding UTF8
    exit 1
}

$backupFile = $TargetFile + '.bak'
Copy-Item -LiteralPath $TargetFile -Destination $backupFile -Force
Add-Log ('Backup ban gayi: ' + $backupFile)

$updatedNormalized = $contentNormalized.Replace($oldBlock, $newBlock)
$updatedContent = $updatedNormalized -replace "`n", "`r`n"

Set-Content -LiteralPath $TargetFile -Value $updatedContent -Encoding UTF8 -NoNewline

Add-Log ('SUCCESS: addRawMaterial function update ho gaya hai: ' + $TargetFile)
Add-Log ''
Add-Log 'Kya badla:'
Add-Log '- addRawMaterial ab raw-materials-create edge function ko call karta hai'
Add-Log '  (direct table insert ki jagah), taake case-insensitive duplicate-name'
Add-Log '  check (Atta / atta) bypass na ho.'
Add-Log '- Duplicate honay par edge function ka asli Urdu message ab UI toast'
Add-Log '  mein dikhega, generic error ki jagah.'
Add-Log ''
Add-Log 'Agar kuch galat ho to original file restore karne ke liye:'
Add-Log ('  Copy-Item -LiteralPath "' + $backupFile + '" -Destination "' + $TargetFile + '" -Force')

Set-Content -LiteralPath $LogFile -Value $LogLines -Encoding UTF8

Write-Host ''
Write-Host ('Done. Log file: ' + $LogFile)