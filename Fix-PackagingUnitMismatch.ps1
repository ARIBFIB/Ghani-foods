<#
  Fix-PackagingUnitMismatch.ps1
  -----------------------------------------------------------------------
  ISSUE 8: Unit mismatch / hardcoded "grams" bug in Box & Batch dialogs.

  WHAT THIS SCRIPT FIXES (frontend, verified against your uploaded code):
    1. apps/frontend/app/(dashboard)/packaging/page.tsx
       - "Define Box"/"Define Wrapper" dialog: label was hardcoded
         "Grams per Unit" regardless of the selected raw material's real
         unit. Now shows "Pieces per Unit" / "Kg per Unit" / "Litres per
         Unit" / etc. dynamically, based on the selected raw material.
       - "Produce" dialog: "Box Paper in stock: 25 g" and "Grams to be
         consumed: 10 g" were hardcoded to "g" and secretly multiplied
         kg-unit stock by 1000 (grams conversion) while leaving every
         other unit, including "piece", uncorrected. Replaced with
         direct, same-unit comparison (no silent conversion at all) and
         a dynamic unit label/abbreviation.
       - Wrappers/Boxes list table: "Grams per Unit" column header and
         forced " g" suffix replaced with a generic "Qty per Unit" header
         and a per-row unit abbreviation pulled from that row's actual
         raw material.
    2. apps/frontend/lib/store.ts
       - computePackagingUnitCost() previously divided avgUnitCost by a
         "unitToGramsMultiplier" that silently defaulted every non-kg
         unit (including "piece") to a 1:1 grams assumption. Replaced
         with a straight multiplication in the raw material's own unit
         (no assumed conversion).
       - Added packagingQtyLabel()/packagingUnitAbbrev() helpers so every
         screen shows the correct unit instead of a hardcoded "g".
    3. apps/frontend/app/(dashboard)/packaging/carton-config/page.tsx
       - Local costPerGram() helper had the exact same hardcoded bug
         (only treated literal unit "g" correctly, /1000'd everything
         else - including "piece" - as if it were kg). Removed and
         replaced with the shared, unit-aware computePackagingUnitCost().
    4. apps/frontend/lib/schemas.ts
       - Validation message "Grams per unit must be greater than 0" ->
         "Quantity per unit must be greater than 0" (field is no longer
         grams-only).

  WHAT THIS SCRIPT DOES NOT (CANNOT) FIX, AND WHY:
    The actual stock DEDUCTION when you click "Confirm" in the Produce
    dialog does NOT happen in any .tsx/.ts file you exported - it happens
    inside two Postgres functions on the Supabase side:
        fn_produce_box(p_box_id, p_qty)
        fn_produce_wrapper(p_wrapper_id, p_qty)
    These are called via supabase.rpc(...) in lib/store.ts, but their
    SQL bodies are not part of this code export (no migrations folder
    was included, only edits.json from a previous script). That is the
    most likely place the real "24.98 pieces" data corruption comes
    from - if that function does its own internal gram-based math, no
    frontend fix can correct it.

    ACTION NEEDED FROM YOU: run this in the Supabase SQL editor and send
    me the output:
        select pg_get_functiondef(oid)
        from pg_proc
        where proname in ('fn_produce_box','fn_produce_wrapper');
    Once I can see that SQL, I will give you a precise CREATE OR REPLACE
    migration for it (same anchor/replace pattern as this script).

  SAFE, NON-DESTRUCTIVE DB DIAGNOSTIC INCLUDED:
    This script also writes a new migration that creates a read-only
    view, v_fractional_stock_flags, listing every wrapper/box (and raw
    material) whose unit implies whole numbers (piece/dozen/box/packet/
    bag) but whose current stock_qty / quantity_in_stock is NOT a whole
    number - e.g. Box Paper's "24.98". It changes NO data. Query it
    after applying the migration:
        select * from v_fractional_stock_flags;
    Anything it returns is leftover corruption from before this fix and
    needs a manual correction (per the issue notes) - this script
    deliberately does not guess-fix historical numbers for you.

  USAGE:
    cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
    .\Fix-PackagingUnitMismatch.ps1

  Idempotent - safe to re-run. Only uses plain ASCII in its own logic.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    WARNING: $msg" -ForegroundColor Yellow }

function ConvertTo-LF([string]$text) { return $text -replace "`r`n", "`n" }
function ConvertTo-CRLF([string]$text) { return $text -replace "`n", "`r`n" }

function Apply-Edit {
    param([string]$content, [string]$anchor, [string]$replacement, [string]$description)
    $anchorLF = ConvertTo-LF $anchor
    $replacementLF = ConvertTo-LF $replacement
    if ($content.Contains($replacementLF)) {
        Write-Ok "$description - already applied, skipping."
        return @($content, $false)
    }
    $idx = $content.IndexOf($anchorLF)
    if ($idx -lt 0) {
        Write-Warn2 "$description - anchor not found. Paste this file and I will give the exact edit."
        return @($content, $false)
    }
    $newContent = $content.Substring(0, $idx) + $replacementLF + $content.Substring($idx + $anchorLF.Length)
    Write-Ok "$description - wired."
    return @($newContent, $true)
}

function Edit-FileWithSteps {
    param([string]$Path, [array]$Steps)
    if (-not (Test-Path $Path)) { Write-Warn2 "$Path not found - skipping."; return }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    $usesCRLF = $raw -match "`r`n"
    $content = ConvertTo-LF $raw
    $anyChange = $false
    foreach ($step in $Steps) {
        $result = Apply-Edit -content $content -anchor $step.anchor -replacement $step.replacement -description $step.description
        $content = $result[0]
        if ($result[1]) { $anyChange = $true }
    }
    if ($anyChange) {
        $final = if ($usesCRLF) { ConvertTo-CRLF $content } else { $content }
        Set-Content -Path $Path -Value $final -Encoding UTF8 -NoNewline
        Write-Ok "Saved: $Path"
    }
    else {
        Write-Ok "No changes needed for: $Path"
    }
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
$FrontendDir   = Join-Path $ProjectRoot "apps\frontend"

$StorePath           = Join-Path $FrontendDir "lib\store.ts"
$SchemasPath         = Join-Path $FrontendDir "lib\schemas.ts"
$PackagingPagePath   = Join-Path $FrontendDir "app\(dashboard)\packaging\page.tsx"
$CartonConfigPath    = Join-Path $FrontendDir "app\(dashboard)\packaging\carton-config\page.tsx"

Write-Ok "Project root: $ProjectRoot"

# -------------------------------------------------------------------------
# 1. lib/store.ts - unit-aware cost calc + label helpers
# -------------------------------------------------------------------------
Write-Step "Fixing apps/frontend/lib/store.ts..."

$storeSteps = @(
    @{
        description = "Replace unitToGramsMultiplier/computePackagingUnitCost with unit-aware version + label helpers"
        anchor = @'
function unitToGramsMultiplier(unit: string): number {
  const u = unit.trim().toLowerCase();
  if (u === "kg" || u === "kilogram" || u === "kilograms") return 1000;
  if (u === "g" || u === "gram" || u === "grams") return 1;
  return 1;
}

export function computePackagingUnitCost(gramsPerUnit: number, rawMaterial: RawMaterial | undefined): number {
  if (!rawMaterial) return 0;
  const multiplier = unitToGramsMultiplier(rawMaterial.unit);
  const costPerGram = rawMaterial.avgUnitCost / multiplier;
  return gramsPerUnit * costPerGram;
}
'@
        replacement = @'
// ISSUE 8 FIX: this used to assume every raw material's stock was tracked
// in grams (or convertible kg->g), and silently defaulted every OTHER
// unit - including "piece" - to the same 1:1 grams multiplier. That is
// wrong: a Box/Wrapper's "quantity per unit" is always defined in the
// SAME unit the underlying raw material's own stock/avgUnitCost is
// tracked in, so it must be compared/multiplied directly, unit-for-unit,
// with no silent scaling. If a real kg<->g style conversion is ever
// needed, it must be explicit - not assumed here.
export function computePackagingUnitCost(quantityPerUnit: number, rawMaterial: RawMaterial | undefined): number {
  if (!rawMaterial) return 0;
  // avgUnitCost is always "cost per 1 <rawMaterial.unit>", so cost of
  // quantityPerUnit (in that same unit) is a straight multiplication.
  return quantityPerUnit * rawMaterial.avgUnitCost;
}

// Human-readable "<Unit> per Unit" label for packaging quantity fields,
// e.g. "Kg per Unit", "Pieces per Unit", "Grams per Unit" - driven by the
// underlying raw material's actual unit instead of a hardcoded "Grams".
export function packagingQtyLabel(unit: string | undefined): string {
  const u = (unit ?? "").trim().toLowerCase();
  const known: Record<string, string> = {
    kg: "Kg per Unit", g: "Grams per Unit", gram: "Grams per Unit", grams: "Grams per Unit",
    litre: "Litres per Unit", liter: "Litres per Unit", ml: "Millilitres per Unit",
    piece: "Pieces per Unit", dozen: "Dozens per Unit", box: "Boxes per Unit",
    packet: "Packets per Unit", bag: "Bags per Unit",
  };
  if (known[u]) return known[u];
  if (!unit) return "Quantity per Unit";
  return `${unit.charAt(0).toUpperCase()}${unit.slice(1)} per Unit`;
}

// Short unit abbreviation for inline quantity display, e.g. "24 pc", "5 kg".
export function packagingUnitAbbrev(unit: string | undefined): string {
  const u = (unit ?? "").trim().toLowerCase();
  const known: Record<string, string> = {
    kg: "kg", g: "g", gram: "g", grams: "g", litre: "l", liter: "l", ml: "ml",
    piece: "pc", dozen: "dz", box: "box", packet: "pkt", bag: "bag",
  };
  return known[u] ?? (unit ?? "");
}
'@
    }
)
Edit-FileWithSteps -Path $StorePath -Steps $storeSteps

# -------------------------------------------------------------------------
# 2. lib/schemas.ts - validation message
# -------------------------------------------------------------------------
Write-Step "Fixing apps/frontend/lib/schemas.ts..."

$schemasSteps = @(
    @{
        description = "Grams-only validation message -> unit-agnostic message"
        anchor = @'
  gramsPerUnit: z.coerce.number().positive("Grams per unit must be greater than 0"),
'@
        replacement = @'
  gramsPerUnit: z.coerce.number().positive("Quantity per unit must be greater than 0"),
'@
    }
)
Edit-FileWithSteps -Path $SchemasPath -Steps $schemasSteps

# -------------------------------------------------------------------------
# 3. packaging/page.tsx - Define dialog, Produce dialog, list columns
# -------------------------------------------------------------------------
Write-Step "Fixing apps/frontend/app/(dashboard)/packaging/page.tsx..."

$packagingSteps = @(
    @{
        description = "Import new unit-label helpers from store"
        anchor = @'
import { useStore, type Wrapper, type Box, type RawMaterial } from "@/lib/store";
'@
        replacement = @'
import { useStore, type Wrapper, type Box, type RawMaterial, packagingQtyLabel, packagingUnitAbbrev } from "@/lib/store";
'@
    },
    @{
        description = "DefineDialog: watch selected raw material so the label can react to it"
        anchor = @'
  const { register, control, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<
    WrapperDefinitionFormValues | BoxDefinitionFormValues
  >({
    resolver: zodResolver(schema),
    defaultValues: {
      name: "",
      rawMaterialId: rawMaterials[0]?.id ?? "",
      gramsPerUnit: 0,
      lowStockThreshold: kind === "wrapper" ? 500 : 100,
    },
  });

  if (!open) return null;
  const label = kind === "wrapper" ? "Wrapper" : "Box";
'@
        replacement = @'
  const { register, control, handleSubmit, reset, watch, formState: { errors, isSubmitting } } = useForm<
    WrapperDefinitionFormValues | BoxDefinitionFormValues
  >({
    resolver: zodResolver(schema),
    defaultValues: {
      name: "",
      rawMaterialId: rawMaterials[0]?.id ?? "",
      gramsPerUnit: 0,
      lowStockThreshold: kind === "wrapper" ? 500 : 100,
    },
  });

  // ISSUE 8 FIX: label must follow whichever raw material is actually
  // selected, not a hardcoded "Grams".
  const selectedRawMaterialId = watch("rawMaterialId");
  const selectedRawMaterial = rawMaterials.find((m) => m.id === selectedRawMaterialId);
  const qtyPerUnitLabel = packagingQtyLabel(selectedRawMaterial?.unit);

  if (!open) return null;
  const label = kind === "wrapper" ? "Wrapper" : "Box";
'@
    },
    @{
        description = "DefineDialog: dynamic 'Grams per Unit' -> real unit label"
        anchor = @'
          <div>
            <label className="text-sm text-[var(--text-muted)] inline-flex items-center">
              Grams per Unit
              <InfoTip text={`How many grams of the underlying raw material are used to make one ${label.toLowerCase()}`} />
            </label>
            <input {...register("gramsPerUnit")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.gramsPerUnit && <p className="text-xs text-red-400 mt-1">{errors.gramsPerUnit.message}</p>}
          </div>
'@
        replacement = @'
          <div>
            <label className="text-sm text-[var(--text-muted)] inline-flex items-center">
              {qtyPerUnitLabel}
              <InfoTip text={`How many ${(selectedRawMaterial?.unit || "units").toLowerCase()} of the underlying raw material are used to make one ${label.toLowerCase()}`} />
            </label>
            <input {...register("gramsPerUnit")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.gramsPerUnit && <p className="text-xs text-red-400 mt-1">{errors.gramsPerUnit.message}</p>}
          </div>
'@
    },
    @{
        description = "ProduceDialog: remove hardcoded grams / silent kg->g conversion from the calc"
        anchor = @'
  if (!target) return null;
  const { kind, item } = target;
  const rawMaterial = rawMaterials.find((m) => m.id === item.rawMaterialId);
  const unit = (rawMaterial?.unit ?? "").trim().toLowerCase();
  const multiplier = unit === "kg" || unit === "kilogram" || unit === "kilograms" ? 1000 : 1;
  const availableGrams = rawMaterial ? rawMaterial.quantityInStock * multiplier : 0;
  const gramsToConsume = item.gramsPerUnit * quantityProduced;
  const insufficient = gramsToConsume > availableGrams;
'@
        replacement = @'
  if (!target) return null;
  const { kind, item } = target;
  const rawMaterial = rawMaterials.find((m) => m.id === item.rawMaterialId);
  // ISSUE 8 FIX: no more hardcoded grams / silent kg->g conversion. The
  // packaging item's per-unit quantity is defined in the raw material's
  // OWN unit, so it is compared directly against quantityInStock (also in
  // that same unit) with no scaling.
  const unitAbbrev = packagingUnitAbbrev(rawMaterial?.unit);
  const availableQty = rawMaterial ? rawMaterial.quantityInStock : 0;
  const qtyToConsume = item.gramsPerUnit * quantityProduced;
  const insufficient = qtyToConsume > availableQty;
'@
    },
    @{
        description = "ProduceDialog: 'Grams per Unit' / stock-in-grams display -> dynamic unit"
        anchor = @'
        <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 space-y-1 text-xs text-[var(--text-muted)]">
          <div className="flex justify-between">
            <span>Grams per Unit</span>
            <span className="text-[var(--foreground)]">{item.gramsPerUnit.toLocaleString()} g</span>
          </div>
          <div className="flex justify-between">
            <span>{rawMaterial?.name ?? "Raw material"} in stock</span>
            <span className="text-[var(--foreground)]">{availableGrams.toLocaleString()} g</span>
          </div>
        </div>
'@
        replacement = @'
        <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 space-y-1 text-xs text-[var(--text-muted)]">
          <div className="flex justify-between">
            <span>{packagingQtyLabel(rawMaterial?.unit)}</span>
            <span className="text-[var(--foreground)]">{item.gramsPerUnit.toLocaleString()} {unitAbbrev}</span>
          </div>
          <div className="flex justify-between">
            <span>{rawMaterial?.name ?? "Raw material"} in stock</span>
            <span className="text-[var(--foreground)]">{availableQty.toLocaleString()} {unitAbbrev}</span>
          </div>
        </div>
'@
    },
    @{
        description = "ProduceDialog: 'Grams to be consumed' -> dynamic unit"
        anchor = @'
        <div className={`rounded-lg border p-3 text-xs ${insufficient ? "border-red-900 bg-red-950 text-red-400" : "border-[var(--surface-border)] bg-[var(--background)] text-[var(--text-muted)]"}`}>
          <div className="flex justify-between">
            <span>Grams to be consumed</span>
            <span className={insufficient ? "text-red-400 font-medium" : "text-[var(--foreground)] font-medium"}>
              {gramsToConsume.toLocaleString()} g
            </span>
          </div>
          {insufficient && (
            <p className="mt-1">Not enough {rawMaterial?.name ?? "raw material"} in stock to produce this quantity.</p>
          )}
        </div>
'@
        replacement = @'
        <div className={`rounded-lg border p-3 text-xs ${insufficient ? "border-red-900 bg-red-950 text-red-400" : "border-[var(--surface-border)] bg-[var(--background)] text-[var(--text-muted)]"}`}>
          <div className="flex justify-between">
            <span>{(rawMaterial?.unit ? rawMaterial.unit.charAt(0).toUpperCase() + rawMaterial.unit.slice(1) : "Quantity")} to be consumed</span>
            <span className={insufficient ? "text-red-400 font-medium" : "text-[var(--foreground)] font-medium"}>
              {qtyToConsume.toLocaleString()} {unitAbbrev}
            </span>
          </div>
          {insufficient && (
            <p className="mt-1">Not enough {rawMaterial?.name ?? "raw material"} in stock to produce this quantity.</p>
          )}
        </div>
'@
    },
    @{
        description = "List page: add per-row unit-abbreviation lookup helper"
        anchor = @'
  const materialName = (id: string) => rawMaterials.find((m) => m.id === id)?.name ?? "-";
'@
        replacement = @'
  const materialName = (id: string) => rawMaterials.find((m) => m.id === id)?.name ?? "-";
  const materialUnitAbbrev = (id: string) => packagingUnitAbbrev(rawMaterials.find((m) => m.id === id)?.unit);
'@
    },
    @{
        description = "Wrappers table: 'Grams per Unit' column -> unit-aware per row"
        anchor = @'
    { accessorKey: "gramsPerUnit", header: "Grams per Unit", cell: ({ getValue }) => `${(getValue() as number).toLocaleString()} g` },
    { id: "unitCost", header: "Derived Unit Cost", cell: ({ row }) => `Rs. ${wrapperUnitCost(row.original.id).toFixed(2)}` },
'@
        replacement = @'
    { accessorKey: "gramsPerUnit", header: "Qty per Unit", cell: ({ row }) => `${row.original.gramsPerUnit.toLocaleString()} ${materialUnitAbbrev(row.original.rawMaterialId)}` },
    { id: "unitCost", header: "Derived Unit Cost", cell: ({ row }) => `Rs. ${wrapperUnitCost(row.original.id).toFixed(2)}` },
'@
    },
    @{
        description = "Boxes table: 'Grams per Unit' column -> unit-aware per row"
        anchor = @'
    { accessorKey: "gramsPerUnit", header: "Grams per Unit", cell: ({ getValue }) => `${(getValue() as number).toLocaleString()} g` },
    { id: "unitCost", header: "Derived Unit Cost", cell: ({ row }) => `Rs. ${boxUnitCost(row.original.id).toFixed(2)}` },
'@
        replacement = @'
    { accessorKey: "gramsPerUnit", header: "Qty per Unit", cell: ({ row }) => `${row.original.gramsPerUnit.toLocaleString()} ${materialUnitAbbrev(row.original.rawMaterialId)}` },
    { id: "unitCost", header: "Derived Unit Cost", cell: ({ row }) => `Rs. ${boxUnitCost(row.original.id).toFixed(2)}` },
'@
    }
)
Edit-FileWithSteps -Path $PackagingPagePath -Steps $packagingSteps

# -------------------------------------------------------------------------
# 4. packaging/carton-config/page.tsx - same hardcoded-grams bug in cost preview
# -------------------------------------------------------------------------
Write-Step "Fixing apps/frontend/app/(dashboard)/packaging/carton-config/page.tsx..."

$cartonConfigSteps = @(
    @{
        description = "Import the shared, unit-aware cost helper"
        anchor = @'
import { useStore, type CartonConfiguration } from "@/lib/store";
'@
        replacement = @'
import { useStore, type CartonConfiguration, computePackagingUnitCost } from "@/lib/store";
'@
    },
    @{
        description = "Remove local costPerGram() that hardcoded a /1000 conversion for every non-'g' unit"
        anchor = @'
  // Packaging cost build-up (BRS v1.2 sec 1.1; Frontend spec v2.2 sec 5.13
  // "Carton Configuration cost preview"). Grams-per-unit is always in
  // grams; the underlying Raw Material's avgUnitCost is per its stock
  // `unit`. Assume that unit is "kg" unless it is literally "g".
  const costPerGram = (rawMaterialId: string) => {
    const rm = rawMaterials.find((r) => r.id === rawMaterialId);
    if (!rm) return 0;
    return rm.unit === "g" ? rm.avgUnitCost : rm.avgUnitCost / 1000;
  };
'@
        replacement = @'
  // Packaging cost build-up (BRS v1.2 sec 1.1; Frontend spec v2.2 sec 5.13
  // "Carton Configuration cost preview"). ISSUE 8 FIX: this used to assume
  // every raw material was tracked in kg/g and hardcoded a /1000
  // conversion for anything that was not literally "g" - silently wrong
  // for piece/dozen/litre/etc. Now reuses the shared, unit-aware
  // computePackagingUnitCost() from the store, which multiplies directly
  // in the raw material's own unit with no assumed conversion.
'@
    },
    @{
        description = "Use computePackagingUnitCost instead of the removed costPerGram()"
        anchor = @'
  const costPerWrapper = selectedWrapper ? selectedWrapper.gramsPerUnit * costPerGram(selectedWrapper.rawMaterialId) : 0;
  const costPerBox = selectedBox ? selectedBox.gramsPerUnit * costPerGram(selectedBox.rawMaterialId) : 0;
'@
        replacement = @'
  const costPerWrapper = selectedWrapper ? computePackagingUnitCost(selectedWrapper.gramsPerUnit, rawMaterials.find((r) => r.id === selectedWrapper.rawMaterialId)) : 0;
  const costPerBox = selectedBox ? computePackagingUnitCost(selectedBox.gramsPerUnit, rawMaterials.find((r) => r.id === selectedBox.rawMaterialId)) : 0;
'@
    }
)
Edit-FileWithSteps -Path $CartonConfigPath -Steps $cartonConfigSteps

# -------------------------------------------------------------------------
# 5. SQL migration - read-only diagnostic view (no data changes)
# -------------------------------------------------------------------------
Write-Step "Adding fractional-stock diagnostic view (read-only, no data changed)..."

if (-not (Test-Path $MigrationsDir)) { New-Item -ItemType Directory -Force -Path $MigrationsDir | Out-Null }

$existingDiag = Get-ChildItem -Path $MigrationsDir -Filter "*_add_fractional_stock_diagnostic_view.sql" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existingDiag) {
    Write-Ok "Diagnostic view migration already exists: $($existingDiag.FullName) - skipping."
}
else {
    $diagSql = @'
-- ISSUE 8: read-only diagnostic view. Flags any Wrapper/Box whose
-- underlying raw material's unit implies whole numbers (piece, dozen,
-- box, packet, bag) but whose CURRENT stock quantity is not a whole
-- number - e.g. Box Paper showing "24.98". This is a strong signal of
-- historical stock corruption from the grams-hardcoded bug and needs a
-- manual correction; this view changes no data, it only reports.
create or replace view v_fractional_stock_flags as
select
  'wrapper'::text as item_type,
  w.id as item_id,
  w.name as item_name,
  w.stock_qty as recorded_stock,
  rm.unit as raw_material_unit,
  rm.name as raw_material_name,
  rm.quantity_in_stock as raw_material_stock
from wrappers w
join raw_materials rm on rm.id = w.raw_material_id
where lower(trim(rm.unit)) in ('piece','dozen','box','packet','bag')
  and w.stock_qty <> floor(w.stock_qty)
union all
select
  'box'::text as item_type,
  b.id as item_id,
  b.name as item_name,
  b.stock_qty as recorded_stock,
  rm.unit as raw_material_unit,
  rm.name as raw_material_name,
  rm.quantity_in_stock as raw_material_stock
from boxes b
join raw_materials rm on rm.id = b.raw_material_id
where lower(trim(rm.unit)) in ('piece','dozen','box','packet','bag')
  and b.stock_qty <> floor(b.stock_qty)
union all
select
  'raw_material'::text as item_type,
  rm.id as item_id,
  rm.name as item_name,
  rm.quantity_in_stock as recorded_stock,
  rm.unit as raw_material_unit,
  rm.name as raw_material_name,
  rm.quantity_in_stock as raw_material_stock
from raw_materials rm
where lower(trim(rm.unit)) in ('piece','dozen','box','packet','bag')
  and rm.quantity_in_stock <> floor(rm.quantity_in_stock);

comment on view v_fractional_stock_flags is
  'ISSUE 8 diagnostic: piece/dozen/box/packet/bag-unit items with a fractional stock quantity. Read-only - query after deploying the Issue 8 unit-mismatch fix, then manually correct anything it lists.';
'@
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $diagFile = Join-Path $MigrationsDir "${timestamp}_add_fractional_stock_diagnostic_view.sql"
    Set-Content -Path $diagFile -Value $diagSql -Encoding UTF8
    Write-Ok "Migration written: $diagFile"
}

# -------------------------------------------------------------------------
# Done
# -------------------------------------------------------------------------
Write-Step "Done."
Write-Host ""
Write-Host "  Frontend labels/calcs for Define Box/Wrapper, Produce, and the" -ForegroundColor White
Write-Host "  packaging list/carton-config cost preview no longer hardcode grams." -ForegroundColor White
Write-Host ""
Write-Warn2 "IMPORTANT: fn_produce_box / fn_produce_wrapper (Postgres RPC functions)"
Write-Warn2 "are NOT in your code export, so the real server-side stock deduction"
Write-Warn2 "could not be patched here. Run this in the Supabase SQL editor and"
Write-Warn2 "send me the result so I can give you the exact SQL fix:"
Write-Host ""
Write-Host "    select pg_get_functiondef(oid) from pg_proc" -ForegroundColor Gray
Write-Host "    where proname in ('fn_produce_box','fn_produce_wrapper');" -ForegroundColor Gray
Write-Host ""
Write-Warn2 "After applying the new migration, run this to find any leftover"
Write-Warn2 "corrupted stock values (like Box Paper's 24.98) that need manual fixing:"
Write-Host ""
Write-Host "    select * from v_fractional_stock_flags;" -ForegroundColor Gray
Write-Host ""