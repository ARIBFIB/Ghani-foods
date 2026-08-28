<#
  fix-recordLedgerEntry.ps1
  ---------------------------------------------------------------
  Fixes the Vercel/Next.js build error:

    ./app/(dashboard)/customers/[id]/page.tsx:40:5
    Type error: Expected 5 arguments, but got 4.

  Root cause:
    recordLedgerEntry(customerId, amount, direction, method, note)
    needs a `method: 'bank' | 'cash'` argument (see lib/store.ts),
    but customers/[id]/page.tsx's RecordPaymentDialog form was
    missing the "method" field entirely (unlike payments/page.tsx,
    which already has it).

  What this script does:
    1. Locates apps/frontend/app/(dashboard)/customers/[id]/page.tsx
       relative to where you run this script (run it from the repo
       root, e.g. D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods).
    2. Adds "method" to the zod schema + default values.
    3. Adds a Cash / Bank toggle UI (same pattern as payments/page.tsx).
    4. Updates the recordLedgerEntry(...) call to pass values.method
       and awaits it inside a try/catch (matches payments/page.tsx style).
    5. Writes the file back with CRLF line endings preserved.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\fix-recordLedgerEntry.ps1
#>

$ErrorActionPreference = "Stop"

$relativePath = "apps/frontend/app/(dashboard)/customers/[id]/page.tsx"
$targetFile = Join-Path -Path (Get-Location).Path -ChildPath $relativePath

if (-not (Test-Path -LiteralPath $targetFile)) {
    Write-Host "ERROR: Could not find file at: $targetFile" -ForegroundColor Red
    Write-Host "Make sure you run this script from the repo root:" -ForegroundColor Yellow
    Write-Host "  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods" -ForegroundColor Yellow
    exit 1
}

Write-Host "Reading $relativePath ..." -ForegroundColor Cyan
$content = Get-Content -Raw -LiteralPath $targetFile

$originalContent = $content
$changesMade = 0

# ---------------------------------------------------------------
# 1. Zod schema: add "method" field
# ---------------------------------------------------------------
$old1 = "const paymentAmountSchema = z.object({`r`n  amount: z.coerce.number().positive(""Amount must be greater than 0""),`r`n  direction: z.enum([""received"", ""given""], {`r`n    required_error: ""Select a direction"",`r`n  }),`r`n  note: z.string().trim().optional(),`r`n});"
$new1 = "const paymentAmountSchema = z.object({`r`n  amount: z.coerce.number().positive(""Amount must be greater than 0""),`r`n  direction: z.enum([""received"", ""given""], {`r`n    required_error: ""Select a direction"",`r`n  }),`r`n  method: z.enum([""cash"", ""bank""], {`r`n    required_error: ""Select a method"",`r`n  }),`r`n  note: z.string().trim().optional(),`r`n});"

if ($content.Contains($old1)) {
    $content = $content.Replace($old1, $new1)
    $changesMade++
    Write-Host "  [OK] Added 'method' to zod schema" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] Schema block not found as expected (already patched?)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# 2. defaultValues: add method: "cash", and watch("method")
# ---------------------------------------------------------------
$old2 = "    resolver: zodResolver(paymentAmountSchema),`r`n    defaultValues: { amount: 0, direction: ""received"", note: """" },`r`n  });`r`n  const direction = watch(""direction"");"
$new2 = "    resolver: zodResolver(paymentAmountSchema),`r`n    defaultValues: { amount: 0, direction: ""received"", method: ""cash"", note: """" },`r`n  });`r`n  const direction = watch(""direction"");`r`n  const method = watch(""method"");"

if ($content.Contains($old2)) {
    $content = $content.Replace($old2, $new2)
    $changesMade++
    Write-Host "  [OK] Added 'method' default value + watch()" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] defaultValues block not found as expected (already patched?)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# 3. onSubmit: pass values.method, await + try/catch (matches payments/page.tsx)
# ---------------------------------------------------------------
$old3 = "  const onSubmit = async (values: PaymentAmountValues) => {`r`n    recordLedgerEntry(customerId, values.amount, values.direction, values.note ?? """");`r`n    toast.success(`r`n      values.direction === ""received""`r`n        ? ``Payment of Rs. `${values.amount.toLocaleString()} received```r`n        : ``Rs. `${values.amount.toLocaleString()} recorded as given / credit adjustment```r`n    );`r`n    reset();`r`n    onClose();`r`n  };"
$new3 = "  const onSubmit = async (values: PaymentAmountValues) => {`r`n    try {`r`n      await recordLedgerEntry(customerId, values.amount, values.direction, values.method, values.note ?? """");`r`n      toast.success(`r`n        values.direction === ""received""`r`n          ? ``Payment of Rs. `${values.amount.toLocaleString()} received```r`n          : ``Rs. `${values.amount.toLocaleString()} recorded as given / credit adjustment```r`n      );`r`n      reset();`r`n      onClose();`r`n    } catch (err) {`r`n      toast.error(err instanceof Error ? err.message : ""Failed to record payment"");`r`n    }`r`n  };"

if ($content.Contains($old3)) {
    $content = $content.Replace($old3, $new3)
    $changesMade++
    Write-Host "  [OK] Fixed recordLedgerEntry(...) call to pass 'method' + await/try-catch" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] onSubmit block not found as expected (already patched?)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# 4. UI: insert Cash / Bank toggle before the "Note" field
# ---------------------------------------------------------------
$old4 = "            <input type=""hidden"" {...register(""direction"")} />`r`n            {errors.direction && <p className=""text-xs text-red-400 mt-1"">{errors.direction.message}</p>}`r`n          </div>`r`n          <div>`r`n            <label className=""text-sm text-[var(--text-muted)]"">Note</label>"
$new4 = "            <input type=""hidden"" {...register(""direction"")} />`r`n            {errors.direction && <p className=""text-xs text-red-400 mt-1"">{errors.direction.message}</p>}`r`n          </div>`r`n          <div>`r`n            <label className=""text-sm text-[var(--text-muted)]"">Received In / Paid From</label>`r`n            <div className=""mt-1 grid grid-cols-2 gap-2"">`r`n              <button`r`n                type=""button""`r`n                onClick={() => setValue(""method"", ""cash"", { shouldValidate: true })}`r`n                className={``rounded-lg border px-3 py-2 text-xs font-medium transition-colors `${`r`n                  method === ""cash""`r`n                    ? ""border-[var(--surface-border-strong)] bg-[var(--surface-hover)] text-[var(--foreground)]""`r`n                    : ""border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]""`r`n                }```}`r`n              >`r`n                Cash`r`n              </button>`r`n              <button`r`n                type=""button""`r`n                onClick={() => setValue(""method"", ""bank"", { shouldValidate: true })}`r`n                className={``rounded-lg border px-3 py-2 text-xs font-medium transition-colors `${`r`n                  method === ""bank""`r`n                    ? ""border-[var(--surface-border-strong)] bg-[var(--surface-hover)] text-[var(--foreground)]""`r`n                    : ""border-[var(--surface-border)] text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]""`r`n                }```}`r`n              >`r`n                Bank`r`n              </button>`r`n            </div>`r`n            <input type=""hidden"" {...register(""method"")} />`r`n            {errors.method && <p className=""text-xs text-red-400 mt-1"">{errors.method.message}</p>}`r`n          </div>`r`n          <div>`r`n            <label className=""text-sm text-[var(--text-muted)]"">Note</label>"

if ($content.Contains($old4)) {
    $content = $content.Replace($old4, $new4)
    $changesMade++
    Write-Host "  [OK] Added Cash / Bank method toggle UI" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] Note field block not found as expected (already patched?)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# Write back
# ---------------------------------------------------------------
if ($changesMade -eq 0) {
    Write-Host ""
    Write-Host "No changes were applied (file may already be patched, or its content has drifted from what this script expects)." -ForegroundColor Yellow
    exit 0
}

if ($content -eq $originalContent) {
    Write-Host "Content unchanged after replacements - nothing written." -ForegroundColor Yellow
    exit 0
}

# Backup original
$backupFile = "$targetFile.bak"
Copy-Item -LiteralPath $targetFile -Destination $backupFile -Force
Write-Host "Backup saved to: $backupFile" -ForegroundColor Cyan

# Write without adding a BOM, preserving CRLF already embedded in $content
[System.IO.File]::WriteAllText($targetFile, $content, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Done. $changesMade change block(s) applied to:" -ForegroundColor Green
Write-Host "  $relativePath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  git diff -- `"$relativePath`"" -ForegroundColor White
Write-Host "  npm run build   (or your usual build command) to verify" -ForegroundColor White
Write-Host "  git add -A; git commit -m 'fix: pass method arg to recordLedgerEntry'; git push" -ForegroundColor White