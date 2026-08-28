<#
  fix-callFunction-body-type.ps1
  ---------------------------------------------------------------
  Fixes the Vercel/Next.js build error:

    ./lib/api.ts:28:67
    Type error: Type 'unknown' is not assignable to type
    'string | File | Blob | ArrayBuffer | FormData | ReadableStream<...> | Record<...> | undefined'.

  Root cause:
    callFunction<T>(name: string, body: unknown) passes `body` straight
    into supabase.functions.invoke(name, { body }). The Supabase JS types
    require `body` to be one of a specific set of types, and `unknown`
    doesn't satisfy that, even though at runtime any JSON-serializable
    value works fine.

  Fix:
    Cast body to `any` at the call site (the function's own JSDoc/comment
    already documents that it JSON-serializes whatever is passed in, so
    this is a safe, intentional cast, not a behavior change).

  Usage:
    powershell -ExecutionPolicy Bypass -File .\fix-callFunction-body-type.ps1
    (run from the repo root, e.g.
     D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods)
#>

$ErrorActionPreference = "Stop"

$relativePath = "apps/frontend/lib/api.ts"
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
# Cast body to `any` in the supabase.functions.invoke call
# ---------------------------------------------------------------
$old1 = "  const { data, error } = await supabase.functions.invoke(name, { body });"
$new1 = "  const { data, error } = await supabase.functions.invoke(name, { body: body as any });"

if ($content.Contains($old1)) {
    $content = $content.Replace($old1, $new1)
    $changesMade++
    Write-Host "  [OK] Cast 'body' to 'any' in supabase.functions.invoke(...) call" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] Expected callFunction line not found (already patched, or file drifted)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# Write back
# ---------------------------------------------------------------
if ($changesMade -eq 0) {
    Write-Host ""
    Write-Host "No changes were applied." -ForegroundColor Yellow
    exit 0
}

if ($content -eq $originalContent) {
    Write-Host "Content unchanged after replacement - nothing written." -ForegroundColor Yellow
    exit 0
}

$backupFile = "$targetFile.bak"
Copy-Item -LiteralPath $targetFile -Destination $backupFile -Force
Write-Host "Backup saved to: $backupFile" -ForegroundColor Cyan

[System.IO.File]::WriteAllText($targetFile, $content, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Done. $changesMade change(s) applied to:" -ForegroundColor Green
Write-Host "  $relativePath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  git diff -- `"$relativePath`"" -ForegroundColor White
Write-Host "  npm run build   (or your usual build command) to verify" -ForegroundColor White
Write-Host "  git add -A; git commit -m 'fix: cast body type in supabase functions.invoke call'; git push" -ForegroundColor White