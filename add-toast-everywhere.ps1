#
# add-toast-everywhere.ps1
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# What this does:
#   Aapke project mein toast system pehle se "sonner" library se ban raha hai
#   (apps/frontend/components/ui/theme-toaster.tsx -> <Toaster position="top-right" .../>,
#   jo apps/frontend/app/layout.tsx mein mount hai). 14 pages mein already
#   toast.success()/toast.error() calls maujood hain - unko is script mein
#   CHHEDA NAHI GAYA (skip ho jayenge, "already has toast" print hoga).
#
#   Jin pages mein user-facing action hota hai lekin abhi tak koi toast nahi
#   tha, wahan ye script add karti hai:
#
#   1. theme-toaster.tsx  -> confirm/force position="top-right" (idempotent)
#   2. (auth)/login/page.tsx -> sonner import + toast.error() on failed login
#      + toast.success() on successful login
#   3. (dashboard)/reports/page.tsx -> sonner import + toast.success() inside
#      exportCSV() so all 3 export buttons (Inventory/Yield/PnL) show a toast
#
#   Pages that are pure read-only lists/detail views with no save/delete/
#   error action (batches/page.tsx, invoices/page.tsx, dashboard home page.tsx,
#   raw-materials/[id]/page.tsx, suppliers/[id]/page.tsx) are intentionally
#   left alone - there is no event to notify the user about there.
#
# Safe to re-run - already-applied files are skipped, and each modified file
# is backed up first as <file>.bak-<timestamp>.
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
}

# -----------------------------------------------------------------
# 1. theme-toaster.tsx - make sure the Toaster is pinned top-right
# -----------------------------------------------------------------
$toasterPath = Join-Path $root "apps\frontend\components\ui\theme-toaster.tsx"

if (-not (Test-Path -LiteralPath $toasterPath)) {
    Write-Host "ERROR: Could not find $toasterPath" -ForegroundColor Red
    exit 1
}

$toasterContent = Get-Content -Raw -LiteralPath $toasterPath

if ($toasterContent -match 'position="top-right"') {
    Write-Host "theme-toaster.tsx already positioned top-right - skipping." -ForegroundColor Yellow
}
elseif ($toasterContent -match 'position=\{?"[a-z-]+"\}?') {
    Backup-File $toasterPath
    $updated = $toasterContent -replace 'position=\{?"[a-z-]+"\}?', 'position="top-right"'
    Set-Content -LiteralPath $toasterPath -Value $updated -NoNewline
    Write-Host "theme-toaster.tsx -> position forced to top-right." -ForegroundColor Green
}
else {
    Backup-File $toasterPath
    $updated = $toasterContent -replace '<Toaster theme=\{theme\}', '<Toaster theme={theme} position="top-right"'
    Set-Content -LiteralPath $toasterPath -Value $updated -NoNewline
    Write-Host "theme-toaster.tsx -> position=`"top-right`" added." -ForegroundColor Green
}

# -----------------------------------------------------------------
# 2. (auth)/login/page.tsx - toast on login success / failure
# -----------------------------------------------------------------
$loginPath = Join-Path $root "apps\frontend\app\(auth)\login\page.tsx"

if (-not (Test-Path -LiteralPath $loginPath)) {
    Write-Host "WARNING: Could not find $loginPath - skipping login page." -ForegroundColor Yellow
}
else {
    $loginContent = Get-Content -Raw -LiteralPath $loginPath

    if ($loginContent -match 'from "sonner"') {
        Write-Host "login/page.tsx already has toast - skipping." -ForegroundColor Yellow
    }
    else {
        Backup-File $loginPath

        # 2a. add the import, right after the supabase client import
        $updated = $loginContent -replace `
            'import \{ createClient \} from "@/lib/supabase/client";', `
            "import { createClient } from `"@/lib/supabase/client`";`r`nimport { toast } from `"sonner`";"

        # 2b. toast on failed sign-in (kept alongside the existing inline setError)
        $oldError = @'
    setLoading(false);
    if (signInError) {
      setError(signInError.message);
      return;
    }
    router.push("/");
    router.refresh();
'@

        $newError = @'
    setLoading(false);
    if (signInError) {
      setError(signInError.message);
      toast.error(signInError.message || "Login failed. Please check your credentials.");
      return;
    }
    toast.success("Logged in successfully");
    router.push("/");
    router.refresh();
'@

        if ($updated -notmatch [regex]::Escape($oldError)) {
            Write-Host "  WARNING: login handleSubmit block did not match exactly - import added, but toast calls were NOT inserted. Please add manually." -ForegroundColor Yellow
        }
        else {
            $updated = $updated -replace [regex]::Escape($oldError), $newError
        }

        Set-Content -LiteralPath $loginPath -Value $updated -NoNewline
        Write-Host "login/page.tsx -> sonner import + success/error toasts added." -ForegroundColor Green
    }
}

# -----------------------------------------------------------------
# 3. (dashboard)/reports/page.tsx - toast on CSV export
# -----------------------------------------------------------------
$reportsPath = Join-Path $root "apps\frontend\app\(dashboard)\reports\page.tsx"

if (-not (Test-Path -LiteralPath $reportsPath)) {
    Write-Host "WARNING: Could not find $reportsPath - skipping reports page." -ForegroundColor Yellow
}
else {
    $reportsContent = Get-Content -Raw -LiteralPath $reportsPath

    if ($reportsContent -match 'from "sonner"') {
        Write-Host "reports/page.tsx already has toast - skipping." -ForegroundColor Yellow
    }
    else {
        Backup-File $reportsPath

        # 3a. add the import, right after the useStore import
        $updated = $reportsContent -replace `
            'import \{ useStore \} from "@/lib/store";', `
            "import { useStore } from `"@/lib/store`";`r`nimport { toast } from `"sonner`";"

        # 3b. fire a toast at the end of the shared exportCSV() helper,
        #     so all three export buttons (Inventory / Yield / PnL) get it
        $oldExport = @'
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
'@

        $newExport = @'
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
  toast.success(`${filename} downloaded`);
}
'@

        if ($updated -notmatch [regex]::Escape($oldExport)) {
            Write-Host "  WARNING: exportCSV() body did not match exactly - import added, but toast call was NOT inserted. Please add manually." -ForegroundColor Yellow
        }
        else {
            $updated = $updated -replace [regex]::Escape($oldExport), $newExport
        }

        Set-Content -LiteralPath $reportsPath -Value $updated -NoNewline
        Write-Host "reports/page.tsx -> sonner import + export success toast added." -ForegroundColor Green
    }
}

# -----------------------------------------------------------------
# 4. Pages left untouched on purpose (read-only, no action to notify)
# -----------------------------------------------------------------
Write-Host ""
Write-Host "Skipped on purpose (no save/delete/error action present):" -ForegroundColor Cyan
Write-Host "  - apps/frontend/app/(dashboard)/batches/page.tsx          (list view only)"
Write-Host "  - apps/frontend/app/(dashboard)/invoices/page.tsx         (list view only)"
Write-Host "  - apps/frontend/app/(dashboard)/page.tsx                  (dashboard KPIs, read-only)"
Write-Host "  - apps/frontend/app/(dashboard)/raw-materials/[id]/page.tsx (detail view, read-only)"
Write-Host "  - apps/frontend/app/(dashboard)/suppliers/[id]/page.tsx   (detail view, read-only)"

Write-Host ""
Write-Host "Already wired with sonner toasts (left as-is):" -ForegroundColor Cyan
Write-Host "  batches/[id], batches/new, customers/[id], customers, finished-cartons,"
Write-Host "  invoices/[id], invoices/new, packaging/carton-config, packaging, payments,"
Write-Host "  raw-materials, receipts, settings, suppliers, purchase-receipt-dialog"

Write-Host ""
Write-Host "Done." -ForegroundColor Green