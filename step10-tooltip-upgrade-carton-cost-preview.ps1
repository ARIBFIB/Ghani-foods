<#
  step10-tooltip-upgrade-carton-cost-preview.ps1
  ------------------------------------------------------------------
  Step 10: Tooltip pattern upgrade + Carton Configuration cost preview.

  Gap analysis item #10 ("Info tooltip pattern") was partially closed in
  step8: a shared <InfoTip/> exists and is applied on raw-materials,
  finished-cartons, packaging, payments, customers, invoices/new. BUT the
  spec (Frontend spec v2.2, section 5.13) says:

    "Implemented with shadcn Tooltip (hover on desktop, tap-to-toggle on
     touch)" and "A small 'i' icon (lucide Info, 14px)"

  The current info-tip.tsx is a plain <span title="..."> — no lucide
  icon, no real shadcn/Radix Tooltip, and no tap-to-toggle on touch
  (native title only long-presses on mobile, it doesn't tap-toggle).
  Step8 also explicitly flagged: "Carton Configuration cost preview does
  not exist yet ... build the feature first, then re-run a follow-up
  tooltip pass on that page."

  This script closes both gaps:

    1) apps/frontend/package.json
       Adds "@radix-ui/react-tooltip" dependency (needed for a real
       shadcn-style Tooltip). You must run `npm install` after this
       script finishes.

    2) apps/frontend/components/ui/tooltip.tsx (NEW)
       Standard shadcn Tooltip primitive wrapper (Provider/Root/Trigger/
       Content) built on @radix-ui/react-tooltip, styled with this
       project's existing CSS vars.

    3) apps/frontend/components/ui/info-tip.tsx (REPLACED)
       Now renders a 14px lucide <Info/> icon inside a real Radix
       Tooltip. Hover/focus works on desktop as usual; the trigger is
       also an explicit <button onClick> that toggles the tooltip's
       `open` state, so touch users can tap once to show it and tap
       again (or tap elsewhere) to dismiss it — real tap-to-toggle,
       not a hover-only fallback.
       Public API (`<InfoTip text="..."/>`) is unchanged, so every page
       that already imports InfoTip keeps working with no further edits.

    4) apps/frontend/app/(dashboard)/packaging/carton-config/page.tsx
       Adds a packaging cost build-up preview inside the "New
       Configuration" dialog: Cost / Wrapper -> Cost / Box -> Cost /
       Packet -> Cost / Carton, derived from each Wrapper/Box's
       gramsPerUnit and its underlying Raw Material's avgUnitCost
       (grams-to-stock-unit conversion assumes the raw material's
       `unit` field is "kg" unless it is literally "g"). An InfoTip is
       attached explaining the build-up, satisfying spec 5.13's
       explicit "Carton Configuration cost preview" tooltip target.

  Run from the project root:
    PS D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods> .\step10-tooltip-upgrade-carton-cost-preview.ps1

  Then:
    PS ...\GhaniFoods> npm install

  Safe to re-run: every edit is guarded by an "already applied" check
  (idempotent), and each touched file gets a one-time .step10.bak copy.
#>

$ErrorActionPreference = "Stop"

$root = Get-Location
Write-Host "Running Step 10 in: $root" -ForegroundColor Cyan

$pkgPath          = Join-Path $root "apps/frontend/package.json"
$tooltipPath      = Join-Path $root "apps/frontend/components/ui/tooltip.tsx"
$infoTipPath      = Join-Path $root "apps/frontend/components/ui/info-tip.tsx"
$cartonConfigPath = Join-Path $root "apps/frontend/app/(dashboard)/packaging/carton-config/page.tsx"

foreach ($p in @($pkgPath, $infoTipPath, $cartonConfigPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host "ERROR: Expected file not found: $p" -ForegroundColor Red
        Write-Host "Make sure you are running this script from the GhaniFoods project root." -ForegroundColor Red
        exit 1
    }
}

function Backup-File($path) {
    $bak = "$path.step10.bak"
    if (-not (Test-Path -LiteralPath $bak)) {
        Copy-Item -LiteralPath $path -Destination $bak -Force
        Write-Host "Backed up: $path -> $bak" -ForegroundColor DarkGray
    }
}

function Write-Utf8NoBom($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------------------
# 1) apps/frontend/package.json -> add @radix-ui/react-tooltip
# ---------------------------------------------------------------------------
$pkgRaw = [System.IO.File]::ReadAllText($pkgPath)
if ($pkgRaw -match '"@radix-ui/react-tooltip"') {
    Write-Host "Skipped (already present): @radix-ui/react-tooltip in package.json" -ForegroundColor DarkGray
} else {
    Backup-File $pkgPath
    $anchor = '"@radix-ui/react-slot":  "^1.1.0",'
    if ($pkgRaw -match [regex]::Escape($anchor)) {
        $pkgRaw = $pkgRaw -replace [regex]::Escape($anchor), ($anchor + "`r`n                         `"@radix-ui/react-tooltip`":  `"^1.1.4`",")
    } else {
        # Fallback: insert right after the opening of "dependencies": {
        $pkgRaw = $pkgRaw -replace '("dependencies":\s*\{)', "`$1`r`n                         `"@radix-ui/react-tooltip`":  `"^1.1.4`","
    }
    Write-Utf8NoBom $pkgPath $pkgRaw
    Write-Host "Updated: $pkgPath (added @radix-ui/react-tooltip)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2) apps/frontend/components/ui/tooltip.tsx (NEW)
# ---------------------------------------------------------------------------
$tooltipContent = @'
"use client";

import * as React from "react";
import * as TooltipPrimitive from "@radix-ui/react-tooltip";

import { cn } from "@/lib/utils";

const TooltipProvider = TooltipPrimitive.Provider;
const Tooltip = TooltipPrimitive.Root;
const TooltipTrigger = TooltipPrimitive.Trigger;

const TooltipContent = React.forwardRef<
  React.ElementRef<typeof TooltipPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Content>
>(({ className, sideOffset = 6, ...props }, ref) => (
  <TooltipPrimitive.Portal>
    <TooltipPrimitive.Content
      ref={ref}
      sideOffset={sideOffset}
      className={cn(
        "z-50 overflow-hidden rounded-md border border-[var(--surface-border)] bg-[var(--surface)] px-3 py-1.5 text-xs text-[var(--foreground)] shadow-md animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[side=bottom]:slide-in-from-top-1 data-[side=left]:slide-in-from-right-1 data-[side=right]:slide-in-from-left-1 data-[side=top]:slide-in-from-bottom-1",
        className
      )}
      {...props}
    />
  </TooltipPrimitive.Portal>
));
TooltipContent.displayName = TooltipPrimitive.Content.displayName;

export { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider };
'@

if ((Test-Path -LiteralPath $tooltipPath) -and ([System.IO.File]::ReadAllText($tooltipPath) -eq $tooltipContent)) {
    Write-Host "Skipped (already up to date): $tooltipPath" -ForegroundColor DarkGray
} else {
    if (Test-Path -LiteralPath $tooltipPath) { Backup-File $tooltipPath }
    Write-Utf8NoBom $tooltipPath $tooltipContent
    Write-Host "Created/updated: $tooltipPath" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3) apps/frontend/components/ui/info-tip.tsx (REPLACED — real Tooltip + lucide Info icon)
# ---------------------------------------------------------------------------
Backup-File $infoTipPath
$infoTipContent = @'
"use client";

import { useState } from "react";
import { Info } from "lucide-react";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

// Shared "i" info-tooltip used next to any field or calculated value whose
// meaning or derivation is not immediately obvious (BRS v1.2 note; Frontend
// spec v2.2 section 5.13: "shadcn Tooltip, lucide Info 14px, hover on
// desktop, tap-to-toggle on touch"). `open` is controlled so the trigger's
// onClick can explicitly flip it — touchscreens don't fire hover, so
// relying on Radix's default hover-only behavior would leave touch users
// with no way to see the tooltip at all.
export function InfoTip({ text }: { text: string }) {
  const [open, setOpen] = useState(false);

  return (
    <TooltipProvider delayDuration={150}>
      <Tooltip open={open} onOpenChange={setOpen}>
        <TooltipTrigger asChild>
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              setOpen((v) => !v);
            }}
            aria-label="More info"
            className="ml-1 inline-flex h-3.5 w-3.5 shrink-0 cursor-help select-none items-center justify-center align-middle text-[var(--text-faint)] outline-none hover:text-[var(--text-secondary)]"
          >
            <Info size={14} strokeWidth={2} />
          </button>
        </TooltipTrigger>
        <TooltipContent className="max-w-[220px] text-xs leading-snug">
          {text}
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}

export default InfoTip;
'@

Write-Utf8NoBom $infoTipPath $infoTipContent
Write-Host "Updated: $infoTipPath (real shadcn Tooltip + lucide Info icon, tap-to-toggle)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4) apps/frontend/app/(dashboard)/packaging/carton-config/page.tsx
#    Add packaging cost build-up preview + InfoTip inside the dialog
# ---------------------------------------------------------------------------
$cartonConfigContent = [System.IO.File]::ReadAllText($cartonConfigPath)

if ($cartonConfigContent -match "Cost / Carton") {
    Write-Host "Skipped (already applied): cost preview in carton-config/page.tsx" -ForegroundColor DarkGray
} else {
    Backup-File $cartonConfigPath

    # --- 4a) import InfoTip + Wrapper/Box/RawMaterial types + useStore rawMaterials
    $importAnchor = 'import { SortableTable } from "@/components/ui/sortable-table";'
    if ($cartonConfigContent -notmatch [regex]::Escape($importAnchor)) {
        Write-Host "ERROR: Could not find import anchor in carton-config/page.tsx. No changes made." -ForegroundColor Red
        exit 1
    }
    $newImports = $importAnchor + "`r`nimport { InfoTip } from `"@/components/ui/info-tip`";"
    $cartonConfigContent = $cartonConfigContent -replace [regex]::Escape($importAnchor), $newImports

    # --- 4b) pull rawMaterials into AddConfigDialog and compute cost build-up
    $dialogStateAnchor = 'const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const addCartonConfiguration = useStore((s) => s.addCartonConfiguration);'
    $dialogStateReplacement = 'const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const addCartonConfiguration = useStore((s) => s.addCartonConfiguration);

  // Packaging cost build-up (BRS v1.2 sec 1.1; Frontend spec v2.2 sec 5.13
  // "Carton Configuration cost preview"). Grams-per-unit is always in
  // grams; the underlying Raw Material''s avgUnitCost is per its stock
  // `unit`. Assume that unit is "kg" unless it is literally "g".
  const costPerGram = (rawMaterialId: string) => {
    const rm = rawMaterials.find((r) => r.id === rawMaterialId);
    if (!rm) return 0;
    return rm.unit === "g" ? rm.avgUnitCost : rm.avgUnitCost / 1000;
  };'
    if ($cartonConfigContent -notmatch [regex]::Escape($dialogStateAnchor)) {
        Write-Host "ERROR: Could not find dialog-state anchor in carton-config/page.tsx. No changes made." -ForegroundColor Red
        exit 1
    }
    $cartonConfigContent = $cartonConfigContent -replace [regex]::Escape($dialogStateAnchor), $dialogStateReplacement

    # --- 4c) compute selected wrapper/box cost figures next to totalPacketsPerCarton
    $totalPacketsAnchor = 'const totalPacketsPerCarton = (Number(packetsPerBox) || 0) * (Number(boxesPerCarton) || 0);'
    $totalPacketsReplacement = 'const totalPacketsPerCarton = (Number(packetsPerBox) || 0) * (Number(boxesPerCarton) || 0);

  const selectedWrapper = wrappers.find((w) => w.id === wrapperId);
  const selectedBox = boxes.find((b) => b.id === boxId);
  const costPerWrapper = selectedWrapper ? selectedWrapper.gramsPerUnit * costPerGram(selectedWrapper.rawMaterialId) : 0;
  const costPerBox = selectedBox ? selectedBox.gramsPerUnit * costPerGram(selectedBox.rawMaterialId) : 0;
  const costPerPacket = costPerWrapper;
  const costPerBoxAssembled = costPerBox + (Number(packetsPerBox) || 0) * costPerWrapper;
  const costPerCarton = (Number(boxesPerCarton) || 0) * costPerBoxAssembled;'
    if ($cartonConfigContent -notmatch [regex]::Escape($totalPacketsAnchor)) {
        Write-Host "ERROR: Could not find totalPacketsPerCarton anchor in carton-config/page.tsx. No changes made." -ForegroundColor Red
        exit 1
    }
    $cartonConfigContent = $cartonConfigContent -replace [regex]::Escape($totalPacketsAnchor), $totalPacketsReplacement

    # --- 4d) render the cost preview panel right after the existing packets-per-carton note
    $previewAnchor = '{wrapperId && boxId && totalPacketsPerCarton > 0 && (
            <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 text-xs text-[var(--text-muted)]">
              {name?.trim() ? <span className="text-[var(--foreground)] font-medium">"{name.trim()}"</span> : "This configuration"} yields{" "}
              <span className="text-[var(--foreground)] font-medium">{totalPacketsPerCarton} packets</span> per carton.
            </div>
          )}'
    if ($cartonConfigContent -notmatch [regex]::Escape($previewAnchor)) {
        Write-Host "ERROR: Could not find preview-panel anchor in carton-config/page.tsx. No changes made." -ForegroundColor Red
        exit 1
    }
    $previewReplacement = $previewAnchor + '

          {wrapperId && boxId && totalPacketsPerCarton > 0 && (
            <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 text-xs text-[var(--text-muted)] space-y-1.5">
              <div className="flex items-center text-[var(--foreground)] font-medium">
                Cost Build-Up
                <InfoTip text="Derived from each Wrapper/Box''s grams-per-unit x its raw material''s current weighted-average cost. Wrapper cost = per packet. Box cost + (Packets/Box x Wrapper cost) = per box. That x Boxes/Carton = per carton. Excludes bulk product cost, which varies per batch." />
              </div>
              <div className="grid grid-cols-2 gap-x-3 gap-y-1">
                <span>Cost / Wrapper (Packet)</span><span className="text-right text-[var(--foreground)]">Rs. {costPerPacket.toFixed(2)}</span>
                <span>Cost / Box</span><span className="text-right text-[var(--foreground)]">Rs. {costPerBox.toFixed(2)}</span>
                <span>Cost / Box (assembled)</span><span className="text-right text-[var(--foreground)]">Rs. {costPerBoxAssembled.toFixed(2)}</span>
                <span className="font-medium">Cost / Carton</span><span className="text-right text-[var(--foreground)] font-medium">Rs. {costPerCarton.toFixed(2)}</span>
              </div>
            </div>
          )}'
    $cartonConfigContent = $cartonConfigContent -replace [regex]::Escape($previewAnchor), $previewReplacement

    Write-Utf8NoBom $cartonConfigPath $cartonConfigContent
    Write-Host "Updated: $cartonConfigPath (added Cost Build-Up preview + InfoTip)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 10 complete." -ForegroundColor Cyan
Write-Host "Next: run 'npm install' at the project root to pull in @radix-ui/react-tooltip." -ForegroundColor Yellow