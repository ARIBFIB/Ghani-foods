<#
========================================================================
  Run-GhaniFoods-Testing.ps1

  Purpose:
    Pura GhaniFoods project (apps/frontend + apps/backend + supabase
    functions) ka FULL SYSTEM TESTING script.

    Ye script karta hai:
      - Alpha Testing   -> static code checks (har file, har function)
      - Beta Testing    -> build/typecheck simulation (frontend+backend)
      - UAT Checklist   -> user-flow checklist (manual sign-off wala)
      - Logic/Function Testing -> har .ts/.tsx file me functions dhoondh
                                   kar unka status (OK / SUSPECT / BROKEN)
                                   nikalta hai (empty body, TODO, no
                                   return, empty catch, console.log left
                                   in code, etc.)
      - RPC Functional Smoke Test -> asal Supabase RPC functions ko real
                                     sample data ke saath call karta hai
                                     (opt-in, -RunRpcSmokeTest se), taake
                                     "reachable hai" aur "sahi kaam karta
                                     hai" dono test ho.

    Output "Testing Report" folder me 3 files banta hai:
      - TestingReport_<timestamp>.txt
      - TestingReport_<timestamp>.json
      - TestingReport_<timestamp>.pdf   (Edge/Chrome headless se, agar
                                          system par available ho)

  Run karne ka tareeqa (root se):
    PS D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods> .\Run-GhaniFoods-Testing.ps1
    PS D:\...\GhaniFoods> .\Run-GhaniFoods-Testing.ps1 -RunRpcSmokeTest   # also runs real RPC calls (see WARNING below)
========================================================================
#>

[CmdletBinding()]
param(
    [switch]$SkipInstall,     # npm install skip karne ke liye (agar node_modules already hai)
    [switch]$SkipBuild,       # build/typecheck skip karne ke liye (sirf static scan chahiye to)
    [switch]$RunRpcSmokeTest  # DESTRUCTIVE: real Supabase RPCs ko real sample data se call karta hai
                              # (e.g. fn_create_invoice) - ye REAL invoice banata hai aur REAL stock
                              # deduct karta hai. Sirf staging/test project par, ya jaan-boojh kar
                              # production par ek test customer/item ke saath chalayein. Default OFF.
)

$ErrorActionPreference = "Continue"
$Root = (Get-Location).Path

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " GhaniFoods - FULL SYSTEM TESTING" -ForegroundColor Cyan
Write-Host " Root: $Root" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($RunRpcSmokeTest) {
    Write-Host " WARNING: -RunRpcSmokeTest is ON. This will call REAL Supabase RPC" -ForegroundColor Red
    Write-Host " functions (e.g. fn_create_invoice) with REAL sample data pulled from" -ForegroundColor Red
    Write-Host " your DB. This WILL create a real invoice row and deduct real stock." -ForegroundColor Red
    Write-Host " Press Ctrl+C now to abort, or wait 5 seconds to continue..." -ForegroundColor Red
    Start-Sleep -Seconds 5
}

# ------------------------------------------------------------------
# Setup: Report folder + timestamp
# ------------------------------------------------------------------
$Timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$ReportDir   = Join-Path $Root "Testing Report"
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir | Out-Null
}
else {
    # Purani reports delete kar do - har run par sirf latest report rahega
    Get-ChildItem -Path $ReportDir -File -Include "TestingReport_*.txt","TestingReport_*.json","TestingReport_*.html","TestingReport_*.pdf" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "  Purani reports clear kar di gayin - naya report banega." -ForegroundColor DarkGray
}

$TxtPath  = Join-Path $ReportDir "TestingReport_$Timestamp.txt"
$JsonPath = Join-Path $ReportDir "TestingReport_$Timestamp.json"
$HtmlPath = Join-Path $ReportDir "TestingReport_$Timestamp.html"
$PdfPath  = Join-Path $ReportDir "TestingReport_$Timestamp.pdf"

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# Result buckets
$Findings      = New-Object System.Collections.Generic.List[Object]   # file/function level issues
$FunctionStats = New-Object System.Collections.Generic.List[Object]   # every function found + status
$BuildResults  = New-Object System.Collections.Generic.List[Object]   # alpha/beta build steps
$UatChecklist  = New-Object System.Collections.Generic.List[Object]

$SW = [System.Diagnostics.Stopwatch]::StartNew()

# ------------------------------------------------------------------
# Helper: run a command, capture pass/fail, add to BuildResults
# ------------------------------------------------------------------
function Invoke-Step {
    param(
        [string]$Phase,       # Alpha / Beta / UAT
        [string]$Name,
        [string]$WorkDir,
        [string]$Command,
        [string[]]$Arguments
    )
    Write-Host "  -> [$Phase] $Name" -ForegroundColor Yellow
    $stepSw = [System.Diagnostics.Stopwatch]::StartNew()
    $out = ""
    $ok  = $true
    try {
        Push-Location $WorkDir
        $out = & $Command @Arguments 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { $ok = $false }
    }
    catch {
        $ok  = $false
        $out += "`nEXCEPTION: $($_.Exception.Message)"
    }
    finally {
        Pop-Location
    }
    $stepSw.Stop()

    $BuildResults.Add([PSCustomObject]@{
        Phase      = $Phase
        Step       = $Name
        Status     = if ($ok) { "PASS" } else { "FAIL" }
        DurationMs = [int]$stepSw.Elapsed.TotalMilliseconds
        Output     = ($out.Trim())
    })

    if ($ok) { Write-Host "     OK ($([int]$stepSw.Elapsed.TotalSeconds)s)" -ForegroundColor Green }
    else {
        Write-Host "     FAILED ($([int]$stepSw.Elapsed.TotalSeconds)s) - see report" -ForegroundColor Red
        $preview = ($out.Trim() -split "`r?`n" | Select-Object -Last 15) -join "`n"
        if ($preview) {
            Write-Host "     ---- last 15 lines ----" -ForegroundColor DarkGray
            Write-Host "     $preview" -ForegroundColor DarkGray
        }
    }

    return $ok
}

# ============================================================
# PHASE 1: ALPHA TESTING (internal, code-level, static)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 1: ALPHA TESTING (static code scan) =====" -ForegroundColor Cyan

$ScanRoots = @()
if (Test-Path (Join-Path $Root "apps\backend"))  { $ScanRoots += (Join-Path $Root "apps\backend") }
if (Test-Path (Join-Path $Root "apps\frontend")) { $ScanRoots += (Join-Path $Root "apps\frontend") }
if ($ScanRoots.Count -eq 0) { $ScanRoots += $Root }

$CodeFiles = foreach ($r in $ScanRoots) {
    Get-ChildItem -Path $r -Recurse -File -Include *.ts,*.tsx -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\node_modules\\' -and
            $_.FullName -notmatch '\\\.next\\' -and
            $_.FullName -notmatch '\\dist\\'
        }
}
$CodeFiles = @($CodeFiles)
Write-Host "  Files to scan: $($CodeFiles.Count)" -ForegroundColor Gray

# Regex patterns for logic-level red flags
$PatternChecks = @(
    @{ Name = "TODO/FIXME left in code";        Regex = '(?i)\b(TODO|FIXME|HACK)\b' }
    @{ Name = "console.log left in code";        Regex = 'console\.(log|debug)\s*\(' }
    @{ Name = "Empty catch block";               Regex = 'catch\s*\([^)]*\)\s*\{\s*\}' }
    @{ Name = "Debugger statement left";         Regex = '\bdebugger\b' }
    @{ Name = "Hardcoded localhost URL";         Regex = 'https?://localhost' }
    @{ Name = "Possible hardcoded secret/key";   Regex = '(?i)(api[_-]?key|secret|password)\s*[:=]\s*["''][A-Za-z0-9_\-]{8,}["'']' }
    @{ Name = "any type used (weak typing)";     Regex = ':\s*any\b' }
    @{ Name = "Unhandled promise (no await/then/catch on obvious call)"; Regex = '^\s*[A-Za-z0-9_.]+\(\s*\)\s*;\s*$' ; Weak = $true }
)

$FunctionRegex = '(?m)(?:export\s+)?(?:async\s+)?function\s+([A-Za-z0-9_]+)\s*\(|(?:export\s+)?const\s+([A-Za-z0-9_]+)\s*=\s*(?:async\s*)?\([^)]*\)\s*(?::\s*[^=]+)?=>'

foreach ($file in $CodeFiles) {
    $rel = $file.FullName.Substring($Root.Length).TrimStart('\','/')
    $content = $null
    try { $content = [System.IO.File]::ReadAllText($file.FullName) } catch { $content = $null }
    if ([string]::IsNullOrEmpty($content)) { continue }
    $lines = $content -split "`r?`n"

    # --- pattern-based findings ---
    foreach ($p in $PatternChecks) {
        $matches = [regex]::Matches($content, $p.Regex)
        if ($matches.Count -gt 0 -and -not $p.Weak) {
            foreach ($m in $matches) {
                $lineNo = ($content.Substring(0, $m.Index) -split "`n").Count
                $Findings.Add([PSCustomObject]@{
                    File     = $rel
                    Line     = $lineNo
                    Category = $p.Name
                    Snippet  = ($lines[[Math]::Min($lineNo-1, $lines.Count-1)]).Trim()
                    Severity = if ($p.Name -match 'secret|Debugger') { "HIGH" } elseif ($p.Name -match 'TODO|console') { "LOW" } else { "MEDIUM" }
                })
            }
        }
    }

    # --- function-level extraction ---
    $fnMatches = [regex]::Matches($content, $FunctionRegex)
    foreach ($fm in $fnMatches) {
        $fnName = if ($fm.Groups[1].Success) { $fm.Groups[1].Value } else { $fm.Groups[2].Value }
        if ([string]::IsNullOrWhiteSpace($fnName)) { continue }

        $startIdx = $fm.Index
        $lineNo = ($content.Substring(0, $startIdx) -split "`n").Count

        # naive body slice: next 400 chars after match, ya agli function tak
        $bodyEnd = [Math]::Min($content.Length, $startIdx + 600)
        $body = $content.Substring($startIdx, $bodyEnd - $startIdx)

        $status = "OK"
        $reason = ""
        if ($body -match '\{\s*\}') { $status = "SUSPECT"; $reason = "Empty function body ho sakta hai" }
        elseif ($body -match '(?i)TODO|FIXME|not implemented|NotImplemented') { $status = "SUSPECT"; $reason = "TODO / not-implemented marker mila" }
        elseif ($body -match 'throw new Error\(["'']not implemented["'']\)') { $status = "BROKEN"; $reason = "Explicitly not implemented" }

        $FunctionStats.Add([PSCustomObject]@{
            File     = $rel
            Line     = $lineNo
            Function = $fnName
            Status   = $status
            Reason   = $reason
        })
    }
}

$SeverityCounts = $Findings | Group-Object Severity | ForEach-Object { "$($_.Name)=$($_.Count)" } | Out-String
Write-Host "  Static findings: $($Findings.Count)  |  Functions scanned: $($FunctionStats.Count)" -ForegroundColor Gray

# ============================================================
# PHASE 2: BETA TESTING (typecheck / build simulation)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 2: BETA TESTING (typecheck / build) =====" -ForegroundColor Cyan

$BackendDir  = Join-Path $Root "apps\backend"
$FrontendDir = Join-Path $Root "apps\frontend"

if (Test-Path $BackendDir) {
    if (-not $SkipInstall -and -not (Test-Path (Join-Path $BackendDir "node_modules"))) {
        $null = Invoke-Step -Phase "Beta" -Name "Backend: npm install" -WorkDir $BackendDir -Command "npm" -Arguments @("install")
    }
    if (-not $SkipBuild) {
        $null = Invoke-Step -Phase "Beta" -Name "Backend: TypeScript build (tsc)" -WorkDir $BackendDir -Command "npm" -Arguments @("run","build")
    }
}
else {
    Write-Host "  apps\backend not found - skipping backend build" -ForegroundColor DarkYellow
}

if (Test-Path $FrontendDir) {
    if (-not $SkipInstall -and -not (Test-Path (Join-Path $FrontendDir "node_modules"))) {
        $null = Invoke-Step -Phase "Beta" -Name "Frontend: npm install" -WorkDir $FrontendDir -Command "npm" -Arguments @("install")
    }
    if (-not $SkipBuild) {
        $null = Invoke-Step -Phase "Beta" -Name "Frontend: Next.js build" -WorkDir $FrontendDir -Command "npm" -Arguments @("run","build")
    }
}
else {
    Write-Host "  apps\frontend not found - skipping frontend build" -ForegroundColor DarkYellow
}

# Supabase functions - deno/ts syntax presence check (no execution, just existence + basic scan already covered in Alpha)
$SupaFnDir = Join-Path $Root "apps\backend\supabase\functions"
if (Test-Path $SupaFnDir) {
    $fnCount = (Get-ChildItem -Path $SupaFnDir -Directory -ErrorAction SilentlyContinue).Count
    $BuildResults.Add([PSCustomObject]@{
        Phase = "Beta"; Step = "Supabase Edge Functions inventory"
        Status = "INFO"; DurationMs = 0
        Output = "Total edge function folders found: $fnCount"
    })
}

# ============================================================
# PHASE 3: USER ACCEPTANCE TESTING (UAT) - checklist
# ============================================================
Write-Host ""
Write-Host "===== PHASE 3: UAT CHECKLIST (manual sign-off) =====" -ForegroundColor Cyan

$UatFlows = @(
    "Login / Auth flow (apps/frontend/app/(auth)/login)"
    "Dashboard KPIs load correctly (dashboard-kpis function)"
    "Raw Materials: create / list / history"
    "Production Batches: create batch, view detail, leftover sources"
    "Packing Runs + Preview"
    "Finished Cartons stock view"
    "Carton Configurations: create / update"
    "Customers: create / ledger / item prices / invoices"
    "Invoices: create, PDF export, price lookup, back-context"
    "Payments recording"
    "Purchase Receipts: create / list / update / delete"
    "Suppliers history"
    "Monthly Expenses + Overhead allocation"
    "Reports: Inventory / P&L / Production / Finished Carton availability"
    "Data Export / Data Delete (danger zone)"
    "Settings page"
)
foreach ($flow in $UatFlows) {
    $UatChecklist.Add([PSCustomObject]@{ Flow = $flow; Status = "PENDING MANUAL CHECK" })
}
Write-Host "  UAT flows listed: $($UatChecklist.Count) (in-app se manually verify karein)" -ForegroundColor Gray

# ============================================================
# PHASE 4: DEAD / BROKEN BUTTON SCAN (frontend .tsx)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 4: BUTTON / CLICK-HANDLER SCAN =====" -ForegroundColor Cyan

$ButtonFindings = New-Object System.Collections.Generic.List[Object]
$FrontendFiles = @($CodeFiles | Where-Object { $_.FullName -match '\\apps\\frontend\\' -and $_.Extension -eq '.tsx' })

# Regex: <button ...> or <Button ...>  (self-contained tag, up to matching '>')
$TagRegex = '<(button|Button)\b((?:=>|[^>])*?)>'

foreach ($file in $FrontendFiles) {
    $rel = $file.FullName.Substring($Root.Length).TrimStart('\','/')
    $content = $null
    try { $content = [System.IO.File]::ReadAllText($file.FullName) } catch { $content = $null }
    if ([string]::IsNullOrEmpty($content)) { continue }

    $tagMatches = [regex]::Matches($content, $TagRegex)
    foreach ($tm in $tagMatches) {
        $tagBody = $tm.Groups[2].Value
        $lineNo  = ($content.Substring(0, $tm.Index) -split "`n").Count

        # skip if type="submit" (form submit buttons legitimately have no onClick)
        $isSubmit = $tagBody -match 'type\s*=\s*["'']submit["'']'
        $hasOnClick = $tagBody -match 'onClick\s*='
        $isDisabledStatic = $tagBody -match '\bdisabled\b(?!\s*=\s*\{)(?!:)'   # bare disabled attribute only - excludes Tailwind "disabled:xxx" classes and disabled={expr}

        if (-not $hasOnClick -and -not $isSubmit) {
            $ButtonFindings.Add([PSCustomObject]@{
                File = $rel; Line = $lineNo
                Issue = "onClick handler missing (aur type=submit bhi nahi)"
                Snippet = ($tagBody.Trim() -replace '\s+',' ') 
                Severity = "HIGH"
            })
            continue
        }

        if ($hasOnClick) {
            # extract handler reference, e.g. onClick={handleSave} or onClick={() => ...}
            $hm = [regex]::Match($tagBody, 'onClick\s*=\s*\{([^}]*)\}')
            $handlerExpr = if ($hm.Success) { $hm.Groups[1].Value.Trim() } else { "" }

            if ($handlerExpr -match '^\(\)\s*=>\s*\{\s*\}$' -or $handlerExpr -eq '') {
                $ButtonFindings.Add([PSCustomObject]@{
                    File = $rel; Line = $lineNo
                    Issue = "onClick khaali arrow function hai - kuch nahi karta"
                    Snippet = ($tagBody.Trim() -replace '\s+',' ')
                    Severity = "HIGH"
                })
            }
            elseif ($handlerExpr -match '^console\.(log|debug)\(') {
                $ButtonFindings.Add([PSCustomObject]@{
                    File = $rel; Line = $lineNo
                    Issue = "onClick sirf console.log karta hai - real action missing"
                    Snippet = ($tagBody.Trim() -replace '\s+',' ')
                    Severity = "MEDIUM"
                })
            }
            else {
                # named handler -> check if that function exists & is non-trivial in same file
                $fnNameMatch = [regex]::Match($handlerExpr, '^[A-Za-z0-9_]+$')
                if ($fnNameMatch.Success) {
                    $fnName = $fnNameMatch.Value
                    $defPattern = "(function\s+$fnName\s*\(|const\s+$fnName\s*=)"
                    if ($content -notmatch $defPattern) {
                        $ButtonFindings.Add([PSCustomObject]@{
                            File = $rel; Line = $lineNo
                            Issue = "onClick='$fnName' - is naam ka function isi file me define nahi mila (import se aa sakta hai, manually check karein)"
                            Snippet = ($tagBody.Trim() -replace '\s+',' ')
                            Severity = "LOW"
                        })
                    }
                }
            }
        }

        if ($isDisabledStatic) {
            $ButtonFindings.Add([PSCustomObject]@{
                File = $rel; Line = $lineNo
                Issue = "Button hamesha disabled hai (static 'disabled' attribute, koi condition nahi)"
                Snippet = ($tagBody.Trim() -replace '\s+',' ')
                Severity = "MEDIUM"
            })
        }
    }
}
Write-Host "  Buttons scanned: $($tagMatches.Count -as [string])  |  Issues found: $($ButtonFindings.Count)" -ForegroundColor Gray

# ============================================================
# PHASE 5: DOMAIN MODEL (ER diagram from type/interface defs)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 5: DOMAIN MODEL EXTRACTION =====" -ForegroundColor Cyan

$Entities = New-Object System.Collections.Generic.List[Object]   # { Name, Fields=[ {Name,Type} ] }
$TypeDefRegex = '(?ms)(?:export\s+)?(?:type|interface)\s+([A-Za-z0-9_]+)\s*(?:=\s*)?\{(.*?)\}'

$DomainSourceFiles = @($CodeFiles | Where-Object {
    $_.FullName -match '(data\.ts|schemas\.ts|types)' 
})
if ($DomainSourceFiles.Count -eq 0) { $DomainSourceFiles = $CodeFiles }

foreach ($file in $DomainSourceFiles) {
    $content = $null
    try { $content = [System.IO.File]::ReadAllText($file.FullName) } catch { continue }
    if ([string]::IsNullOrEmpty($content)) { continue }

    $defs = [regex]::Matches($content, $TypeDefRegex)
    foreach ($d in $defs) {
        $entityName = $d.Groups[1].Value
        $body = $d.Groups[2].Value
        if ($body.Length -gt 2000) { continue }  # skip giant non-domain blocks (route handlers etc.)

        $fieldLines = $body -split "`r?`n" | Where-Object { $_.Trim() -match '^[A-Za-z0-9_]+\??\s*:' }
        $fields = New-Object System.Collections.Generic.List[Object]
        foreach ($fl in $fieldLines) {
            $fm = [regex]::Match($fl.Trim(), '^([A-Za-z0-9_]+)(\??)\s*:\s*([^;,]+)')
            if ($fm.Success) {
                $fields.Add([PSCustomObject]@{ Name = $fm.Groups[1].Value; Optional = $fm.Groups[2].Value -eq '?'; Type = ($fm.Groups[3].Value.Trim() -replace '"','') })
            }
        }
        if ($fields.Count -gt 0 -and -not ($Entities | Where-Object Name -eq $entityName)) {
            $Entities.Add([PSCustomObject]@{ Name = $entityName; Fields = $fields })
        }
    }
}
Write-Host "  Entities extracted: $($Entities.Count)" -ForegroundColor Gray

# Build Mermaid ER diagram + naive relationships (fieldName ending in 'Id' matches another entity)
$MermaidEr = New-Object System.Text.StringBuilder
[void]$MermaidEr.AppendLine("erDiagram")
foreach ($e in $Entities) {
    [void]$MermaidEr.AppendLine("    $($e.Name) {")
    foreach ($f in $e.Fields) {
        $safeType = ($f.Type -replace '[^A-Za-z0-9_\[\]]','_')
        if ([string]::IsNullOrWhiteSpace($safeType)) { $safeType = "any" }
        [void]$MermaidEr.AppendLine("        $safeType $($f.Name)")
    }
    [void]$MermaidEr.AppendLine("    }")
}
foreach ($e in $Entities) {
    foreach ($f in $e.Fields) {
        if ($f.Name -match '(?i)^(.*)Id$' -and $f.Name -ne 'id') {
            $refBase = $Matches[1]
            $target = $Entities | Where-Object { $_.Name -match "(?i)$refBase" -and $_.Name -ne $e.Name } | Select-Object -First 1
            if ($target) {
                [void]$MermaidEr.AppendLine("    $($target.Name) ||--o{ $($e.Name) : `"has`"")
            }
        }
    }
}

# ============================================================
# PHASE 6: SEQUENCE DIAGRAMS (Frontend -> api.ts -> Supabase Function -> DB)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 6: SEQUENCE DIAGRAMS (per module) =====" -ForegroundColor Cyan

$SupaFnNames = @()
if (Test-Path $SupaFnDir) {
    $SupaFnNames = (Get-ChildItem -Path $SupaFnDir -Directory -ErrorAction SilentlyContinue).Name | Where-Object { $_ -notmatch '^_' }
}

# group supabase functions into modules by common prefix keyword
$Modules = @{}
foreach ($fn in $SupaFnNames) {
    $key = ($fn -split '-')[0]
    if (-not $Modules.ContainsKey($key)) { $Modules[$key] = New-Object System.Collections.Generic.List[string] }
    $Modules[$key].Add($fn)
}

$SequenceDiagrams = New-Object System.Collections.Generic.List[Object]
foreach ($mod in $Modules.Keys | Sort-Object) {
    $fns = $Modules[$mod]
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("sequenceDiagram")
    [void]$sb.AppendLine("    participant U as User")
    [void]$sb.AppendLine("    participant FE as Frontend (Next.js page)")
    [void]$sb.AppendLine("    participant API as lib/api.ts")
    [void]$sb.AppendLine("    participant EF as Supabase Edge Fn ($mod-*)")
    [void]$sb.AppendLine("    participant DB as Postgres DB")
    [void]$sb.AppendLine("    U->>FE: Click / submit action")
    [void]$sb.AppendLine("    FE->>API: call helper function")
    foreach ($f in $fns) {
        [void]$sb.AppendLine("    API->>EF: HTTP request -> /$f")
        [void]$sb.AppendLine("    EF->>DB: query / mutate")
        [void]$sb.AppendLine("    DB-->>EF: result")
        [void]$sb.AppendLine("    EF-->>API: JSON response")
    }
    [void]$sb.AppendLine("    API-->>FE: data")
    [void]$sb.AppendLine("    FE-->>U: UI update")
    $SequenceDiagrams.Add([PSCustomObject]@{ Module = $mod; Mermaid = $sb.ToString() })
}
Write-Host "  Sequence diagrams generated: $($SequenceDiagrams.Count) (module-wise)" -ForegroundColor Gray

# ============================================================
# PHASE 7: NAVIGATION / FLOW DIAGRAM (Next.js route tree)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 7: NAVIGATION FLOW DIAGRAM =====" -ForegroundColor Cyan

$DashboardDir = Join-Path $FrontendDir "app\(dashboard)"
$FlowSb = New-Object System.Text.StringBuilder
[void]$FlowSb.AppendLine("flowchart TD")
[void]$FlowSb.AppendLine("    Login[Login Page] --> Dashboard[Dashboard Home]")

if (Test-Path $DashboardDir) {
    $routeDirs = Get-ChildItem -Path $DashboardDir -Directory -ErrorAction SilentlyContinue
    foreach ($rd in $routeDirs) {
        $nodeName = ($rd.Name -replace '[^A-Za-z0-9]','_')
        [void]$FlowSb.AppendLine("    Dashboard --> $nodeName[$($rd.Name)]")
        $subDirs = Get-ChildItem -Path $rd.FullName -Directory -ErrorAction SilentlyContinue
        foreach ($sd in $subDirs) {
            $subNode = "$($nodeName)_$($sd.Name -replace '[^A-Za-z0-9]','_')"
            $label = $sd.Name
            [void]$FlowSb.AppendLine("    $nodeName --> $subNode[$label]")
        }
    }
}
Write-Host "  Flow diagram nodes generated from app/(dashboard) route tree" -ForegroundColor Gray

# ============================================================
# Helpers for live HTTP testing (used by Phase 8-11)
# ============================================================
function Get-DotEnvValue {
    param([string]$Dir, [string]$Key)
    foreach ($fname in @(".env", ".env.local", ".env.development")) {
        $p = Join-Path $Dir $fname
        if (Test-Path $p) {
            $lines = Get-Content -Path $p -ErrorAction SilentlyContinue
            foreach ($l in $lines) {
                if ($l -match "^\s*$Key\s*=\s*(.+?)\s*$") {
                    return ($Matches[1].Trim('"').Trim("'"))
                }
            }
        }
    }
    return $null
}

function Test-HttpEndpoint {
    param([string]$Url, [string]$Method = "GET", [hashtable]$Headers = @{}, [string]$Body = $null, [int]$TimeoutSec = 8)
    $result = [ordered]@{ Url = $Url; Method = $Method; StatusCode = $null; Status = "UNREACHABLE"; Error = "" ; DurationMs = 0}
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $params = @{ Uri = $Url; Method = $Method; TimeoutSec = $TimeoutSec; Headers = $Headers; UseBasicParsing = $true }
        if ($Body) { $params["Body"] = $Body; $params["ContentType"] = "application/json" }
        $resp = Invoke-WebRequest @params -ErrorAction Stop
        $result.StatusCode = [int]$resp.StatusCode
        $result.Status = "REACHABLE"
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $result.StatusCode = [int]$_.Exception.Response.StatusCode
            $result.Status = "REACHABLE"   # server responded, even if 4xx/5xx
        } else {
            $result.Status = "UNREACHABLE"
            $result.Error = $_.Exception.Message
        }
    }
    catch {
        # PowerShell 7 style HttpResponseException
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $result.StatusCode = [int]$_.Exception.Response.StatusCode
            $result.Status = "REACHABLE"
        } else {
            $result.Status = "UNREACHABLE"
            $result.Error = $_.Exception.Message
        }
    }
    $sw.Stop()
    $result.DurationMs = [int]$sw.Elapsed.TotalMilliseconds
    return [PSCustomObject]$result
}

function Wait-ForServerReady {
    param([string]$Url, [int]$TimeoutSec = 30)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-WebRequest -Uri $Url -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop | Out-Null
            return $true
        } catch { Start-Sleep -Milliseconds 800 }
    }
    return $false
}

function Stop-ProcessTree {
    param([int]$ProcId)
    try { & taskkill /PID $ProcId /T /F 2>$null | Out-Null } catch {}
}

$BackendApiResults   = New-Object System.Collections.Generic.List[Object]
$SupabaseFnResults   = New-Object System.Collections.Generic.List[Object]
$DbTestResults       = New-Object System.Collections.Generic.List[Object]
$FrontendPageResults = New-Object System.Collections.Generic.List[Object]
$RpcSmokeResults     = New-Object System.Collections.Generic.List[Object]

# ============================================================
# PHASE 8: BACKEND LOCAL API LIVE TEST (apps/backend Express mock server)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 8: BACKEND API LIVE TEST =====" -ForegroundColor Cyan
try {
    $BackendIndexTs = Join-Path $BackendDir "src\index.ts"
    $BackendDistJs  = Join-Path $BackendDir "dist\index.js"

    if ((Test-Path $BackendIndexTs) -and (Test-Path $BackendDistJs)) {
        $idxContent = [System.IO.File]::ReadAllText($BackendIndexTs)
        $portMatch = [regex]::Match($idxContent, 'PORT\s*=\s*process\.env\.PORT\s*\?\s*Number\(process\.env\.PORT\)\s*:\s*(\d+)')
        $BePort = if ($portMatch.Success) { $portMatch.Groups[1].Value } else { "4000" }

        $routeMatches = [regex]::Matches($idxContent, 'app\.(get|post|put|patch|delete)\(\s*["'']([^"'']+)["'']')
        Write-Host "  Routes found in index.ts: $($routeMatches.Count) | Starting server on port $BePort ..." -ForegroundColor Gray

        $proc = Start-Process -FilePath "node" -ArgumentList @("dist/index.js") -WorkingDirectory $BackendDir -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $ReportDir "_backend_stdout.log") -RedirectStandardError (Join-Path $ReportDir "_backend_stderr.log")

        $ready = Wait-ForServerReady -Url "http://localhost:$BePort/api/health" -TimeoutSec 20
        if (-not $ready) {
            Write-Host "  Backend server ready nahi hua (20s timeout) - skipping route tests." -ForegroundColor Red
            $BackendApiResults.Add([PSCustomObject]@{ Route="(server startup)"; Method="-"; StatusCode=$null; Status="SERVER DID NOT START"; DurationMs=0 })
        }
        else {
            foreach ($rm in $routeMatches) {
                $method = $rm.Groups[1].Value.ToUpper()
                $path = $rm.Groups[2].Value -replace ':id', 'test-id'
                $url = "http://localhost:$BePort$path"
                $body = if ($method -in @("POST","PUT","PATCH")) { "{}" } else { $null }
                $r = Test-HttpEndpoint -Url $url -Method $method -Body $body
                $verdict = if ($r.Status -eq "REACHABLE" -and $r.StatusCode -lt 500) { "WORKING" }
                           elseif ($r.Status -eq "REACHABLE") { "SERVER ERROR (5xx)" }
                           else { "NOT WORKING (unreachable)" }
                $BackendApiResults.Add([PSCustomObject]@{
                    Route = $path; Method = $method; StatusCode = $r.StatusCode
                    Status = $verdict; DurationMs = $r.DurationMs
                })
            }
        }
        Stop-ProcessTree -ProcId $proc.Id
        Write-Host "  Backend API test done. Working: $(($BackendApiResults | Where-Object Status -eq 'WORKING').Count) / $($BackendApiResults.Count)" -ForegroundColor Gray
    }
    else {
        Write-Host "  apps\backend\dist\index.js nahi mila (build hui thi?) - skipping live API test." -ForegroundColor DarkYellow
        $BackendApiResults.Add([PSCustomObject]@{ Route="(n/a)"; Method="-"; StatusCode=$null; Status="SKIPPED - dist not found"; DurationMs=0 })
    }
}
catch {
    Write-Host "  Backend API live test error: $($_.Exception.Message)" -ForegroundColor Red
    $BackendApiResults.Add([PSCustomObject]@{ Route="(error)"; Method="-"; StatusCode=$null; Status="SKIPPED - $($_.Exception.Message)"; DurationMs=0 })
}

# ============================================================
# PHASE 9: SUPABASE EDGE FUNCTIONS LIVE TEST
# ============================================================
Write-Host ""
Write-Host "===== PHASE 9: SUPABASE EDGE FUNCTIONS LIVE TEST =====" -ForegroundColor Cyan
$SupaUrl = $null
$SupaAnon = $null
try {
    $SupaUrl = Get-DotEnvValue -Dir $FrontendDir -Key "NEXT_PUBLIC_SUPABASE_URL"
    if (-not $SupaUrl) { $SupaUrl = Get-DotEnvValue -Dir $BackendDir -Key "SUPABASE_URL" }
    $SupaAnon = Get-DotEnvValue -Dir $FrontendDir -Key "NEXT_PUBLIC_SUPABASE_ANON_KEY"
    if (-not $SupaAnon) { $SupaAnon = Get-DotEnvValue -Dir $BackendDir -Key "SUPABASE_ANON_KEY" }

    if (-not $SupaUrl -or -not $SupaAnon) {
        Write-Host "  .env me NEXT_PUBLIC_SUPABASE_URL / ANON_KEY nahi mile - LIVE test skip." -ForegroundColor DarkYellow
        Write-Host "  (Ye normal hai agar .env repo me commit nahi hai - security ke liye theek hai)" -ForegroundColor DarkYellow
        $SupabaseFnResults.Add([PSCustomObject]@{ Function="(all)"; Status="SKIPPED - .env / Supabase URL-key nahi mila"; StatusCode=$null; DurationMs=0 })
    }
    else {
        Write-Host "  Supabase URL mil gaya - $($SupaFnNames.Count) functions test kar rahe hain..." -ForegroundColor Gray
        foreach ($fn in $SupaFnNames) {
            $url = "$SupaUrl/functions/v1/$fn"
            $headers = @{ apikey = $SupaAnon; Authorization = "Bearer $SupaAnon" }
            $r = Test-HttpEndpoint -Url $url -Method "OPTIONS" -Headers $headers -TimeoutSec 10
            if ($r.Status -eq "UNREACHABLE") {
                $r = Test-HttpEndpoint -Url $url -Method "GET" -Headers $headers -TimeoutSec 10
            }
            $verdict = if ($r.Status -eq "REACHABLE" -and $r.StatusCode -ne 404) { "DEPLOYED / REACHABLE" }
                       elseif ($r.StatusCode -eq 404) { "NOT DEPLOYED (404)" }
                       else { "NOT REACHABLE" }
            $SupabaseFnResults.Add([PSCustomObject]@{ Function=$fn; Status=$verdict; StatusCode=$r.StatusCode; DurationMs=$r.DurationMs })
        }
        Write-Host "  Deployed/Reachable: $(($SupabaseFnResults | Where-Object Status -eq 'DEPLOYED / REACHABLE').Count) / $($SupabaseFnResults.Count)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  Supabase function test error: $($_.Exception.Message)" -ForegroundColor Red
    $SupabaseFnResults.Add([PSCustomObject]@{ Function="(error)"; Status="SKIPPED - $($_.Exception.Message)"; StatusCode=$null; DurationMs=0 })
}

# ============================================================
# PHASE 10: DATABASE CONNECTIVITY TEST (Supabase Postgres via REST)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 10: DATABASE CONNECTIVITY TEST =====" -ForegroundColor Cyan
$SqlTablesFound = @()
try {
    if (-not $SupaUrl -or -not $SupaAnon) {
        Write-Host "  Supabase URL/key nahi mile - DB test skip." -ForegroundColor DarkYellow
        $DbTestResults.Add([PSCustomObject]@{ Check="Database connectivity"; Status="SKIPPED - .env / Supabase URL-key nahi mila"; StatusCode=$null })
    }
    else {
        $restUrl = "$SupaUrl/rest/v1/"
        $r = Test-HttpEndpoint -Url $restUrl -Method "GET" -Headers @{ apikey = $SupaAnon; Authorization = "Bearer $SupaAnon" } -TimeoutSec 10
        $verdict = if ($r.Status -eq "REACHABLE") { "DATABASE REACHABLE" } else { "DATABASE NOT REACHABLE" }
        $DbTestResults.Add([PSCustomObject]@{ Check="Supabase REST/DB root ($restUrl)"; Status=$verdict; StatusCode=$r.StatusCode })

        # Try a few likely table names from migrations, based on entity names found in domain model
        $MigrationsDir = Join-Path $BackendDir "supabase\migrations"
        $sqlTables = @()
        if (Test-Path $MigrationsDir) {
            $sqlFiles = Get-ChildItem -Path $MigrationsDir -Filter "*.sql" -ErrorAction SilentlyContinue
            foreach ($sf in $sqlFiles) {
                $sqlContent = [System.IO.File]::ReadAllText($sf.FullName)
                $tblMatches = [regex]::Matches($sqlContent, '(?i)create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?"?([A-Za-z0-9_]+)"?')
                foreach ($tm in $tblMatches) { $sqlTables += $tm.Groups[1].Value }
            }
            $sqlTables = $sqlTables | Sort-Object -Unique
        }
        $SqlTablesFound = $sqlTables
        Write-Host "  Tables found in migrations: $($sqlTables.Count) - checking each is queryable..." -ForegroundColor Gray
        foreach ($tbl in $sqlTables) {
            $tUrl = "$SupaUrl/rest/v1/$tbl`?select=*&limit=1"
            $tr = Test-HttpEndpoint -Url $tUrl -Method "GET" -Headers @{ apikey = $SupaAnon; Authorization = "Bearer $SupaAnon" } -TimeoutSec 10
            $tv = if ($tr.Status -eq "REACHABLE" -and $tr.StatusCode -lt 400) { "TABLE OK" }
                  elseif ($tr.StatusCode -eq 404) { "TABLE NOT FOUND" }
                  elseif ($tr.StatusCode -eq 401 -or $tr.StatusCode -eq 403) { "TABLE EXISTS (RLS/auth blocked - expected)" }
                  else { "ERROR" }
            $DbTestResults.Add([PSCustomObject]@{ Check="Table: $tbl"; Status=$tv; StatusCode=$tr.StatusCode })
        }
    }
}
catch {
    Write-Host "  DB test error: $($_.Exception.Message)" -ForegroundColor Red
    $DbTestResults.Add([PSCustomObject]@{ Check="Database connectivity"; Status="SKIPPED - $($_.Exception.Message)"; StatusCode=$null })
}

# ============================================================
# PHASE 11: FRONTEND PAGES LIVE TEST (next start)
# ============================================================
Write-Host ""
Write-Host "===== PHASE 11: FRONTEND PAGES LIVE TEST =====" -ForegroundColor Cyan
try {
    $NextBuildDir = Join-Path $FrontendDir ".next"
    if (-not (Test-Path $NextBuildDir)) {
        Write-Host "  .next build folder nahi mila (Phase 2 build fail hui thi?) - skipping." -ForegroundColor DarkYellow
        $FrontendPageResults.Add([PSCustomObject]@{ Page="(n/a)"; Status="SKIPPED - .next build missing"; StatusCode=$null })
    }
    else {
        $FePort = 3100
        $feProc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c","npm","run","start","--","-p","$FePort") -WorkingDirectory $FrontendDir -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $ReportDir "_frontend_stdout.log") -RedirectStandardError (Join-Path $ReportDir "_frontend_stderr.log")

        $ready = Wait-ForServerReady -Url "http://localhost:$FePort/login" -TimeoutSec 30
        if (-not $ready) {
            Write-Host "  Frontend server ready nahi hua (30s timeout) - skipping page tests." -ForegroundColor Red
            $FrontendPageResults.Add([PSCustomObject]@{ Page="(server startup)"; Status="SERVER DID NOT START"; StatusCode=$null })
        }
        else {
            $Pages = @("/login")
            if (Test-Path $DashboardDir) {
                $Pages += "/"
                $routeDirs2 = Get-ChildItem -Path $DashboardDir -Directory -ErrorAction SilentlyContinue
                foreach ($rd in $routeDirs2) {
                    $Pages += "/$($rd.Name)"
                    $subDirs2 = Get-ChildItem -Path $rd.FullName -Directory -ErrorAction SilentlyContinue
                    foreach ($sd in $subDirs2) {
                        $seg = if ($sd.Name -match '^\[.*\]$') { "test-id" } else { $sd.Name }
                        $Pages += "/$($rd.Name)/$seg"
                    }
                }
            }
            $Pages = $Pages | Sort-Object -Unique
            Write-Host "  Pages to test: $($Pages.Count)" -ForegroundColor Gray
            foreach ($pg in $Pages) {
                $url = "http://localhost:$FePort$pg"
                $r = Test-HttpEndpoint -Url $url -Method "GET" -TimeoutSec 10
                $verdict = if ($r.Status -eq "REACHABLE" -and $r.StatusCode -lt 400) { "LOADS OK" }
                           elseif ($r.StatusCode -eq 404) { "404 NOT FOUND" }
                           elseif ($r.Status -eq "REACHABLE") { "PAGE ERROR ($($r.StatusCode))" }
                           else { "NOT REACHABLE" }
                $FrontendPageResults.Add([PSCustomObject]@{ Page=$pg; Status=$verdict; StatusCode=$r.StatusCode; DurationMs=$r.DurationMs })
            }
        }
        Stop-ProcessTree -ProcId $feProc.Id
        Write-Host "  Frontend page test done. OK: $(($FrontendPageResults | Where-Object Status -eq 'LOADS OK').Count) / $($FrontendPageResults.Count)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  Frontend live test error: $($_.Exception.Message)" -ForegroundColor Red
    $FrontendPageResults.Add([PSCustomObject]@{ Page="(error)"; Status="SKIPPED - $($_.Exception.Message)"; StatusCode=$null })
}

# ============================================================
# PHASE 12: RPC FUNCTIONAL SMOKE TEST (real payload, opt-in)
#
# Unlike Phase 9 (which only checks a function is deployed/reachable
# via OPTIONS/GET), this phase actually INVOKES key business RPCs with
# a real, valid payload built from real rows already in your DB - the
# same way the frontend does it. This is what catches bugs like
# "finished carton not found" (a camelCase/snake_case key mismatch
# between the frontend payload and the SQL function) that a plain
# reachability check cannot see.
#
# OFF by default because it can mutate real data (e.g. fn_create_invoice
# creates a real invoice row and deducts real stock). Run with
# -RunRpcSmokeTest to enable. Each RPC tested here is documented with
# what real-world side effect it has.
# ============================================================
Write-Host ""
Write-Host "===== PHASE 12: RPC FUNCTIONAL SMOKE TEST (real payload) =====" -ForegroundColor Cyan

if (-not $RunRpcSmokeTest) {
    Write-Host "  Skipped (default off - pass -RunRpcSmokeTest to enable)." -ForegroundColor DarkYellow
    $RpcSmokeResults.Add([PSCustomObject]@{ Rpc="(all)"; Status="SKIPPED - not requested (-RunRpcSmokeTest)"; StatusCode=$null; DurationMs=0; SideEffect="" })
}
elseif (-not $SupaUrl -or -not $SupaAnon) {
    Write-Host "  Supabase URL/key nahi mile - RPC smoke test skip." -ForegroundColor DarkYellow
    $RpcSmokeResults.Add([PSCustomObject]@{ Rpc="(all)"; Status="SKIPPED - .env / Supabase URL-key nahi mila"; StatusCode=$null; DurationMs=0; SideEffect="" })
}
else {
    function Invoke-SupabaseRpc {
        param([string]$FnName, [hashtable]$Payload)
        $url = "$SupaUrl/rest/v1/rpc/$FnName"
        $headers = @{ apikey = $SupaAnon; Authorization = "Bearer $SupaAnon"; "Content-Type" = "application/json" }
        $bodyJson = $Payload | ConvertTo-Json -Depth 8
        return Test-HttpEndpoint -Url $url -Method "POST" -Headers $headers -Body $bodyJson -TimeoutSec 15
    }

    function Get-OneRow {
        param([string]$Table, [string]$Filter = "")
        $url = "$SupaUrl/rest/v1/$Table`?select=*&limit=1$Filter"
        try {
            $resp = Invoke-RestMethod -Uri $url -Method Get -Headers @{ apikey = $SupaAnon; Authorization = "Bearer $SupaAnon" } -TimeoutSec 10 -ErrorAction Stop
            if ($resp -and $resp.Count -gt 0) { return $resp[0] }
        } catch {}
        return $null
    }

    # --- fn_create_invoice: needs a real customer + a real finished_carton with stock ---
    Write-Host "  -> Testing fn_create_invoice (creates a REAL invoice, deducts REAL stock)..." -ForegroundColor Yellow
    $testCustomer = Get-OneRow -Table "customers"
    $testCarton   = Get-OneRow -Table "finished_cartons" -Filter "&stock_qty=gt.0&order=stock_qty.desc"

    if (-not $testCustomer -or -not $testCarton) {
        Write-Host "     SKIPPED - no customer or no in-stock finished_carton found to test with." -ForegroundColor DarkYellow
        $RpcSmokeResults.Add([PSCustomObject]@{ Rpc="fn_create_invoice"; Status="SKIPPED - no test data available (need >=1 customer and >=1 finished_carton with stock_qty > 0)"; StatusCode=$null; DurationMs=0; SideEffect="none (skipped)" })
    }
    else {
        $unitPrice = if ($testCarton.cost_per_carton) { [double]$testCarton.cost_per_carton } else { 1 }
        $payload = @{
            p_customer_id = $testCustomer.id
            p_lines = @(
                @{
                    itemId = $testCarton.id
                    item_id = $testCarton.id
                    qty = 1
                    unitPrice = $unitPrice
                    unit_price = $unitPrice
                    priceSourceNote = "RPC smoke test (Run-GhaniFoods-Testing.ps1)"
                    price_source_note = "RPC smoke test (Run-GhaniFoods-Testing.ps1)"
                }
            )
        }
        $r = Invoke-SupabaseRpc -FnName "fn_create_invoice" -Payload $payload
        $verdict = if ($r.Status -eq "REACHABLE" -and $r.StatusCode -lt 300) { "WORKING (real invoice created - verify/delete it manually if this was not intended)" }
                   else { "FAILED (HTTP $($r.StatusCode))" }
        Write-Host "     $verdict" -ForegroundColor $(if ($verdict -like "WORKING*") { "Green" } else { "Red" })
        $RpcSmokeResults.Add([PSCustomObject]@{
            Rpc = "fn_create_invoice"
            Status = $verdict
            StatusCode = $r.StatusCode
            DurationMs = $r.DurationMs
            SideEffect = "Creates 1 real invoice for customer '$($testCustomer.id)', deducts 1 unit of stock from finished_carton '$($testCarton.id)' if successful."
        })
    }

    # --- fn_price_lookup: read-only, safe to always run when RunRpcSmokeTest is on ---
    if ($testCustomer -and $testCarton) {
        Write-Host "  -> Testing fn_price_lookup (read-only)..." -ForegroundColor Yellow
        $r2 = Invoke-SupabaseRpc -FnName "fn_price_lookup" -Payload @{ p_customer_id = $testCustomer.id; p_item_id = $testCarton.id }
        $verdict2 = if ($r2.Status -eq "REACHABLE" -and $r2.StatusCode -lt 300) { "WORKING" } else { "FAILED (HTTP $($r2.StatusCode))" }
        Write-Host "     $verdict2" -ForegroundColor $(if ($verdict2 -eq "WORKING") { "Green" } else { "Red" })
        $RpcSmokeResults.Add([PSCustomObject]@{ Rpc="fn_price_lookup"; Status=$verdict2; StatusCode=$r2.StatusCode; DurationMs=$r2.DurationMs; SideEffect="none (read-only)" })
    }

    Write-Host "  RPC smoke test done. Working: $(($RpcSmokeResults | Where-Object Status -like 'WORKING*').Count) / $($RpcSmokeResults.Count)" -ForegroundColor Gray
}

$SW.Stop()


# ============================================================
# BUILD SUMMARY
# ============================================================
$TotalPass = ($BuildResults | Where-Object Status -eq "PASS").Count
$TotalFail = ($BuildResults | Where-Object Status -eq "FAIL").Count
$HighSeverity = ($Findings | Where-Object Severity -eq "HIGH").Count
$MedSeverity  = ($Findings | Where-Object Severity -eq "MEDIUM").Count
$LowSeverity  = ($Findings | Where-Object Severity -eq "LOW").Count
$SuspectFns   = ($FunctionStats | Where-Object Status -eq "SUSPECT").Count
$BrokenFns    = ($FunctionStats | Where-Object Status -eq "BROKEN").Count
$OkFns        = ($FunctionStats | Where-Object Status -eq "OK").Count

$BackendApiFailCount = ($BackendApiResults | Where-Object { $_.Status -match 'NOT WORKING|SERVER ERROR|DID NOT START' }).Count
$RpcSmokeFailCount   = ($RpcSmokeResults | Where-Object { $_.Status -like 'FAILED*' }).Count

$OverallStatus = if ($TotalFail -gt 0 -or $BrokenFns -gt 0 -or $HighSeverity -gt 0 -or $BackendApiFailCount -gt 0 -or $RpcSmokeFailCount -gt 0) { "NEEDS ATTENTION" }
                 elseif ($MedSeverity -gt 0 -or $SuspectFns -gt 0) { "PASS WITH WARNINGS" }
                 else { "PASS" }

# ============================================================
# WRITE JSON REPORT
# ============================================================
$JsonObject = [ordered]@{
    project        = "GhaniFoods"
    generatedAt    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    durationSec    = [int]$SW.Elapsed.TotalSeconds
    overallStatus  = $OverallStatus
    summary        = [ordered]@{
        filesScanned      = $CodeFiles.Count
        totalFindings     = $Findings.Count
        highSeverity      = $HighSeverity
        mediumSeverity    = $MedSeverity
        lowSeverity       = $LowSeverity
        functionsScanned  = $FunctionStats.Count
        functionsOk       = $OkFns
        functionsSuspect  = $SuspectFns
        functionsBroken   = $BrokenFns
        buildStepsPass    = $TotalPass
        buildStepsFail    = $TotalFail
        backendApiWorking = ($BackendApiResults | Where-Object Status -eq 'WORKING').Count
        backendApiTotal   = $BackendApiResults.Count
        frontendPagesOk   = ($FrontendPageResults | Where-Object Status -eq 'LOADS OK').Count
        frontendPagesTotal = $FrontendPageResults.Count
        rpcSmokeTestRun    = [bool]$RunRpcSmokeTest
        rpcSmokeWorking    = ($RpcSmokeResults | Where-Object Status -like 'WORKING*').Count
        rpcSmokeFailed     = $RpcSmokeFailCount
        rpcSmokeTotal      = $RpcSmokeResults.Count
    }
    alphaTesting   = $Findings
    functionAudit  = $FunctionStats
    betaTesting    = $BuildResults
    uatChecklist   = $UatChecklist
    buttonAudit    = $ButtonFindings
    domainModel    = [ordered]@{
        entities = $Entities
        mermaidErDiagram = $MermaidEr.ToString()
    }
    sequenceDiagrams = $SequenceDiagrams
    navigationFlowDiagram = $FlowSb.ToString()
    backendApiLiveTest    = $BackendApiResults
    supabaseFunctionsLiveTest = $SupabaseFnResults
    databaseTest          = $DbTestResults
    frontendPagesLiveTest = $FrontendPageResults
    rpcFunctionalSmokeTest = $RpcSmokeResults
}
$JsonObject | ConvertTo-Json -Depth 8 | Out-File -FilePath $JsonPath -Encoding utf8

# ============================================================
# WRITE TXT REPORT
# ============================================================
$Txt = New-Object System.Collections.Generic.List[string]
$Txt.Add("============================================================")
$Txt.Add(" GHANIFOODS - FULL SYSTEM TESTING REPORT")
$Txt.Add(" Generated : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")")
$Txt.Add(" Duration  : $([int]$SW.Elapsed.TotalSeconds)s")
$Txt.Add(" Overall   : $OverallStatus")
$Txt.Add("============================================================")
$Txt.Add("")
$Txt.Add("SUMMARY")
$Txt.Add("------------------------------------------------------------")
$Txt.Add("Files scanned          : $($CodeFiles.Count)")
$Txt.Add("Total static findings  : $($Findings.Count)  (High=$HighSeverity, Medium=$MedSeverity, Low=$LowSeverity)")
$Txt.Add("Functions scanned      : $($FunctionStats.Count)  (OK=$OkFns, Suspect=$SuspectFns, Broken=$BrokenFns)")
$Txt.Add("Build steps            : Pass=$TotalPass, Fail=$TotalFail")
$Txt.Add("Backend API (live)     : $(($BackendApiResults | Where-Object Status -eq 'WORKING').Count) / $($BackendApiResults.Count) working")
$Txt.Add("Frontend pages (live)  : $(($FrontendPageResults | Where-Object Status -eq 'LOADS OK').Count) / $($FrontendPageResults.Count) loading OK")
$Txt.Add("RPC smoke test (real)  : $(if ($RunRpcSmokeTest) { "$(($RpcSmokeResults | Where-Object Status -like 'WORKING*').Count) / $($RpcSmokeResults.Count) working" } else { "NOT RUN (pass -RunRpcSmokeTest to enable)" })")
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 1: ALPHA TESTING - STATIC CODE FINDINGS")
$Txt.Add("============================================================")
if ($Findings.Count -eq 0) {
    $Txt.Add("Koi static issue nahi mila. Clean.")
} else {
    foreach ($grp in ($Findings | Group-Object File | Sort-Object Name)) {
        $Txt.Add("")
        $Txt.Add("FILE: $($grp.Name)")
        foreach ($f in ($grp.Group | Sort-Object Line)) {
            $Txt.Add("  [Line $($f.Line)] [$($f.Severity)] $($f.Category)")
            $Txt.Add("    -> $($f.Snippet)")
        }
    }
}
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 1b: FUNCTION / LOGIC AUDIT")
$Txt.Add("============================================================")
$brokenOrSuspect = $FunctionStats | Where-Object { $_.Status -ne "OK" }
if ($brokenOrSuspect.Count -eq 0) {
    $Txt.Add("Sab functions OK dikh rahe hain (basic static check ke mutabiq).")
} else {
    foreach ($fn in ($brokenOrSuspect | Sort-Object File, Line)) {
        $Txt.Add("  [$($fn.Status)] $($fn.File) :: $($fn.Function)() [Line $($fn.Line)] - $($fn.Reason)")
    }
}
$Txt.Add("")
$Txt.Add("Total functions scanned: $($FunctionStats.Count) (OK=$OkFns, Suspect=$SuspectFns, Broken=$BrokenFns)")
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 2: BETA TESTING - BUILD / TYPECHECK RESULTS")
$Txt.Add("============================================================")
foreach ($b in $BuildResults) {
    $Txt.Add("")
    $Txt.Add("[$($b.Status)] $($b.Step)  ($($b.DurationMs) ms)")
    if ($b.Status -eq "FAIL" -and $b.Output) {
        $Txt.Add("  Output (last 40 lines):")
        $outLines = $b.Output -split "`r?`n" | Select-Object -Last 40
        foreach ($ol in $outLines) { $Txt.Add("    $ol") }
    }
}
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 3: UAT CHECKLIST (manual sign-off required)")
$Txt.Add("============================================================")
foreach ($u in $UatChecklist) {
    $Txt.Add("  [ ] $($u.Flow)")
}
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 4: BUTTON / CLICK-HANDLER AUDIT (heuristic, static)")
$Txt.Add("============================================================")
if ($ButtonFindings.Count -eq 0) {
    $Txt.Add("Koi button issue static scan me nahi mila (real click-testing ke liye Playwright/Cypress chahiye).")
} else {
    foreach ($grp in ($ButtonFindings | Group-Object File | Sort-Object Name)) {
        $Txt.Add("")
        $Txt.Add("FILE: $($grp.Name)")
        foreach ($b in ($grp.Group | Sort-Object Line)) {
            $Txt.Add("  [Line $($b.Line)] [$($b.Severity)] $($b.Issue)")
            $Txt.Add("    -> $($b.Snippet)")
        }
    }
}
$Txt.Add("")
$Txt.Add("NOTE: Ye static-code heuristic hai - actual browser me click karke test nahi hua. 'LOW' severity items")
$Txt.Add("      me handler import se aa sakta hai, false-positive ho sakta hai.")
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 5: DOMAIN MODEL (entities extracted from types)")
$Txt.Add("============================================================")
foreach ($e in $Entities) {
    $Txt.Add("")
    $Txt.Add("ENTITY: $($e.Name)")
    foreach ($f in $e.Fields) {
        $opt = if ($f.Optional) { "(optional)" } else { "" }
        $Txt.Add("    - $($f.Name): $($f.Type) $opt")
    }
}
$Txt.Add("")
$Txt.Add("Mermaid ER Diagram source (paste in https://mermaid.live to view):")
$Txt.Add("------------------------------------------------------------")
$Txt.Add($MermaidEr.ToString())
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 6: SEQUENCE DIAGRAMS (per module)")
$Txt.Add("============================================================")
foreach ($sd in $SequenceDiagrams) {
    $Txt.Add("")
    $Txt.Add("MODULE: $($sd.Module)")
    $Txt.Add("------------------------------------------------------------")
    $Txt.Add($sd.Mermaid)
}
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 7: NAVIGATION / FLOW DIAGRAM")
$Txt.Add("============================================================")
$Txt.Add($FlowSb.ToString())
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 8: BACKEND API LIVE TEST (apps/backend Express server)")
$Txt.Add("============================================================")
foreach ($b in $BackendApiResults) {
    $Txt.Add("  [$($b.Status)] $($b.Method) $($b.Route)  -> HTTP $($b.StatusCode)  ($($b.DurationMs) ms)")
}
$WorkingCount = ($BackendApiResults | Where-Object Status -eq 'WORKING').Count
$Txt.Add("")
$Txt.Add("Summary: $WorkingCount / $($BackendApiResults.Count) routes WORKING")
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 9: SUPABASE EDGE FUNCTIONS LIVE TEST")
$Txt.Add("============================================================")
foreach ($s in $SupabaseFnResults) {
    $Txt.Add("  [$($s.Status)] $($s.Function)  -> HTTP $($s.StatusCode)  ($($s.DurationMs) ms)")
}
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 10: DATABASE CONNECTIVITY TEST")
$Txt.Add("============================================================")
foreach ($d in $DbTestResults) {
    $Txt.Add("  [$($d.Status)] $($d.Check)  -> HTTP $($d.StatusCode)")
}
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 11: FRONTEND PAGES LIVE TEST (next start)")
$Txt.Add("============================================================")
foreach ($p in $FrontendPageResults) {
    $Txt.Add("  [$($p.Status)] $($p.Page)  -> HTTP $($p.StatusCode)")
}
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("PHASE 12: RPC FUNCTIONAL SMOKE TEST (real payload, opt-in)")
$Txt.Add("============================================================")
if (-not $RunRpcSmokeTest) {
    $Txt.Add("  NOT RUN - pass -RunRpcSmokeTest to enable. This phase calls real RPCs")
    $Txt.Add("  (e.g. fn_create_invoice) with real sample data, the same shape the")
    $Txt.Add("  frontend sends, to catch functional bugs a reachability check misses.")
    $Txt.Add("  WARNING: it can create real rows / mutate real data - see per-RPC")
    $Txt.Add("  SideEffect notes in the JSON report before enabling on production data.")
} else {
    foreach ($rp in $RpcSmokeResults) {
        $Txt.Add("  [$($rp.Status)] $($rp.Rpc)  -> HTTP $($rp.StatusCode)  ($($rp.DurationMs) ms)")
        if ($rp.SideEffect) { $Txt.Add("      Side effect: $($rp.SideEffect)") }
    }
}
$Txt.Add("")

$Txt.Add("============================================================")
$Txt.Add("END OF REPORT")
$Txt.Add("============================================================")

Write-Utf8NoBom -Path $TxtPath -Content ($Txt -join "`r`n")

# ============================================================
# WRITE HTML (for PDF conversion) REPORT
# ============================================================
function Esc([string]$s) {
    if ($null -eq $s) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($s)
}

$statusColor = @{ PASS="#16a34a"; FAIL="#dc2626"; INFO="#2563eb"; OK="#16a34a"; SUSPECT="#d97706"; BROKEN="#dc2626"; HIGH="#dc2626"; MEDIUM="#d97706"; LOW="#6b7280" }

$Html = New-Object System.Text.StringBuilder
[void]$Html.Append("<html><head><meta charset='utf-8'><title>GhaniFoods Testing Report</title><style>")
[void]$Html.Append("body{font-family:Segoe UI,Arial,sans-serif;font-size:12px;margin:24px;color:#111}")
[void]$Html.Append("h1{font-size:20px} h2{font-size:16px;margin-top:28px;border-bottom:2px solid #ddd;padding-bottom:4px}")
[void]$Html.Append("table{border-collapse:collapse;width:100%;margin-top:8px} th,td{border:1px solid #ccc;padding:4px 6px;text-align:left;font-size:11px}")
[void]$Html.Append("th{background:#f3f4f6} .badge{padding:2px 6px;border-radius:4px;color:#fff;font-weight:bold}")
[void]$Html.Append("</style></head><body>")
[void]$Html.Append("<h1>GhaniFoods - Full System Testing Report</h1>")
[void]$Html.Append("<p>Generated: $(Esc (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) | Duration: $([int]$SW.Elapsed.TotalSeconds)s | Overall: <b>$(Esc $OverallStatus)</b></p>")

[void]$Html.Append("<h2>Summary</h2><table>")
[void]$Html.Append("<tr><th>Metric</th><th>Value</th></tr>")
[void]$Html.Append("<tr><td>Files scanned</td><td>$($CodeFiles.Count)</td></tr>")
[void]$Html.Append("<tr><td>Static findings (High/Med/Low)</td><td>$($Findings.Count) ($HighSeverity/$MedSeverity/$LowSeverity)</td></tr>")
[void]$Html.Append("<tr><td>Functions (OK/Suspect/Broken)</td><td>$($FunctionStats.Count) ($OkFns/$SuspectFns/$BrokenFns)</td></tr>")
[void]$Html.Append("<tr><td>Build steps (Pass/Fail)</td><td>$TotalPass / $TotalFail</td></tr>")
[void]$Html.Append("<tr><td>Backend API (live-tested)</td><td>$(($BackendApiResults | Where-Object Status -eq 'WORKING').Count) / $($BackendApiResults.Count) working</td></tr>")
[void]$Html.Append("<tr><td>Frontend pages (live-tested)</td><td>$(($FrontendPageResults | Where-Object Status -eq 'LOADS OK').Count) / $($FrontendPageResults.Count) loading OK</td></tr>")
[void]$Html.Append("<tr><td>RPC smoke test (real payload)</td><td>$(if ($RunRpcSmokeTest) { "$(($RpcSmokeResults | Where-Object Status -like 'WORKING*').Count) / $($RpcSmokeResults.Count) working" } else { "NOT RUN (-RunRpcSmokeTest)" })</td></tr>")
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 1: Alpha Testing - Static Findings</h2><table>")
[void]$Html.Append("<tr><th>File</th><th>Line</th><th>Severity</th><th>Category</th><th>Snippet</th></tr>")
foreach ($f in ($Findings | Sort-Object File, Line)) {
    $c = $statusColor[$f.Severity]
    [void]$Html.Append("<tr><td>$(Esc $f.File)</td><td>$($f.Line)</td><td><span class='badge' style='background:$c'>$(Esc $f.Severity)</span></td><td>$(Esc $f.Category)</td><td><code>$(Esc $f.Snippet)</code></td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 1b: Function / Logic Audit (non-OK only)</h2><table>")
[void]$Html.Append("<tr><th>File</th><th>Function</th><th>Line</th><th>Status</th><th>Reason</th></tr>")
foreach ($fn in ($FunctionStats | Where-Object { $_.Status -ne "OK" } | Sort-Object File, Line)) {
    $c = $statusColor[$fn.Status]
    [void]$Html.Append("<tr><td>$(Esc $fn.File)</td><td>$(Esc $fn.Function)</td><td>$($fn.Line)</td><td><span class='badge' style='background:$c'>$(Esc $fn.Status)</span></td><td>$(Esc $fn.Reason)</td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 2: Beta Testing - Build/Typecheck</h2><table>")
[void]$Html.Append("<tr><th>Step</th><th>Status</th><th>Duration(ms)</th></tr>")
foreach ($b in $BuildResults) {
    $c = $statusColor[$b.Status]
    if (-not $c) { $c = "#2563eb" }
    [void]$Html.Append("<tr><td>$(Esc $b.Step)</td><td><span class='badge' style='background:$c'>$(Esc $b.Status)</span></td><td>$($b.DurationMs)</td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 3: UAT Checklist</h2><table>")
[void]$Html.Append("<tr><th>Flow</th><th>Status</th></tr>")
foreach ($u in $UatChecklist) {
    [void]$Html.Append("<tr><td>$(Esc $u.Flow)</td><td>$(Esc $u.Status)</td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 4: Button / Click-Handler Audit (heuristic, static scan)</h2>")
[void]$Html.Append("<p style='color:#6b7280'>Ye static code scan hai, actual browser click-testing nahi. LOW severity = false positive ho sakta hai.</p>")
[void]$Html.Append("<table><tr><th>File</th><th>Line</th><th>Severity</th><th>Issue</th><th>Snippet</th></tr>")
foreach ($b in ($ButtonFindings | Sort-Object File, Line)) {
    $c = $statusColor[$b.Severity]
    [void]$Html.Append("<tr><td>$(Esc $b.File)</td><td>$($b.Line)</td><td><span class='badge' style='background:$c'>$(Esc $b.Severity)</span></td><td>$(Esc $b.Issue)</td><td><code>$(Esc $b.Snippet)</code></td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 5: Domain Model (ER Diagram)</h2>")
[void]$Html.Append("<div class='mermaid'>")
[void]$Html.Append([System.Net.WebUtility]::HtmlEncode($MermaidEr.ToString()))
[void]$Html.Append("</div>")
[void]$Html.Append("<table><tr><th>Entity</th><th>Fields</th></tr>")
foreach ($e in $Entities) {
    $fieldStr = ($e.Fields | ForEach-Object { "$($_.Name): $($_.Type)" }) -join ", "
    [void]$Html.Append("<tr><td>$(Esc $e.Name)</td><td>$(Esc $fieldStr)</td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 6: Sequence Diagrams (per module)</h2>")
foreach ($sd in $SequenceDiagrams) {
    [void]$Html.Append("<h3 style='font-size:13px'>Module: $(Esc $sd.Module)</h3>")
    [void]$Html.Append("<div class='mermaid'>")
    [void]$Html.Append([System.Net.WebUtility]::HtmlEncode($sd.Mermaid))
    [void]$Html.Append("</div>")
}

[void]$Html.Append("<h2>Phase 7: Navigation / Flow Diagram</h2>")
[void]$Html.Append("<div class='mermaid'>")
[void]$Html.Append([System.Net.WebUtility]::HtmlEncode($FlowSb.ToString()))
[void]$Html.Append("</div>")

$liveColor = @{ WORKING="#16a34a"; "LOADS OK"="#16a34a"; "DEPLOYED / REACHABLE"="#16a34a"; "DATABASE REACHABLE"="#16a34a"; "TABLE OK"="#16a34a"; "TABLE EXISTS (RLS/auth blocked - expected)"="#2563eb" }

[void]$Html.Append("<h2>Phase 8: Backend API Live Test (apps/backend Express server)</h2>")
[void]$Html.Append("<table><tr><th>Method</th><th>Route</th><th>HTTP Status</th><th>Result</th><th>ms</th></tr>")
foreach ($b in $BackendApiResults) {
    $c = $liveColor[$b.Status]; if (-not $c) { $c = "#dc2626" }
    [void]$Html.Append("<tr><td>$(Esc $b.Method)</td><td>$(Esc $b.Route)</td><td>$($b.StatusCode)</td><td><span class='badge' style='background:$c'>$(Esc $b.Status)</span></td><td>$($b.DurationMs)</td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 9: Supabase Edge Functions Live Test</h2>")
[void]$Html.Append("<table><tr><th>Function</th><th>HTTP Status</th><th>Result</th><th>ms</th></tr>")
foreach ($s in $SupabaseFnResults) {
    $c = $liveColor[$s.Status]; if (-not $c) { $c = "#dc2626" }
    [void]$Html.Append("<tr><td>$(Esc $s.Function)</td><td>$($s.StatusCode)</td><td><span class='badge' style='background:$c'>$(Esc $s.Status)</span></td><td>$($s.DurationMs)</td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 10: Database Connectivity Test</h2>")
[void]$Html.Append("<table><tr><th>Check</th><th>HTTP Status</th><th>Result</th></tr>")
foreach ($d in $DbTestResults) {
    $c = $liveColor[$d.Status]; if (-not $c) { $c = "#dc2626" }
    [void]$Html.Append("<tr><td>$(Esc $d.Check)</td><td>$($d.StatusCode)</td><td><span class='badge' style='background:$c'>$(Esc $d.Status)</span></td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 11: Frontend Pages Live Test (next start)</h2>")
[void]$Html.Append("<table><tr><th>Page</th><th>HTTP Status</th><th>Result</th><th>ms</th></tr>")
foreach ($p in $FrontendPageResults) {
    $c = $liveColor[$p.Status]; if (-not $c) { $c = "#dc2626" }
    [void]$Html.Append("<tr><td>$(Esc $p.Page)</td><td>$($p.StatusCode)</td><td><span class='badge' style='background:$c'>$(Esc $p.Status)</span></td><td>$($p.DurationMs)</td></tr>")
}
[void]$Html.Append("</table>")

[void]$Html.Append("<h2>Phase 12: RPC Functional Smoke Test (real payload, opt-in)</h2>")
if (-not $RunRpcSmokeTest) {
    [void]$Html.Append("<p style='color:#6b7280'>NOT RUN - pass -RunRpcSmokeTest to enable. This phase invokes real RPCs (e.g. fn_create_invoice) with a real payload built from real DB rows, catching functional/key-mismatch bugs that a plain reachability check (Phase 9) cannot see. It can mutate real data - see per-RPC side effects before enabling on production.</p>")
}
else {
    [void]$Html.Append("<table><tr><th>RPC</th><th>HTTP Status</th><th>Result</th><th>ms</th><th>Side effect</th></tr>")
    foreach ($rp in $RpcSmokeResults) {
        $c = if ($rp.Status -like 'WORKING*') { "#16a34a" } elseif ($rp.Status -like 'SKIPPED*') { "#6b7280" } else { "#dc2626" }
        [void]$Html.Append("<tr><td>$(Esc $rp.Rpc)</td><td>$($rp.StatusCode)</td><td><span class='badge' style='background:$c'>$(Esc $rp.Status)</span></td><td>$($rp.DurationMs)</td><td>$(Esc $rp.SideEffect)</td></tr>")
    }
    [void]$Html.Append("</table>")
}

[void]$Html.Append("<script src='https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js'></script>")
[void]$Html.Append("<script>try{mermaid.initialize({startOnLoad:true,securityLevel:'loose'});}catch(e){}</script>")

[void]$Html.Append("</body></html>")
Write-Utf8NoBom -Path $HtmlPath -Content $Html.ToString()

# ============================================================
# CONVERT HTML -> PDF (Edge / Chrome headless)
# ============================================================
$BrowserPaths = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)
$BrowserExe = $BrowserPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

$PdfGenerated = $false
if ($BrowserExe) {
    Write-Host ""
    Write-Host "  Generating PDF via: $BrowserExe" -ForegroundColor Yellow
    $printArgs = @(
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--virtual-time-budget=8000",
        "--print-to-pdf=`"$PdfPath`"",
        "`"$HtmlPath`""
    )
    try {
        Start-Process -FilePath $BrowserExe -ArgumentList $printArgs -Wait -WindowStyle Hidden
        if (Test-Path $PdfPath) { $PdfGenerated = $true }
    } catch {
        Write-Host "  PDF generation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host ""
    Write-Host "  Edge/Chrome nahi mila -> PDF skip. HTML report available: $HtmlPath" -ForegroundColor DarkYellow
    Write-Host "  (HTML file ko browser me khol kar Ctrl+P > Save as PDF kar sakte hain)" -ForegroundColor DarkYellow
}

# ============================================================
# FINAL CONSOLE SUMMARY
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " TESTING COMPLETE - OVERALL: $OverallStatus" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " TXT  : $TxtPath"
Write-Host " JSON : $JsonPath"
if ($PdfGenerated) { Write-Host " PDF  : $PdfPath" -ForegroundColor Green }
else { Write-Host " PDF  : NOT generated (Edge/Chrome missing) - HTML fallback: $HtmlPath" -ForegroundColor DarkYellow }
Write-Host ""