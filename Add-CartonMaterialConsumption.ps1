<#
  Add-CartonMaterialConsumption.ps1
  -----------------------------------------------------------------------
  ISSUE 9: Carton itself should be a consumable item in Carton Configuration.

  Client's clarified requirement: "During new carton configuration there
  should be an option to add a carton from raw material because that also
  need to be consumed during making of that [carton]."

  WHAT THIS SCRIPT DOES:
    1. DB migration:
       - Adds carton_material_id (references raw_materials) and
         carton_qty_per_carton to carton_configurations. Nullable/defaulted
         so existing configurations are not broken.
       - Adds a NEW function fn_deduct_carton_material(p_config_id, p_qty)
         that deducts the carton material's stock, unit-safe (same
         no-hardcoded-conversion rule as Issue 8) - i.e. carton_qty_per_
         carton is read in the raw material's own unit and multiplied
         directly, no assumed grams/kg conversion.
    2. Frontend - "New Carton Configuration" dialog:
       - New "Carton Material" field, pulled from your Raw Materials list
         (per the client's own words: "add a carton from raw material"),
         same picker style as Define Box's "Underlying Raw Material".
       - New per-carton quantity field with a dynamic unit label (reuses
         the Issue 8 packagingQtyLabel()/packagingUnitAbbrev() helpers).
       - Cost Build-Up preview now includes "Cost / Carton Material".
    3. Frontend - Carton Configurations list: new "Carton Material" column.
    4. Backend edge functions (carton-configurations-create/update): now
       accept/store cartonMaterialId + cartonQtyPerCarton.
    5. Backend edge function (packing-runs): after the existing
       fn_create_packing_run call succeeds, also calls the new
       fn_deduct_carton_material RPC so the carton's own stock is deducted
       every time a packing run actually produces cartons.

  WHY fn_create_packing_run ITSELF WAS NOT EDITED (important, please read):
  fn_create_packing_run already deducts wrapper/box/bulk-product stock and
  creates finished_cartons rows - real, working, business-critical logic
  whose current body is not in your code export. Blindly guessing and
  overwriting it (like fn_produce_box/fn_produce_wrapper in Issue 8, which
  were much simpler) risks silently breaking batch/leftover/finished-
  carton accounting that already works correctly today. Instead, carton
  material deduction is added as its own small, isolated, additive
  function called right after the existing one succeeds. This achieves
  the same end result - carton stock goes down every time cartons are
  produced - without touching code I cannot see. If you want the two
  merged into a single atomic DB transaction later, send me
  fn_create_packing_run's definition (same query as Issue 8):
      select pg_get_functiondef(oid) from pg_proc where proname = 'fn_create_packing_run';

  USAGE:
    cd "D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods"
    .\Add-CartonMaterialConsumption.ps1

  Idempotent - safe to re-run.
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

$StorePath                = Join-Path $FrontendDir "lib\store.ts"
$SchemasPath               = Join-Path $FrontendDir "lib\schemas.ts"
$CartonConfigPagePath      = Join-Path $FrontendDir "app\(dashboard)\packaging\carton-config\page.tsx"
$CartonCreateFnPath        = Join-Path $BackendDir "supabase\functions\carton-configurations-create\index.ts"
$CartonUpdateFnPath        = Join-Path $BackendDir "supabase\functions\carton-configurations-update\index.ts"
$PackingRunsFnPath         = Join-Path $BackendDir "supabase\functions\packing-runs\index.ts"

Write-Ok "Project root: $ProjectRoot"

# -------------------------------------------------------------------------
# 1. SQL migration - new columns + isolated deduction function
# -------------------------------------------------------------------------
Write-Step "Adding carton_material_id/carton_qty_per_carton + fn_deduct_carton_material..."

if (-not (Test-Path $MigrationsDir)) { New-Item -ItemType Directory -Force -Path $MigrationsDir | Out-Null }

$existingMigration = Get-ChildItem -Path $MigrationsDir -Filter "*_add_carton_material_consumption.sql" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existingMigration) {
    Write-Ok "Migration already exists: $($existingMigration.FullName) - skipping."
}
else {
    $sql = @'
-- ISSUE 9: the physical carton itself must be a consumable raw-material
-- item in Carton Configuration, deducted from stock on every packing run.

alter table carton_configurations
  add column if not exists carton_material_id uuid references raw_materials(id),
  add column if not exists carton_qty_per_carton numeric not null default 0;

-- Deliberately kept SEPARATE from fn_create_packing_run (whose current
-- body is not available to patch directly - see script header comment).
-- Skips quietly (no-op) for configurations created before this migration
-- that have no carton_material_id set yet, so old packing runs are not
-- blocked.
create or replace function fn_deduct_carton_material(p_config_id uuid, p_cartons_produced numeric)
returns void
language plpgsql
as $$
declare
  v_config carton_configurations%rowtype;
  v_raw_material raw_materials%rowtype;
  v_qty_needed numeric;
begin
  if p_cartons_produced is null or p_cartons_produced <= 0 then
    raise exception 'Cartons produced must be greater than 0';
  end if;

  select * into v_config from carton_configurations where id = p_config_id for update;
  if not found then
    raise exception 'Carton configuration % not found', p_config_id;
  end if;

  if v_config.carton_material_id is null then
    return;
  end if;

  select * into v_raw_material from raw_materials where id = v_config.carton_material_id for update;
  if not found then
    raise exception 'Carton material for configuration % not found', p_config_id;
  end if;

  -- No hardcoded grams / no silent conversion (Issue 8 convention):
  -- carton_qty_per_carton is defined in the raw material's own unit.
  v_qty_needed := coalesce(v_config.carton_qty_per_carton, 0) * p_cartons_produced;

  if v_qty_needed <= 0 then
    return;
  end if;

  if v_raw_material.quantity_in_stock < v_qty_needed then
    raise exception 'Insufficient stock of % - need % % but only % % available',
      v_raw_material.name, v_qty_needed, v_raw_material.unit, v_raw_material.quantity_in_stock, v_raw_material.unit;
  end if;

  update raw_materials
     set quantity_in_stock = quantity_in_stock - v_qty_needed
   where id = v_raw_material.id;
end;
$$;
'@
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $migrationFile = Join-Path $MigrationsDir "${timestamp}_add_carton_material_consumption.sql"
    Set-Content -Path $migrationFile -Value $sql -Encoding UTF8
    Write-Ok "Migration written: $migrationFile"
}

# -------------------------------------------------------------------------
# 2. lib/schemas.ts
# -------------------------------------------------------------------------
Write-Step "Fixing apps/frontend/lib/schemas.ts..."

$schemasSteps = @(
    @{
        description = "cartonConfigSchema: require cartonMaterialId + cartonQtyPerCarton"
        anchor = @'
export const cartonConfigSchema = z.object({
  name: z.string().trim().min(1, "Configuration name is required"),
  wrapperId: z.string().min(1, "Select a wrapper"),
  packetsPerBox: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
  boxId: z.string().min(1, "Select a box"),
  boxesPerCarton: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
});
'@
        replacement = @'
export const cartonConfigSchema = z.object({
  name: z.string().trim().min(1, "Configuration name is required"),
  wrapperId: z.string().min(1, "Select a wrapper"),
  packetsPerBox: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
  boxId: z.string().min(1, "Select a box"),
  boxesPerCarton: z.coerce.number().int("Must be a whole number").positive("Must be greater than 0"),
  // ISSUE 9: the physical carton itself is now a required, consumable input.
  cartonMaterialId: z.string().min(1, "Select the physical carton material"),
  cartonQtyPerCarton: z.coerce.number().positive("Must be greater than 0"),
});
'@
    }
)
Edit-FileWithSteps -Path $SchemasPath -Steps $schemasSteps

# -------------------------------------------------------------------------
# 3. lib/store.ts
# -------------------------------------------------------------------------
Write-Step "Fixing apps/frontend/lib/store.ts..."

$storeSteps = @(
    @{
        description = "mapCartonConfigRow: read carton_material_id/carton_qty_per_carton"
        anchor = @'
function mapCartonConfigRow(row: Record<string, any>): CartonConfiguration {
  return {
    id: row.id,
    name: row.name,
    wrapperId: row.wrapper_id,
    packetsPerBox: Number(row.packets_per_box),
    boxId: row.box_id,
    boxesPerCarton: Number(row.boxes_per_carton),
    usedInPackingRun: Boolean(row.used_in_packing_run),
  };
}
'@
        replacement = @'
function mapCartonConfigRow(row: Record<string, any>): CartonConfiguration {
  return {
    id: row.id,
    name: row.name,
    wrapperId: row.wrapper_id,
    packetsPerBox: Number(row.packets_per_box),
    boxId: row.box_id,
    boxesPerCarton: Number(row.boxes_per_carton),
    cartonMaterialId: row.carton_material_id ?? "",
    cartonQtyPerCarton: Number(row.carton_qty_per_carton ?? 0),
    usedInPackingRun: Boolean(row.used_in_packing_run),
  };
}
'@
    },
    @{
        description = "CartonConfiguration type: add cartonMaterialId/cartonQtyPerCarton"
        anchor = @'
export type CartonConfiguration = {
  id: string;
  name: string;
  wrapperId: string;
  packetsPerBox: number;
  boxId: string;
  boxesPerCarton: number;
  usedInPackingRun: boolean;
};
'@
        replacement = @'
export type CartonConfiguration = {
  id: string;
  name: string;
  wrapperId: string;
  packetsPerBox: number;
  boxId: string;
  boxesPerCarton: number;
  cartonMaterialId: string;
  cartonQtyPerCarton: number;
  usedInPackingRun: boolean;
};
'@
    },
    @{
        description = "addCartonConfiguration signature: accept cartonMaterialId/cartonQtyPerCarton"
        anchor = @'
  addCartonConfiguration: (input: {
    name: string;
    wrapperId: string;
    packetsPerBox: number;
    boxId: string;
    boxesPerCarton: number;
  }) => Promise<string>;
'@
        replacement = @'
  addCartonConfiguration: (input: {
    name: string;
    wrapperId: string;
    packetsPerBox: number;
    boxId: string;
    boxesPerCarton: number;
    cartonMaterialId: string;
    cartonQtyPerCarton: number;
  }) => Promise<string>;
'@
    },
    @{
        description = "updateCartonConfiguration signature: allow editing cartonMaterialId/cartonQtyPerCarton"
        anchor = @'
  updateCartonConfiguration: (id: string, patch: { name?: string; packetsPerBox?: number; boxesPerCarton?: number }) => Promise<{ ok: boolean; reason?: string }>;
'@
        replacement = @'
  updateCartonConfiguration: (id: string, patch: { name?: string; packetsPerBox?: number; boxesPerCarton?: number; cartonMaterialId?: string; cartonQtyPerCarton?: number }) => Promise<{ ok: boolean; reason?: string }>;
'@
    }
)
Edit-FileWithSteps -Path $StorePath -Steps $storeSteps

# -------------------------------------------------------------------------
# 4. carton-config/page.tsx - UI
# -------------------------------------------------------------------------
Write-Step "Fixing apps/frontend/app/(dashboard)/packaging/carton-config/page.tsx..."

$cartonPageSteps = @(
    @{
        description = "Import Issue 8 unit-label helpers alongside computePackagingUnitCost"
        anchor = @'
import { useStore, type CartonConfiguration, computePackagingUnitCost } from "@/lib/store";
'@
        replacement = @'
import { useStore, type CartonConfiguration, computePackagingUnitCost, packagingQtyLabel, packagingUnitAbbrev } from "@/lib/store";
'@
    },
    @{
        description = "AddConfigDialog: default values + watch cartonMaterialId/cartonQtyPerCarton + cost calc"
        anchor = @'
  const { register, handleSubmit, control, watch, reset, formState: { errors, isSubmitting } } = useForm<CartonConfigFormValues>({
    resolver: zodResolver(cartonConfigSchema),
    defaultValues: { name: "", wrapperId: wrappers[0]?.id ?? "", packetsPerBox: 12, boxId: boxes[0]?.id ?? "", boxesPerCarton: 4 },
  });

  const name = watch("name");
  const wrapperId = watch("wrapperId");
  const boxId = watch("boxId");
  const packetsPerBox = watch("packetsPerBox");
  const boxesPerCarton = watch("boxesPerCarton");

  if (!open) return null;

  const totalPacketsPerCarton = (Number(packetsPerBox) || 0) * (Number(boxesPerCarton) || 0);

  const selectedWrapper = wrappers.find((w) => w.id === wrapperId);
  const selectedBox = boxes.find((b) => b.id === boxId);
  const costPerWrapper = selectedWrapper ? computePackagingUnitCost(selectedWrapper.gramsPerUnit, rawMaterials.find((r) => r.id === selectedWrapper.rawMaterialId)) : 0;
  const costPerBox = selectedBox ? computePackagingUnitCost(selectedBox.gramsPerUnit, rawMaterials.find((r) => r.id === selectedBox.rawMaterialId)) : 0;
  const costPerPacket = costPerWrapper;
  const costPerBoxAssembled = costPerBox + (Number(packetsPerBox) || 0) * costPerWrapper;
  const costPerCarton = (Number(boxesPerCarton) || 0) * costPerBoxAssembled;
'@
        replacement = @'
  const { register, handleSubmit, control, watch, reset, formState: { errors, isSubmitting } } = useForm<CartonConfigFormValues>({
    resolver: zodResolver(cartonConfigSchema),
    defaultValues: { name: "", wrapperId: wrappers[0]?.id ?? "", packetsPerBox: 12, boxId: boxes[0]?.id ?? "", boxesPerCarton: 4, cartonMaterialId: rawMaterials[0]?.id ?? "", cartonQtyPerCarton: 1 },
  });

  const name = watch("name");
  const wrapperId = watch("wrapperId");
  const boxId = watch("boxId");
  const packetsPerBox = watch("packetsPerBox");
  const boxesPerCarton = watch("boxesPerCarton");
  // ISSUE 9: the physical carton itself is a consumable raw material too,
  // and needs to be selected + deducted just like Wrapper/Box already are.
  const cartonMaterialId = watch("cartonMaterialId");
  const cartonQtyPerCarton = watch("cartonQtyPerCarton");

  if (!open) return null;

  const totalPacketsPerCarton = (Number(packetsPerBox) || 0) * (Number(boxesPerCarton) || 0);

  const selectedWrapper = wrappers.find((w) => w.id === wrapperId);
  const selectedBox = boxes.find((b) => b.id === boxId);
  const selectedCartonMaterial = rawMaterials.find((r) => r.id === cartonMaterialId);
  const costPerWrapper = selectedWrapper ? computePackagingUnitCost(selectedWrapper.gramsPerUnit, rawMaterials.find((r) => r.id === selectedWrapper.rawMaterialId)) : 0;
  const costPerBox = selectedBox ? computePackagingUnitCost(selectedBox.gramsPerUnit, rawMaterials.find((r) => r.id === selectedBox.rawMaterialId)) : 0;
  const costPerCartonMaterial = selectedCartonMaterial ? computePackagingUnitCost(Number(cartonQtyPerCarton) || 0, selectedCartonMaterial) : 0;
  const costPerPacket = costPerWrapper;
  const costPerBoxAssembled = costPerBox + (Number(packetsPerBox) || 0) * costPerWrapper;
  const costPerCarton = (Number(boxesPerCarton) || 0) * costPerBoxAssembled + costPerCartonMaterial;
'@
    },
    @{
        description = "Insert Carton Material picker + qty field into the form"
        anchor = @'
          <div>
            <label className="text-sm text-[var(--text-muted)]">Boxes per Carton</label>
            <input {...register("boxesPerCarton")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.boxesPerCarton && <p className="text-xs text-red-400 mt-1">{errors.boxesPerCarton.message}</p>}
          </div>

          {wrapperId && boxId && totalPacketsPerCarton > 0 && (
'@
        replacement = @'
          <div>
            <label className="text-sm text-[var(--text-muted)]">Boxes per Carton</label>
            <input {...register("boxesPerCarton")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.boxesPerCarton && <p className="text-xs text-red-400 mt-1">{errors.boxesPerCarton.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Carton Material</label>
            <Controller
              control={control}
              name="cartonMaterialId"
              render={({ field }) => (
                <SearchableSelect
                  value={field.value}
                  onChange={field.onChange}
                  options={rawMaterials.map((m) => ({ value: m.id, label: `${m.name}${m.category ? ` - ${m.category}` : ""} (${m.unit})` }))}
                  placeholder="Select the physical carton..."
                  searchPlaceholder="Search raw materials..."
                  className="mt-1"
                />
              )}
            />
            <p className="mt-1 text-[11px] text-[var(--text-muted)]">The physical carton this configuration is packed into - consumed from stock, same as Wrapper/Box, every time this configuration is produced.</p>
            {errors.cartonMaterialId && <p className="text-xs text-red-400 mt-1">{errors.cartonMaterialId.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)] inline-flex items-center">
              {packagingQtyLabel(selectedCartonMaterial?.unit)}
              <InfoTip text={`How many ${(selectedCartonMaterial?.unit || "units").toLowerCase()} of the carton material are consumed per carton produced`} />
            </label>
            <input {...register("cartonQtyPerCarton")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.cartonQtyPerCarton && <p className="text-xs text-red-400 mt-1">{errors.cartonQtyPerCarton.message}</p>}
          </div>

          {wrapperId && boxId && totalPacketsPerCarton > 0 && (
'@
    },
    @{
        description = "Cost Build-Up preview: add Cost / Carton Material row"
        anchor = @'
              <div className="grid grid-cols-2 gap-x-3 gap-y-1">
                <span>Cost / Wrapper (Packet)</span><span className="text-right text-[var(--foreground)]">Rs. {costPerPacket.toFixed(2)}</span>
                <span>Cost / Box</span><span className="text-right text-[var(--foreground)]">Rs. {costPerBox.toFixed(2)}</span>
                <span>Cost / Box (assembled)</span><span className="text-right text-[var(--foreground)]">Rs. {costPerBoxAssembled.toFixed(2)}</span>
                <span className="font-medium">Cost / Carton</span><span className="text-right text-[var(--foreground)] font-medium">Rs. {costPerCarton.toFixed(2)}</span>
              </div>
'@
        replacement = @'
              <div className="grid grid-cols-2 gap-x-3 gap-y-1">
                <span>Cost / Wrapper (Packet)</span><span className="text-right text-[var(--foreground)]">Rs. {costPerPacket.toFixed(2)}</span>
                <span>Cost / Box</span><span className="text-right text-[var(--foreground)]">Rs. {costPerBox.toFixed(2)}</span>
                <span>Cost / Box (assembled)</span><span className="text-right text-[var(--foreground)]">Rs. {costPerBoxAssembled.toFixed(2)}</span>
                <span>Cost / Carton Material</span><span className="text-right text-[var(--foreground)]">Rs. {costPerCartonMaterial.toFixed(2)}</span>
                <span className="font-medium">Cost / Carton</span><span className="text-right text-[var(--foreground)] font-medium">Rs. {costPerCarton.toFixed(2)}</span>
              </div>
'@
    },
    @{
        description = "Update Cost Build-Up InfoTip wording to mention Carton Material"
        anchor = @'
                <InfoTip text="Derived from each Wrapper/Box's grams-per-unit x its raw material's current weighted-average cost. Wrapper cost = per packet. Box cost + (Packets/Box x Wrapper cost) = per box. That x Boxes/Carton = per carton. Excludes bulk product cost, which varies per batch." />
'@
        replacement = @'
                <InfoTip text="Derived from each Wrapper/Box/Carton Material's quantity-per-unit x its raw material's current weighted-average cost. Wrapper cost = per packet. Box cost + (Packets/Box x Wrapper cost) = per box. (Boxes/Carton x Box cost) + Carton Material cost = per carton. Excludes bulk product cost, which varies per batch." />
'@
    },
    @{
        description = "CartonConfigPage: pull rawMaterials from the store"
        anchor = @'
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const [dialogOpen, setDialogOpen] = useState(false);
'@
        replacement = @'
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const [dialogOpen, setDialogOpen] = useState(false);
'@
    },
    @{
        description = "List Row type + mapping: add cartonMaterialName"
        anchor = @'
  type Row = CartonConfiguration & { wrapperName: string; boxName: string; packetsPerCarton: number };

  const rows = useMemo<Row[]>(() => {
    return configs.map((c) => {
      const wrapper = wrappers.find((w) => w.id === c.wrapperId);
      const box = boxes.find((b) => b.id === c.boxId);
      return {
        ...c,
        wrapperName: wrapper?.name ?? "Unknown Wrapper",
        boxName: box?.name ?? "Unknown Box",
        packetsPerCarton: c.packetsPerBox * c.boxesPerCarton,
      };
    });
  }, [configs, wrappers, boxes]);
'@
        replacement = @'
  type Row = CartonConfiguration & { wrapperName: string; boxName: string; cartonMaterialName: string; packetsPerCarton: number };

  const rows = useMemo<Row[]>(() => {
    return configs.map((c) => {
      const wrapper = wrappers.find((w) => w.id === c.wrapperId);
      const box = boxes.find((b) => b.id === c.boxId);
      const cartonMaterial = rawMaterials.find((r) => r.id === c.cartonMaterialId);
      return {
        ...c,
        wrapperName: wrapper?.name ?? "Unknown Wrapper",
        boxName: box?.name ?? "Unknown Box",
        cartonMaterialName: cartonMaterial ? `${cartonMaterial.name} (${c.cartonQtyPerCarton} ${packagingUnitAbbrev(cartonMaterial.unit)})` : "Not set",
        packetsPerCarton: c.packetsPerBox * c.boxesPerCarton,
      };
    });
  }, [configs, wrappers, boxes, rawMaterials]);
'@
    },
    @{
        description = "List table: add Carton Material column"
        anchor = @'
    { accessorKey: "boxesPerCarton", header: "Boxes / Carton" },
    { accessorKey: "packetsPerCarton", header: "Packets / Carton" },
'@
        replacement = @'
    { accessorKey: "boxesPerCarton", header: "Boxes / Carton" },
    { accessorKey: "cartonMaterialName", header: "Carton Material" },
    { accessorKey: "packetsPerCarton", header: "Packets / Carton" },
'@
    },
    @{
        description = "canCreate gate: also require at least one raw material"
        anchor = @'
  const canCreate = wrappers.length > 0 && boxes.length > 0;
'@
        replacement = @'
  const canCreate = wrappers.length > 0 && boxes.length > 0 && rawMaterials.length > 0;
'@
    },
    @{
        description = "Disabled-button tooltip wording"
        anchor = @'
          title={canCreate ? undefined : "Add at least one Wrapper and one Box first"}
'@
        replacement = @'
          title={canCreate ? undefined : "Add at least one Wrapper, one Box, and one Raw Material first"}
'@
    },
    @{
        description = "Empty-state warning banner wording"
        anchor = @'
        <div className="rounded-xl border border-amber-900 bg-amber-950 p-4 text-sm text-amber-400">
          You need at least one Wrapper and one Box before creating a carton configuration.
        </div>
'@
        replacement = @'
        <div className="rounded-xl border border-amber-900 bg-amber-950 p-4 text-sm text-amber-400">
          You need at least one Wrapper, one Box, and one Raw Material before creating a carton configuration.
        </div>
'@
    }
)
Edit-FileWithSteps -Path $CartonConfigPagePath -Steps $cartonPageSteps

# -------------------------------------------------------------------------
# 5. Backend edge functions
# -------------------------------------------------------------------------
Write-Step "Fixing apps/backend/supabase/functions/carton-configurations-create/index.ts..."

$cartonCreateSteps = @(
    @{
        description = "Require + insert cartonMaterialId/cartonQtyPerCarton"
        anchor = @'
    if (!body.name || !body.wrapperId || !body.boxId || !body.packetsPerBox || !body.boxesPerCarton) {
      return jsonResponse(envelopeError(
        "name, wrapperId, boxId, packetsPerBox and boxesPerCarton are required", "BAD_REQUEST"
      ), 400, corsHeaders);
    }

    const { data, error } = await supabase
      .from("carton_configurations")
      .insert({
        name: body.name,
        wrapper_id: body.wrapperId,
        packets_per_box: body.packetsPerBox,
        box_id: body.boxId,
        boxes_per_carton: body.boxesPerCarton,
      })
      .select()
      .single();
'@
        replacement = @'
    if (!body.name || !body.wrapperId || !body.boxId || !body.packetsPerBox || !body.boxesPerCarton || !body.cartonMaterialId || !body.cartonQtyPerCarton) {
      return jsonResponse(envelopeError(
        "name, wrapperId, boxId, packetsPerBox, boxesPerCarton, cartonMaterialId and cartonQtyPerCarton are required", "BAD_REQUEST"
      ), 400, corsHeaders);
    }

    const { data, error } = await supabase
      .from("carton_configurations")
      .insert({
        name: body.name,
        wrapper_id: body.wrapperId,
        packets_per_box: body.packetsPerBox,
        box_id: body.boxId,
        boxes_per_carton: body.boxesPerCarton,
        carton_material_id: body.cartonMaterialId,
        carton_qty_per_carton: body.cartonQtyPerCarton,
      })
      .select()
      .single();
'@
    }
)
Edit-FileWithSteps -Path $CartonCreateFnPath -Steps $cartonCreateSteps

Write-Step "Fixing apps/backend/supabase/functions/carton-configurations-update/index.ts..."

$cartonUpdateSteps = @(
    @{
        description = "Allow patching cartonMaterialId/cartonQtyPerCarton"
        anchor = @'
    if (body.boxesPerCarton !== undefined) updatePayload.boxes_per_carton = body.boxesPerCarton;
'@
        replacement = @'
    if (body.boxesPerCarton !== undefined) updatePayload.boxes_per_carton = body.boxesPerCarton;
    if (body.cartonMaterialId !== undefined) updatePayload.carton_material_id = body.cartonMaterialId;
    if (body.cartonQtyPerCarton !== undefined) updatePayload.carton_qty_per_carton = body.cartonQtyPerCarton;
'@
    }
)
Edit-FileWithSteps -Path $CartonUpdateFnPath -Steps $cartonUpdateSteps

Write-Step "Fixing apps/backend/supabase/functions/packing-runs/index.ts..."

$packingRunsSteps = @(
    @{
        description = "After fn_create_packing_run succeeds, also deduct carton material stock"
        anchor = @'
    const { data, error } = await supabase.rpc("fn_create_packing_run", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
'@
        replacement = @'
    const { data, error } = await supabase.rpc("fn_create_packing_run", rpcParams);

    if (error) {
      const status = statusForPgError(error.message);
      return jsonResponse(envelopeError(error.message, error.code ?? "DB_ERROR"), status, corsHeaders);
    }

    // ISSUE 9: also deduct the physical carton material's own stock, same
    // as Wrapper/Box already are. Kept as a separate RPC (instead of
    // editing the existing fn_create_packing_run, whose current body this
    // codebase export does not include) so the already-working bulk/
    // wrapper/box consumption and finished_cartons creation logic in
    // fn_create_packing_run is never touched or risked.
    const { error: cartonMaterialError } = await supabase.rpc("fn_deduct_carton_material", {
      p_config_id: body.configId,
      p_cartons_produced: body.cartonsProduced,
    });
    if (cartonMaterialError) {
      const status = statusForPgError(cartonMaterialError.message);
      return jsonResponse(envelopeError(
        `Packing run was recorded, but carton material stock could not be deducted: ${cartonMaterialError.message}`,
        cartonMaterialError.code ?? "DB_ERROR"
      ), status, corsHeaders);
    }

    return jsonResponse(envelopeSuccess(data), 201, corsHeaders);
'@
    }
)
Edit-FileWithSteps -Path $PackingRunsFnPath -Steps $packingRunsSteps

# -------------------------------------------------------------------------
# 6. Push migration automatically (same as Issue 8 script)
# -------------------------------------------------------------------------
Write-Step "Attempting to apply the migration automatically..."

$supabaseCli = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseCli) {
    Write-Warn2 "Supabase CLI not found on PATH - could not auto-apply."
    Write-Warn2 "Run this yourself from $BackendDir : supabase db push"
}
else {
    Push-Location $BackendDir
    try {
        Write-Ok "Supabase CLI found: $($supabaseCli.Source)"
        Write-Host "    Running: supabase db push" -ForegroundColor Gray
        supabase db push
        Write-Ok "Migration pushed. carton_configurations now has carton_material_id/carton_qty_per_carton, and fn_deduct_carton_material exists."
    }
    catch {
        Write-Warn2 "Auto-push failed: $($_.Exception.Message)"
        Write-Warn2 "Run it yourself from $BackendDir : supabase db push"
    }
    finally {
        Pop-Location
    }
}

# -------------------------------------------------------------------------
# Done
# -------------------------------------------------------------------------
Write-Step "Done."
Write-Host ""
Write-Host "  Carton Configuration now has a required 'Carton Material' field (from" -ForegroundColor White
Write-Host "  your Raw Materials list) with its own per-carton quantity, cost preview" -ForegroundColor White
Write-Host "  row, and list column. Every packing run now also deducts that carton" -ForegroundColor White
Write-Host "  material's stock." -ForegroundColor White
Write-Host ""
Write-Warn2 "Existing carton configurations created BEFORE this migration have no"
Write-Warn2 "carton_material_id set yet - fn_deduct_carton_material will silently skip"
Write-Warn2 "them (won't block their packing runs), but you should open each one and"
Write-Warn2 "set its Carton Material via Edit so it starts being tracked."
Write-Host ""
Write-Warn2 "Also confirm with the client: should 'Carton Material' pull from Raw"
Write-Warn2 "Materials (what this script does, per their own wording 'from raw"
Write-Warn2 "material'), or should it be restricted to a new dedicated 'Carton'"
Write-Warn2 "category within Raw Materials? Easy one-line tweak either way once"
Write-Warn2 "confirmed."
Write-Host ""