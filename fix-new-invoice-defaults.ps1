<#
  fix-new-invoice-defaults.ps1
  Purpose: Fix two UI bugs on the New Invoice page (apps/frontend/app/(dashboard)/invoices/new/page.tsx):

  BUG 1 - Literal "\u2014" text shown instead of an em dash in the item
  dropdown ("Carton A \u2014 2 in stock").
  Root cause: `{c.name} \u2014 {c.stockQty} in stock` is raw JSX text, not
  inside a JS string - so the \u2014 unicode escape is never interpreted by
  JS/React, it's rendered as the literal 4 characters "\u2014". (The other
  three \u2014 occurrences elsewhere in this file ARE inside JS string /
  template literals, so those already render correctly as an em dash.)

  BUG 2 - Customer and item dropdowns come pre-selected on page load/refresh.
  Root cause: defaultValues used `customers[0]?.id` for the customer, and the
  first invoice line used `finishedCartons[0]?.id` for the item, with no
  blank placeholder <option>. Nothing is truly "selected" by the user, but
  the UI looks pre-filled - and once data finishes loading async, the native
  <select> falls back to visually showing the first real <option> since the
  bound value ("" on first render) doesn't match any option, which is what
  produced the confusing "akhtar selected but still says Select a customer"
  screenshot.

  Fix: never auto-pick the first customer or the first item. Add an explicit
  blank "Select..." option to both dropdowns so nothing looks chosen until
  the user actually picks something.

  Run this from the repo root:
  D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\fix-new-invoice-defaults.ps1
    .\fix-new-invoice-defaults.ps1 -WhatIf
#>

param(
    [switch]$WhatIf
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

$pagePath = Join-Path $root "apps\frontend\app\(dashboard)\invoices\new\page.tsx"
if (-not (Test-Path -LiteralPath $pagePath)) {
    Write-Fail "Not found: $pagePath"
    exit 1
}

$original = Get-Content -LiteralPath $pagePath -Raw -Encoding UTF8
$content = $original
$changesMade = 0

# ---------------------------------------------------------------------
# Fix 1: literal "\u2014" in the item dropdown -> real em dash character
# ---------------------------------------------------------------------
Write-Step "[1/3] Fixing literal \u2014 text in item dropdown..."
$oldDash = '{c.name} \u2014 {c.stockQty} in stock'
$newDash = '{c.name} {"\u2014"} {c.stockQty} in stock'
if ($content.Contains($oldDash)) {
    $content = $content.Replace($oldDash, $newDash)
    Write-Ok "Wrapped the em dash in a JS string so it renders correctly."
    $changesMade++
} else {
    Write-Skip "Pattern not found verbatim - may already be fixed or file has changed."
}

# ---------------------------------------------------------------------
# Fix 2: don't auto-select the first customer
# ---------------------------------------------------------------------
Write-Step "[2/3] Removing auto-selected default customer..."
$oldCustomerDefault = 'defaultValues: { customerId: preselectedCustomerId || customers[0]?.id || "", margin: defaultMargin ?? 20 },'
$newCustomerDefault = 'defaultValues: { customerId: preselectedCustomerId || "", margin: defaultMargin ?? 20 },'
if ($content.Contains($oldCustomerDefault)) {
    $content = $content.Replace($oldCustomerDefault, $newCustomerDefault)
    Write-Ok "customerId now starts blank unless passed via ?customerId= in the URL."
    $changesMade++
} else {
    Write-Skip "Pattern not found verbatim - may already be fixed or file has changed."
}

# Add a blank placeholder option to the customer <select>
$oldCustomerSelect = '<select {...register("customerId")}
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>'
$newCustomerSelect = '<select {...register("customerId")}
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
            <option value="">Select a customer</option>
            {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>'
if ($content.Contains($oldCustomerSelect)) {
    $content = $content.Replace($oldCustomerSelect, $newCustomerSelect)
    Write-Ok "Added blank 'Select a customer' placeholder option."
    $changesMade++
} else {
    Write-Skip "Customer <select> block not found verbatim - may already be fixed or file has changed."
}

# ---------------------------------------------------------------------
# Fix 3: don't auto-select the first finished carton / item
# ---------------------------------------------------------------------
Write-Step "[3/3] Removing auto-selected default item on the first line..."

$oldInitialLine = 'const [lines, setLines] = useState<InvoiceLine[]>(() => {
    const firstItemId = finishedCartons[0]?.id ?? "";
    const { unitPrice, priceSourceNote } = buildPriceAndNote(
      firstItemId,
      preselectedCustomerId || customers[0]?.id || "",
      defaultMargin ?? 20,
      finishedCartons,
      lastSoldPriceInfo,
    );
    return [{ id: crypto.randomUUID(), itemId: firstItemId, qty: "1", unitPrice, priceSourceNote, touched: false }];
  });'
$newInitialLine = 'const [lines, setLines] = useState<InvoiceLine[]>(() => {
    return [{ id: crypto.randomUUID(), itemId: "", qty: "", unitPrice: "", priceSourceNote: "", touched: false }];
  });'
if ($content.Contains($oldInitialLine)) {
    $content = $content.Replace($oldInitialLine, $newInitialLine)
    Write-Ok "First invoice line now starts fully blank (no item, qty, or price)."
    $changesMade++
} else {
    Write-Skip "Initial lines useState block not found verbatim - may already be fixed or file has changed."
}

$oldAddLine = 'const addLine = () => {
    const firstItemId = finishedCartons[0]?.id ?? "";
    const { unitPrice, priceSourceNote } = buildPriceAndNote(firstItemId, customerId, Number(margin) || 0, finishedCartons, lastSoldPriceInfo);
    setLines((prev) => [...prev, { id: crypto.randomUUID(), itemId: firstItemId, qty: "1", unitPrice, priceSourceNote, touched: false }]);
  };'
$newAddLine = 'const addLine = () => {
    setLines((prev) => [...prev, { id: crypto.randomUUID(), itemId: "", qty: "", unitPrice: "", priceSourceNote: "", touched: false }]);
  };'
if ($content.Contains($oldAddLine)) {
    $content = $content.Replace($oldAddLine, $newAddLine)
    Write-Ok "New lines added via '+ Add Item' also start blank."
    $changesMade++
} else {
    Write-Skip "addLine() block not found verbatim - may already be fixed or file has changed."
}

# Add a blank placeholder option to the item <select>
$oldItemSelect = '<select value={line.itemId} onChange={(e) => handleItemChange(line.id, e.target.value)}
                    className="flex-1 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                    {finishedCartons.map((c) => <option key={c.id} value={c.id}>{c.name} {"\u2014"} {c.stockQty} in stock</option>)}
                  </select>'
$newItemSelect = '<select value={line.itemId} onChange={(e) => handleItemChange(line.id, e.target.value)}
                    className="flex-1 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]">
                    <option value="">Select item</option>
                    {finishedCartons.map((c) => <option key={c.id} value={c.id}>{c.name} {"\u2014"} {c.stockQty} in stock</option>)}
                  </select>'
if ($content.Contains($oldItemSelect)) {
    $content = $content.Replace($oldItemSelect, $newItemSelect)
    Write-Ok "Added blank 'Select item' placeholder option."
    $changesMade++
} else {
    Write-Skip "Item <select> block not found verbatim (it may not have picked up Fix 1 above, or the file has changed)."
}

if ($changesMade -eq 0) {
    Write-Fail "No patterns matched - no changes made. Paste the current file for a precise patch."
    exit 1
}

if ($content -eq $original) {
    Write-Skip "No change needed: $pagePath"
}
elseif ($WhatIf) {
    Write-Ok "[WhatIf] Would update: $pagePath ($changesMade change(s))"
}
else {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($pagePath, $content, $utf8NoBom)
    Write-Ok "Updated: $pagePath ($changesMade change(s))"
}

if (-not $WhatIf) {
    Write-Step "Verifying frontend build..."
    $frontendPath = Join-Path $root "apps\frontend"
    if (Test-Path -LiteralPath $frontendPath) {
        Push-Location $frontendPath
        try {
            npm run build
            if ($LASTEXITCODE -ne 0) { Write-Fail "Frontend build failed - paste the error." }
            else { Write-Ok "Frontend build passed." }
        } finally { Pop-Location }
    }
}
else {
    Write-Step "Skipped build verification (-WhatIf mode)"
}

Write-Host ""
Write-Host "Done. Redeploy and refresh the New Invoice page - customer and item" -ForegroundColor Cyan
Write-Host "should both start blank, and the stock dropdown should show a real em dash." -ForegroundColor Cyan
Write-Host "Note: Margin % is left defaulting to your app_settings value (a business" -ForegroundColor Yellow
Write-Host "default, not a 'selection'). Say the word if you want that blanked too." -ForegroundColor Yellow