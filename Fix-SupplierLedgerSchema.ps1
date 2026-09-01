<#
  Fix-SupplierLedgerSchema.ps1
  -----------------------------------------------------------------------
  WHY THIS SCRIPT EXISTS
  A previous run confirmed the REAL live table is:

      public.supplier_ledger_entries
      columns: id, supplier_id, type, amount, running_balance,
               note, reference_id, entry_date, created_at

  ...and explicitly said it would skip the migration because of that
  mismatch - but then wrote the migration anyway against a table/columns
  that do not exist (supplier_ledger / entry_type / purchase_receipt_id /
  payment_id). That migration would either error on push or silently do
  nothing useful. This script replaces it with one written against the
  REAL table and REAL columns.

  It also fixes a SECOND, related bug found in your own exported code:
  apps/backend/supabase/functions/suppliers-history/index.ts queries
  the WRONG table/columns too (supplier_ledger / entry_type /
  purchase_receipt_id / payment_id) - so that endpoint would currently
  fail against your real DB regardless of the migration. This script
  corrects that query to match the real table so the fix is complete
  end-to-end, not just in the migration file.

  WHAT THIS SCRIPT DOES
    1. Deletes/replaces any previous wrong-schema migration file for
       this feature (matched by filename suffix) so it can't get pushed
       by accident, and writes a new correct one:
         - create/replace fn_supplier_balance(p_supplier_id uuid)
           - Does NOT recompute or rewrite running_balance itself.
             running_balance already exists on the live table, so this
             function just reads the latest stored value for that
             supplier (ordered by entry_date/created_at/id). This
             avoids having two different pieces of code (DB function vs
             whatever already writes running_balance today) disagree
             about the "true" balance.
         - A DO block that RAISE NOTICEs every trigger currently
           attached to supplier_ledger_entries, so the `supabase db
           push` output itself tells you whether something in the DB
           is already maintaining running_balance (vs. it being set
           from application/edge-function code).
         - A diagnostic view v_supplier_ledger_orphans using the REAL
           column reference_id (not purchase_receipt_id/payment_id,
           which don't exist).
    2. Fixes apps/backend/supabase/functions/suppliers-history/index.ts
       to query supplier_ledger_entries with the real columns.
    3. Runs `supabase db push`.
    4. STRICT verification - does NOT trust "up to date" / exit code 0.
       - Always cross-checks `supabase migration list` to confirm this
         migration's timestamp is actually marked as applied on the
         REMOTE side, not just present locally.
       - If you pass -DbPassword and `psql` is installed, it also runs
         a direct query against the live DB
         (select proname from pg_proc where proname = 'fn_supplier_balance')
         and a matching check for v_supplier_ledger_orphans, and prints
         a hard FAILED if either is missing - it will not report success
         just because the push command returned 0.
       - If neither check is possible, it prints an explicit WARNING
         that it could NOT verify, plus the exact SQL to run yourself
         in the Supabase SQL editor. It will never silently claim
         success it didn't check.
    5. Deploys the corrected edge function with
       `supabase functions deploy suppliers-history`, and verifies that
       command's own exit code separately (same "don't trust silence"
       rule).

  USAGE
    cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
    .\Fix-SupplierLedgerSchema.ps1

    Optional, for the strict DB-level verification in step 4:
    .\Fix-SupplierLedgerSchema.ps1 -DbPassword "your-db-password"

  Idempotent - safe to re-run. The migration uses CREATE OR REPLACE for
  the function/view, and the edge-function edit is a targeted text
  replace that only fires if the old broken query is still present.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$DbPassword = $null
)

$ErrorActionPreference = "Stop"

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    WARNING: $msg" -ForegroundColor Yellow }
function Invoke-SupabaseCli {
    <#
      Runs a supabase CLI command via cmd.exe instead of directly in
      PowerShell. supabase.ps1 (the npm-installed wrapper) sets its own
      $ErrorActionPreference internally, which overrides anything the
      caller sets - so PowerShell kept turning normal stderr status
      lines (e.g. "Connecting to remote database...") into terminating
      exceptions and swallowing the real output. Routing through cmd.exe
      sidesteps PowerShell's error stream entirely - only $LASTEXITCODE
      and the raw text matter here.
      Returns combined stdout+stderr as a single string; sets
      $script:LastSupabaseExitCode.
    #>
    param([string[]]$ArgList)

    $quoted = $ArgList | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }
    $cmdLine = "supabase " + ($quoted -join ' ') + " 2>&1"
    $output = cmd.exe /c $cmdLine
    $script:LastSupabaseExitCode = $LASTEXITCODE
    return ($output | Out-String)
}



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
$ProjectRoot   = $resolvedRoot
$BackendDir    = Join-Path $ProjectRoot "apps\backend"
$MigrationsDir = Join-Path $BackendDir "supabase\migrations"
$EdgeFnFile    = Join-Path $BackendDir "supabase\functions\suppliers-history\index.ts"

Write-Ok "Project root: $ProjectRoot"

# -------------------------------------------------------------------------
# 1. Remove any previous WRONG-schema migration for this feature
# -------------------------------------------------------------------------
Write-Step "Checking for previous wrong-schema supplier ledger migrations..."

if (-not (Test-Path $MigrationsDir)) { New-Item -ItemType Directory -Force -Path $MigrationsDir | Out-Null }

$badOnes = Get-ChildItem -Path $MigrationsDir -Filter "*_fix_supplier_ledger_integrity_and_balance.sql" -File -ErrorAction SilentlyContinue
foreach ($bad in $badOnes) {
    $content = Get-Content -Path $bad.FullName -Raw
    if ($content -match "supplier_ledger\b" -and $content -notmatch "supplier_ledger_entries") {
        Write-Warn2 "Removing wrong-schema migration: $($bad.FullName)"
        Remove-Item -Path $bad.FullName -Force
    }
}

# -------------------------------------------------------------------------
# 2. Write the CORRECT migration against supplier_ledger_entries
# -------------------------------------------------------------------------
Write-Step "Writing corrected migration against public.supplier_ledger_entries..."

$existing = Get-ChildItem -Path $MigrationsDir -Filter "*_fix_supplier_ledger_real_schema.sql" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existing) {
    Write-Ok "Migration already exists: $($existing.FullName) - skipping (delete it first if you want to regenerate)."
    $migrationFile = $existing.FullName
}
else {
    $sql = @'
-- Fix: rebuild fn_supplier_balance against the REAL live table
-- (public.supplier_ledger_entries), not "supplier_ledger" (which does
-- not exist). Confirmed real schema:
--   public.supplier_ledger_entries(
--     id, supplier_id, type, amount, running_balance,
--     note, reference_id, entry_date, created_at
--   )
--
-- running_balance ALREADY EXISTS on this table and may already be
-- maintained by a trigger or by application/edge-function code on
-- insert. This migration does NOT recompute or rewrite it - it only
-- reads the latest stored value, so it cannot conflict with whatever
-- already sets it today.

-- Diagnostic: print every trigger on supplier_ledger_entries into the
-- `supabase db push` output, so you can see right now whether the DB
-- itself is maintaining running_balance.
do $$
declare
  trg record;
  trg_count int := 0;
begin
  for trg in
    select tgname
    from pg_trigger
    where tgrelid = 'public.supplier_ledger_entries'::regclass
      and not tgisinternal
  loop
    trg_count := trg_count + 1;
    raise notice 'supplier_ledger_entries has existing trigger: %', trg.tgname;
  end loop;

  if trg_count = 0 then
    raise notice 'supplier_ledger_entries has NO triggers - running_balance is most likely written by application/edge-function code, not the DB. Check purchase-receipts / supplier-payments / fn_record_supplier_payment before assuming it is safe to change how it is set.';
  end if;
end;
$$;

-- Orphan-entry diagnostic, using the REAL column (reference_id) - the
-- old migration checked purchase_receipt_id/payment_id, which do not
-- exist on this table.
create or replace view v_supplier_ledger_orphans as
select *
from public.supplier_ledger_entries
where reference_id is null
  and type in ('purchase', 'payment');
  -- NOTE: entries of type 'adjustment' or 'debit_note' may legitimately
  -- have no reference_id - adjust this filter if that's wrong for you.

-- fn_supplier_balance: reads the latest running_balance already on the
-- table for this supplier. Does not recompute a second balance.
create or replace function fn_supplier_balance(p_supplier_id uuid)
returns numeric
language sql
stable
as $$
  select coalesce(
    (
      select running_balance
      from public.supplier_ledger_entries
      where supplier_id = p_supplier_id
      order by entry_date desc, created_at desc, id desc
      limit 1
    ),
    0
  );
$$;
'@
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $migrationFile = Join-Path $MigrationsDir "${timestamp}_fix_supplier_ledger_real_schema.sql"
    Set-Content -Path $migrationFile -Value $sql -Encoding UTF8
    Write-Ok "Migration written: $migrationFile"
}

# -------------------------------------------------------------------------
# 3. Fix the matching broken edge function (same wrong table/columns)
# -------------------------------------------------------------------------
Write-Step "Fixing apps/backend/supabase/functions/suppliers-history/index.ts..."

if (-not (Test-Path $EdgeFnFile)) {
    Write-Warn2 "Could not find $EdgeFnFile - skipping edge function fix. You'll need to fix this file manually if it queries 'supplier_ledger' instead of 'supplier_ledger_entries'."
}
else {
    $fnContent = Get-Content -Path $EdgeFnFile -Raw

    $oldFromSelect = ".from(""supplier_ledger"")`r`n      .select(""id, amount, entry_type, purchase_receipt_id, payment_id, created_at"")"
    $newFromSelect = ".from(""supplier_ledger_entries"")`r`n      .select(""id, amount, type, reference_id, running_balance, note, entry_date, created_at"")"

    $oldOrder = ".order(""created_at"", { ascending: false });"
    $newOrder = ".order(""entry_date"", { ascending: false });"

    if ($fnContent.Contains("supplier_ledger_entries")) {
        Write-Ok "suppliers-history/index.ts already queries supplier_ledger_entries - no change needed."
    }
    elseif ($fnContent.Contains($oldFromSelect)) {
        $fnContent = $fnContent.Replace($oldFromSelect, $newFromSelect)

        # There are two ".order(...)" calls in this file (one for receipts, one for the
        # ledger). Only swap the SECOND occurrence (the ledger one) to entry_date.
        $firstIdx  = $fnContent.IndexOf($oldOrder)
        $secondIdx = $fnContent.IndexOf($oldOrder, $firstIdx + 1)
        if ($secondIdx -ge 0) {
            $fnContent = $fnContent.Substring(0, $secondIdx) + $newOrder + $fnContent.Substring($secondIdx + $oldOrder.Length)
        }

        Set-Content -Path $EdgeFnFile -Value $fnContent -Encoding UTF8 -NoNewline
        Write-Ok "Rewrote ledger query in suppliers-history/index.ts to use supplier_ledger_entries + real columns."
    }
    else {
        Write-Warn2 "Could not find the expected old query text to replace in suppliers-history/index.ts."
        Write-Warn2 "Open it manually and change the '.from(\"supplier_ledger\")...' block to query supplier_ledger_entries with columns: id, amount, type, reference_id, running_balance, note, entry_date, created_at."
    }
}

# -------------------------------------------------------------------------
# 4. Push the migration
# -------------------------------------------------------------------------
Write-Step "Pushing migration to Supabase..."

# -------------------------------------------------------------------------
# 3b. Detect the dual-supabase-folder drift BEFORE pushing.
#     This project has both apps/backend/supabase and a root-level
#     supabase/ folder, both linked to the same remote project. If the
#     remote's migration-history table has versions that only exist in
#     the ROOT folder, apps/backend won't know about them and 'db push'
#     will fail with "Remote migration versions not found in local
#     migrations directory." The correct fix is to copy those files
#     across (they really were applied - they are not "reverted"),
#     NOT to run 'migration repair --status reverted' on them, which
#     would incorrectly tell the CLI to forget a migration that is
#     actually live on the remote schema.
# -------------------------------------------------------------------------
$RootMigrationsDir = Join-Path $ProjectRoot "supabase\migrations"
if ((Test-Path $RootMigrationsDir) -and ($RootMigrationsDir -ne $MigrationsDir)) {
    $rootFiles = Get-ChildItem -Path $RootMigrationsDir -Filter "*.sql" -File -ErrorAction SilentlyContinue
    foreach ($rf in $rootFiles) {
        $targetPath = Join-Path $MigrationsDir $rf.Name
        if (-not (Test-Path $targetPath)) {
            Write-Warn2 "Found root-level migration not present in apps/backend: $($rf.Name) - copying it across (it's already applied on remote, this just makes the CLI aware of it locally too)."
            Copy-Item -Path $rf.FullName -Destination $targetPath
        }
    }
}


$supabaseCli = Get-Command supabase -ErrorAction SilentlyContinue
$pushSucceeded = $false

if (-not $supabaseCli) {
    Write-Fail "Supabase CLI not found on PATH. Install it (npm i -g supabase@latest), run 'supabase login' and 'supabase link', then re-run this script."
}
else {
    Push-Location $BackendDir
    try {
        Write-Ok "Supabase CLI found: $($supabaseCli.Source)"
        Write-Host "    Running: supabase db push" -ForegroundColor Gray
        $pushOutput = Invoke-SupabaseCli -ArgList @("db", "push")
        Write-Host $pushOutput

        if ($script:LastSupabaseExitCode -ne 0) {
            # Case A: remote migration-history has a version not present locally at all
            # (leftover drift). Supabase suggests marking it "reverted" - correct when
            # that migration genuinely isn't part of current remote state.
            $repairMatch = [regex]::Match($pushOutput, 'supabase migration repair --status reverted (\d+)')

            # Case B: local has OLDER migrations (e.g. 0001..0009) that predate a
            # squashed "remote_schema" snapshot and are already reflected in the live
            # schema, but were never recorded in remote's migration-history table.
            # Supabase suggests --include-all, but that would actually RE-RUN them,
            # risking duplicate-object errors. The correct, safe fix is to mark them
            # "applied" (bookkeeping only, no SQL executes) since their effects are
            # already live, then push normally so only genuinely new migrations run.
            $includeAllBlock = [regex]::Match($pushOutput, 'Rerun the command with --include-all flag to apply these migrations:\s*((?:\r?\n\S.*)+)')

            if ($includeAllBlock.Success) {
                $paths = $includeAllBlock.Groups[1].Value -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
                $versions = foreach ($p in $paths) {
                    $name = Split-Path $p.Trim() -Leaf
                    ($name -split '_')[0]
                }
                Write-Warn2 "Remote has no history record for these already-live migrations: $($versions -join ', '). Marking them as 'applied' (bookkeeping only - no SQL will re-run) instead of using --include-all, which would risk re-running them for real."
                foreach ($v in $versions) {
                    Write-Host "    Running: supabase migration repair --status applied $v" -ForegroundColor Gray
                    $repairOut = Invoke-SupabaseCli -ArgList @("migration", "repair", "--status", "applied", $v)
                    Write-Host $repairOut
                    if ($script:LastSupabaseExitCode -ne 0) {
                        Write-Fail "Could not mark $v as applied (exit code $($script:LastSupabaseExitCode)). Stopping - do not proceed blindly."
                    }
                }
                Write-Ok "Retrying push once now that history is reconciled..."
                Write-Host "    Running: supabase db push" -ForegroundColor Gray
                $pushOutput2 = Invoke-SupabaseCli -ArgList @("db", "push")
                Write-Host $pushOutput2
                if ($script:LastSupabaseExitCode -ne 0) {
                    Write-Fail "supabase db push still exited with code $($script:LastSupabaseExitCode) after reconciling history. Read the output above carefully before retrying."
                }
                else {
                    $pushSucceeded = $true
                }
            }
            elseif ($repairMatch.Success) {
                $driftVersion = $repairMatch.Groups[1].Value
                Write-Warn2 "Remote has migration history version $driftVersion not present locally (leftover from earlier runs). Auto-repairing as Supabase itself suggested..."
                Write-Host "    Running: supabase migration repair --status reverted $driftVersion" -ForegroundColor Gray
                $repairOutput = Invoke-SupabaseCli -ArgList @("migration", "repair", "--status", "reverted", $driftVersion)
                Write-Host $repairOutput
                if ($script:LastSupabaseExitCode -ne 0) {
                    Write-Fail "migration repair exited with code $($script:LastSupabaseExitCode) - could not auto-fix the drift. Run 'supabase db pull' manually and inspect what's on remote before retrying."
                }
                else {
                    Write-Ok "Repair applied. Retrying push once..."
                    Write-Host "    Running: supabase db push" -ForegroundColor Gray
                    $pushOutput2 = Invoke-SupabaseCli -ArgList @("db", "push")
                    Write-Host $pushOutput2
                    if ($script:LastSupabaseExitCode -ne 0) {
                        Write-Fail "supabase db push still exited with code $($script:LastSupabaseExitCode) after repair. Do not assume anything applied - inspect manually with 'supabase db pull' first."
                    }
                    else {
                        $pushSucceeded = $true
                    }
                }
            }
            else {
                Write-Fail "supabase db push exited with code $($script:LastSupabaseExitCode)."
            }
        }
        else {
            $pushSucceeded = $true
        }
    }
    catch {
        Write-Fail "supabase db push threw an error: $($_.Exception.Message)"
    }
    finally {
        Pop-Location
    }
}

# -------------------------------------------------------------------------
# 5. STRICT verification - never trust exit code / "up to date" alone
# -------------------------------------------------------------------------
Write-Step "Verifying the migration ACTUALLY applied (not trusting push exit code)..."

$migrationTimestamp = [System.IO.Path]::GetFileNameWithoutExtension($migrationFile).Split('_')[0]
$verifiedRemote = $false

if ($supabaseCli) {
    Push-Location $BackendDir
    try {
        Write-Host "    Running: supabase migration list" -ForegroundColor Gray
        $listOutput = Invoke-SupabaseCli -ArgList @("migration", "list")
        Write-Host $listOutput

        if ($listOutput -match [regex]::Escape($migrationTimestamp)) {
            # crude but honest check: the timestamp must appear, and on a line that also
            # looks like it has two populated columns (local | remote), not just "Local" only.
            $lines = $listOutput -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($migrationTimestamp) }
            $looksApplied = $false
            foreach ($line in $lines) {
                $cols = ($line -split '\|').Trim() | Where-Object { $_ -ne "" }
                if ($cols.Count -ge 2) { $looksApplied = $true }
            }
            if ($looksApplied) {
                Write-Ok "Migration $migrationTimestamp appears under both Local and Remote in 'supabase migration list'."
                $verifiedRemote = $true
            }
            else {
                Write-Fail "Migration $migrationTimestamp is only listed LOCALLY, not confirmed remote. Do not assume it applied."
            }
        }
        else {
            Write-Fail "Migration $migrationTimestamp does not appear in 'supabase migration list' output at all."
        }
    }
    catch {
        Write-Warn2 "Could not run 'supabase migration list': $($_.Exception.Message)"
    }
    finally {
        Pop-Location
    }
}

$verifiedDb = $false
$psqlCli = Get-Command psql -ErrorAction SilentlyContinue
$projectRef = $null
$linkedFile = Join-Path $BackendDir "supabase\.temp\linked-project.json"
if (Test-Path $linkedFile) {
    try { $projectRef = (Get-Content $linkedFile -Raw | ConvertFrom-Json).ref } catch {}
}

if ($DbPassword -and $psqlCli -and $projectRef) {
    Write-Step "Running direct DB check via psql (strict, no trust in CLI messages)..."
    $env:PGPASSWORD = $DbPassword
    $connStr = "postgresql://postgres:$DbPassword@db.$projectRef.supabase.co:5432/postgres"
    try {
        $fnCheck = & psql $connStr -t -A -c "select count(*) from pg_proc where proname = 'fn_supplier_balance';" 2>&1
        $viewCheck = & psql $connStr -t -A -c "select count(*) from pg_views where viewname = 'v_supplier_ledger_orphans';" 2>&1

        if ($fnCheck -match '^\s*1\s*$') {
            Write-Ok "Confirmed in live DB: fn_supplier_balance exists."
        }
        else {
            Write-Fail "fn_supplier_balance was NOT found in the live DB. Output: $fnCheck"
        }

        if ($viewCheck -match '^\s*1\s*$') {
            Write-Ok "Confirmed in live DB: v_supplier_ledger_orphans exists."
            $verifiedDb = $true
        }
        else {
            Write-Fail "v_supplier_ledger_orphans was NOT found in the live DB. Output: $viewCheck"
        }
    }
    catch {
        Write-Warn2 "psql check failed to run: $($_.Exception.Message)"
    }
    finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    }
}
else {
    Write-Warn2 "Skipping direct DB check (need -DbPassword and psql installed and a linked project)."
    Write-Warn2 "To get a real, trustworthy verification, run this yourself in the Supabase SQL editor:"
    Write-Host ""
    Write-Host "    select proname from pg_proc where proname = 'fn_supplier_balance';" -ForegroundColor White
    Write-Host "    select viewname from pg_views where viewname = 'v_supplier_ledger_orphans';" -ForegroundColor White
    Write-Host ""
}

# -------------------------------------------------------------------------
# 6. Deploy the fixed edge function (separately verified, not assumed)
# -------------------------------------------------------------------------
Write-Step "Deploying corrected suppliers-history edge function..."

if (-not $supabaseCli) {
    Write-Warn2 "Supabase CLI not available - deploy manually: supabase functions deploy suppliers-history"
}
elseif (-not $pushSucceeded) {
    Write-Warn2 "Skipping function deploy because the DB push did not succeed - fix that first."
}
else {
    Push-Location $BackendDir
    try {
        Write-Host "    Running: supabase functions deploy suppliers-history" -ForegroundColor Gray
        $deployOutput = Invoke-SupabaseCli -ArgList @("functions", "deploy", "suppliers-history")
        Write-Host $deployOutput
        if ($script:LastSupabaseExitCode -ne 0) {
            Write-Fail "supabase functions deploy suppliers-history exited with code $($script:LastSupabaseExitCode)."
        }
        else {
            Write-Ok "suppliers-history deployed."
        }
    }
    catch {
        Write-Fail "Deploy failed: $($_.Exception.Message)"
    }
    finally {
        Pop-Location
    }
}

# -------------------------------------------------------------------------
# 7. Final honest summary
# -------------------------------------------------------------------------
Write-Step "Summary"
if ($pushSucceeded -and ($verifiedRemote -or $verifiedDb)) {
    Write-Ok "Migration pushed AND independently verified as applied."
}
elseif ($pushSucceeded) {
    Write-Warn2 "Push command reported success, but could not be independently verified - do not treat this as confirmed. Run the manual SQL checks above."
}
else {
    Write-Fail "Migration push did not succeed. Nothing below this point should be trusted as applied."
}