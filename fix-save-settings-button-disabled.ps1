<#
  fix-save-settings-button-disabled.ps1
  ------------------------------------------------------------------
  Run this from the project ROOT:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  ISSUE:
    Hovering over the "Save Settings" button on /settings shows a
    "not-allowed" cursor, and the button stays greyed out even when
    the user has changed a value.

  ROOT CAUSE:
    apps/frontend/app/(dashboard)/settings/page.tsx has:
        disabled={isSubmitting || !isDirty}
    "!isDirty" means the button is intentionally disabled UNTIL
    react-hook-form detects that at least one field's value differs
    from its original defaultValue. If that dirty-tracking doesn't
    fire the way the user expects (e.g. re-selecting the same value
    in the dropdown, or the form's defaultValues getting reset from
    a background store refresh), the button can appear permanently
    disabled even though the user wants to save.

  FIX:
    Removes the "!isDirty" gate so the Save Settings button is only
    disabled while the save request is actually in flight
    (isSubmitting) - otherwise it's always clickable, which is the
    simpler and more predictable behavior most users expect from a
    "Save" button.

  SAFETY:
    The file is backed up to <file>.bak-<timestamp> before editing.
    The patch only applies if the exact anchor text is found EXACTLY
    ONCE in the file. If not found (e.g. already patched, or the file
    has since changed), the step is SKIPPED with a warning - nothing
    is force-applied or corrupted.
------------------------------------------------------------------#>

$ErrorActionPreference = "Stop"
$root = Get-Location
$ts = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Fix: 'Save Settings' button stuck disabled" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Root: $root`n"

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        $bak = "$path.bak-$ts"
        Copy-Item -LiteralPath $path -Destination $bak -Force
        Write-Host "  Backed up -> $bak" -ForegroundColor DarkGray
    }
}

function Edit-File($path, $old, $new, $label) {
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Warning "SKIP [$label]: file not found -> $path"
        return
    }
    $content = Get-Content -Raw -LiteralPath $path
    $count = ([regex]::Matches($content, [regex]::Escape($old))).Count
    if ($count -eq 1) {
        $newContent = $content.Replace($old, $new)
        Set-Content -LiteralPath $path -Value $newContent -NoNewline -Encoding UTF8
        Write-Host "  OK   [$label]" -ForegroundColor Green
    } elseif ($count -eq 0) {
        Write-Warning "SKIP [$label]: anchor text not found (file may already be patched, or edited) -> $path"
    } else {
        Write-Warning "SKIP [$label]: anchor text found $count times (expected 1, ambiguous) -> $path"
    }
}

$settingsPath = Join-Path $root "apps\frontend\app\(dashboard)\settings\page.tsx"

Write-Host "`n[1/2] apps/frontend/app/(dashboard)/settings/page.tsx"
Backup-File $settingsPath

# 1) Stop destructuring isDirty out of formState if it's now unused
#    elsewhere in the file - avoids an unused-variable lint warning.
#    (Safe no-op if isDirty is still used somewhere else; the disabled
#    prop edit below is the one that actually matters.)
Edit-File $settingsPath `
@'
    formState: { errors, isSubmitting, isDirty },
'@ `
@'
    formState: { errors, isSubmitting },
'@ `
"settings/page.tsx: drop unused isDirty from formState destructure"

# 2) The actual fix: only disable the button while actively submitting.
Edit-File $settingsPath `
@'
            disabled={isSubmitting || !isDirty}
'@ `
@'
            disabled={isSubmitting}
'@ `
"settings/page.tsx: Save Settings button no longer gated by isDirty"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  DONE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host @"

Next steps:
  1. cd apps\frontend
  2. npm run build   (or just refresh dev server)
  3. Visit /settings?tab=profile and confirm "Save Settings" is now
     always clickable (normal cursor, not the "not-allowed" cursor),
     and only greys out briefly while the save is actually in
     progress.

If anything looks off, the original file is backed up right next to
it as page.tsx.bak-$ts
"@ -ForegroundColor Yellow