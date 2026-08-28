<#
  fix-phase1-invoice-bugs.ps1
  GhaniFoods - Phase 1: Critical invoice bug fixes (client feedback batch)

  Fixes TWO issues reported by the client:

  [1] "Invoice view karne ka option bhi nhi he after putting in - sirf
       first time dekh pate hain"
      Root cause: apps/frontend/app/(dashboard)/invoices/[id]/page.tsx
      looks up the invoice with:
          const invoice = useStore((s) => s.invoices.find((i) => i.id === id));
      and immediately renders "Invoice not found." if it's not there yet -
      with NO check for whether the store has finished loading
      (s.hydrated) and NO explicit refresh trigger on this page. If this
      page is opened directly (refresh, bookmark, reopened tab, coming
      back after the browser was closed) before the global hydration
      finishes, the user sees a dead-end "not found" screen.
      Fix: add a hydration/loading guard (show a loading state instead of
      "not found" while data is still loading) AND make this page trigger
      its own data refresh on mount, so it doesn't depend only on the
      dashboard layout's one-time load.

  [2] "Is k ilawa invoice men ye kiyon likha aa raha he ke last time this
       amount was charged"
      Root cause: line.priceSourceNote (e.g. "Previously sold to this
      customer on ... - that price applied.") is rendered under every
      item row on the customer-facing invoice screen. This is useful
      internal context but looks unprofessional on an invoice the
      customer sees.
      Fix: remove this note from the on-screen invoice item table.
      (The underlying data/history is untouched in the database - only
      the visible display on the invoice screen is removed.)

  This script is idempotent - safe to re-run. It detects the current
  (already-patched or original) code and only changes what's needed.

  Run this from the repo root:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>

  Usage:
    .\fix-phase1-invoice-bugs.ps1
    .\fix-phase1-invoice-bugs.ps1 -WhatIf
#>

param(
    [switch]$WhatIf
)

function Write-Step { param([string]$Text) Write-Host ""; Write-Host $Text -ForegroundColor Yellow }
function Write-Ok    { param([string]$Text) Write-Host "  -> $Text" -ForegroundColor Green }
function Write-Skip  { param([string]$Text) Write-Host "  -- $Text" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Text) Write-Host "  ERROR: $Text" -ForegroundColor Red }

function Write-FileUtf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

$root = (Get-Location).Path
Write-Host "Repo root: $root" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "Running in -WhatIf preview mode. No files will be changed." -ForegroundColor Magenta }

$detailPath = Join-Path $root "apps\frontend\app\(dashboard)\invoices\[id]\page.tsx"

if (-not (Test-Path -LiteralPath $detailPath)) {
    Write-Fail "Not found: $detailPath"
    Write-Fail "Make sure you're running this from the GhaniFoods repo root."
    exit 1
}

$original = Get-Content -LiteralPath $detailPath -Raw -Encoding UTF8
$content = $original
$changed = $false

# ---------------------------------------------------------------------
# FIX [1] - hydration/loading guard + self-refresh on mount
# ---------------------------------------------------------------------
Write-Step "[1/2] Fixing 'Invoice not found' flash / dead-end on direct or repeat visits..."

$oldHeader = @'
export default function InvoiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const invoice = useStore((s) => s.invoices.find((i) => i.id === id));
  const settings = useStore((s) => s.settings);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [generatingPdf, setGeneratingPdf] = useState(false);

  if (!invoice) {
    return (
      <div className="space-y-4">
        <NavLink href="/invoices" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Invoices</NavLink>
        <p className="text-[var(--text-muted)]">Invoice not found.</p>
      </div>
    );
  }
'@

$newHeader = @'
export default function InvoiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const invoice = useStore((s) => s.invoices.find((i) => i.id === id));
  const settings = useStore((s) => s.settings);
  const hydrated = useStore((s) => s.hydrated);
  const loadCustomersModule = useStore((s) => s.loadCustomersModule);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [generatingPdf, setGeneratingPdf] = useState(false);

  // Fix (client feedback: "sirf first time dekh pate hain"): this page
  // used to depend entirely on the dashboard layout's one-time StoreHydrator
  // load. If this page is opened directly - refresh, bookmark, reopened
  // tab, or coming back after the browser was closed - before that load
  // finishes, `invoice` is briefly (or permanently, if that fetch never
  // re-runs) undefined, and the old code showed a dead-end "Invoice not
  // found" with no way to recover. This page now triggers its own refresh
  // on mount and distinguishes "still loading" from "genuinely not found".
  const [refreshing, setRefreshing] = useState(true);
  useEffect(() => {
    let cancelled = false;
    loadCustomersModule().finally(() => {
      if (!cancelled) setRefreshing(false);
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  if (!invoice) {
    if (!hydrated || refreshing) {
      return (
        <div className="space-y-4">
          <NavLink href="/invoices" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Invoices</NavLink>
          <p className="text-[var(--text-muted)]">Loading invoice...</p>
        </div>
      );
    }
    return (
      <div className="space-y-4">
        <NavLink href="/invoices" className="text-sm text-[var(--text-muted)] hover:underline">&larr; Back to Invoices</NavLink>
        <p className="text-[var(--text-muted)]">Invoice not found.</p>
      </div>
    );
  }
'@

if ($content.Contains($newHeader)) {
    Write-Skip "Already patched - loading guard is already in place."
}
elseif ($content.Contains($oldHeader)) {
    $content = $content.Replace($oldHeader, $newHeader)
    $changed = $true
    Write-Ok "Added hydration/loading guard and self-refresh on mount."
}
else {
    Write-Fail "Could not find the expected original block to patch (file may already differ)."
    Write-Fail "No changes made for fix [1]. Please share the current file so the script can be adjusted."
}

# ---------------------------------------------------------------------
# FIX [2] - remove "last time this amount was charged" note from the
# on-screen invoice item table
# ---------------------------------------------------------------------
Write-Step "[2/2] Removing the 'last time this amount was charged' note from the invoice screen..."

$oldNoteBlock = @'
                      {line.itemName}
                      {line.priceSourceNote && (
                        <div className="mt-0.5 text-xs text-[var(--text-faint)]">{line.priceSourceNote}</div>
                      )}
'@

$newNoteBlock = @'
                      {line.itemName}
'@

if ($content.Contains($newNoteBlock) -and -not $content.Contains("line.priceSourceNote")) {
    Write-Skip "Already patched - price-source note is already removed from this screen."
}
elseif ($content.Contains($oldNoteBlock)) {
    $content = $content.Replace($oldNoteBlock, $newNoteBlock)
    $changed = $true
    Write-Ok "Removed the price-source note from the customer-facing invoice screen."
}
else {
    Write-Fail "Could not find the expected note block to patch (file may already differ)."
    Write-Fail "No changes made for fix [2]. Please share the current file so the script can be adjusted."
}

# ---------------------------------------------------------------------
# Write out
# ---------------------------------------------------------------------
if ($changed) {
    if ($WhatIf) {
        Write-Host ""
        Write-Host "WhatIf mode - would write changes to:" -ForegroundColor Magenta
        Write-Host "  $detailPath" -ForegroundColor Magenta
    }
    else {
        Write-FileUtf8NoBom -Path $detailPath -Content $content
        Write-Host ""
        Write-Host "Saved: $detailPath" -ForegroundColor Green
    }
}
else {
    Write-Host ""
    Write-Host "No changes were written (either already patched or patch targets not found - see messages above)." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart your dev server (npm run dev) if it was already running." -ForegroundColor Cyan
Write-Host "  2. Test: create a new invoice, view it, go back to /invoices, open the SAME invoice again." -ForegroundColor Cyan
Write-Host "  3. Also test opening an invoice URL directly / after a hard refresh." -ForegroundColor Cyan
Write-Host "  4. Confirm the 'last time this amount was charged' note no longer appears under item rows." -ForegroundColor Cyan
Write-Host ""
Write-Host "Once confirmed working, tell me and we'll move to the next batch (Phase 0: database schema for Ledger / Purchase Order / Returns / Bank-Cash / Carton-as-item)." -ForegroundColor Cyan