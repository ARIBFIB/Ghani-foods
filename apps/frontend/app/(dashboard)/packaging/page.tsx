"use client";

import { useMemo, useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useForm, Controller } from "react-hook-form";
import { SearchableSelect } from "@/components/ui/searchable-select";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "@/components/ui/toast";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type Wrapper, type Box, type RawMaterial, packagingQtyLabel, packagingUnitAbbrev } from "@/lib/store";
import {
  wrapperDefinitionSchema,
  boxDefinitionSchema,
  productionRunSchema,
  type WrapperDefinitionFormValues,
  type BoxDefinitionFormValues,
  type ProductionRunFormValues,
} from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";

function StatusBadge({ isLow }: { isLow: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      isLow ? "bg-red-950 text-red-400 border border-red-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {isLow ? "Low Stock" : "OK"}
    </span>
  );
}

function InfoTip({ text }: { text: string }) {
  return (
    <span
      title={text}
      className="ml-1 inline-flex h-4 w-4 items-center justify-center rounded-full border border-[var(--surface-border-strong)] text-[10px] leading-none text-[var(--text-muted)] cursor-help select-none align-middle"
    >
      i
    </span>
  );
}

type PackagingKind = "wrapper" | "box";

function DefineDialog({ kind, open, onClose }: { kind: PackagingKind; open: boolean; onClose: () => void }) {
  const rawMaterials = useStore((s) => s.rawMaterials);
  const addWrapper = useStore((s) => s.addWrapper);
  const addBox = useStore((s) => s.addBox);
  const schema = kind === "wrapper" ? wrapperDefinitionSchema : boxDefinitionSchema;

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

  const onSubmit = async (values: WrapperDefinitionFormValues) => {
    if (kind === "wrapper") addWrapper(values);
    else addBox(values);
    toast.success(`${label} "${values.name}" defined`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Define {label}</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Name</label>
            <input {...register("name")} placeholder={kind === "wrapper" ? "e.g. Rs. 5 Wrapper" : "e.g. Box (12 packets)"}
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Underlying Raw Material</label>
            <Controller
              control={control}
              name="rawMaterialId"
              render={({ field }) => (
                <SearchableSelect
                  value={field.value}
                  onChange={field.onChange}
                  options={rawMaterials.map((m: RawMaterial) => ({ value: m.id, label: `${m.name}${m.category ? ` - ${m.category}` : ""} (${m.unit})` }))}
                  placeholder="Select raw material..."
                  searchPlaceholder="Search raw materials..."
                  className="mt-1"
                />
              )}
            />
            {errors.rawMaterialId && <p className="text-xs text-red-400 mt-1">{errors.rawMaterialId.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)] inline-flex items-center">
              {qtyPerUnitLabel}
              <InfoTip text={`How many ${(selectedRawMaterial?.unit || "units").toLowerCase()} of the underlying raw material are used to make one ${label.toLowerCase()}`} />
            </label>
            <input {...register("gramsPerUnit")} type="number" step="any"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.gramsPerUnit && <p className="text-xs text-red-400 mt-1">{errors.gramsPerUnit.message}</p>}
          </div>
          <div>
            <label className="text-sm text-[var(--text-muted)]">Low Stock Threshold</label>
            <input {...register("lowStockThreshold")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.lowStockThreshold && <p className="text-xs text-red-400 mt-1">{errors.lowStockThreshold.message}</p>}
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

type ProduceTarget = { kind: PackagingKind; item: Wrapper | Box } | null;

function ProduceDialog({ target, onClose }: { target: ProduceTarget; onClose: () => void }) {
  const rawMaterials = useStore((s) => s.rawMaterials);
  const produceWrapper = useStore((s) => s.produceWrapper);
  const produceBox = useStore((s) => s.produceBox);

  const { register, handleSubmit, reset, watch, formState: { errors, isSubmitting } } = useForm<ProductionRunFormValues>({
    resolver: zodResolver(productionRunSchema),
    defaultValues: { quantityProduced: 1 },
  });

  const quantityProducedRaw = watch("quantityProduced");
  const quantityProduced = Number(quantityProducedRaw) || 0;

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

  const onSubmit = async (values: ProductionRunFormValues) => {
    const result = kind === "wrapper" ? await produceWrapper(item.id, values.quantityProduced) : await produceBox(item.id, values.quantityProduced);
    if (!result.ok) {
      toast.error(result.reason ?? "Could not complete production run");
      return;
    }
    toast.success(`Produced ${values.quantityProduced} x ${item.name}`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Produce: {item.name}</h2>

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

        <div>
          <label className="text-sm text-[var(--text-muted)]">Quantity to Produce</label>
          <input {...register("quantityProduced")} type="number" min={1}
            className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
          {errors.quantityProduced && <p className="text-xs text-red-400 mt-1">{errors.quantityProduced.message}</p>}
        </div>

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

        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]">Cancel</button>
          <button type="submit" disabled={isSubmitting || insufficient} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50">
            {isSubmitting ? "Producing..." : "Confirm"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function PackagingPage() {
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const wrapperUnitCost = useStore((s) => s.wrapperUnitCost);
  const boxUnitCost = useStore((s) => s.boxUnitCost);
  const loadPackagingModule = useStore((s) => s.loadPackagingModule);

  const [tab, setTab] = useState<"wrappers" | "boxes">("wrappers");
  const [defineOpen, setDefineOpen] = useState<PackagingKind | null>(null);
  const [produceTarget, setProduceTarget] = useState<ProduceTarget>(null);

  const materialName = (id: string) => rawMaterials.find((m) => m.id === id)?.name ?? "-";
  const materialUnitAbbrev = (id: string) => packagingUnitAbbrev(rawMaterials.find((m) => m.id === id)?.unit);

  const wrapperColumns = useMemo<ColumnDef<Wrapper, unknown>[]>(() => [
    { accessorKey: "name", header: "Name", cell: ({ getValue }) => <span className="text-[var(--foreground)]">{getValue() as string}</span> },
    { id: "rawMaterial", header: "Underlying Raw Material", cell: ({ row }) => materialName(row.original.rawMaterialId) },
    { accessorKey: "gramsPerUnit", header: "Qty per Unit", cell: ({ row }) => `${row.original.gramsPerUnit.toLocaleString()} ${materialUnitAbbrev(row.original.rawMaterialId)}` },
    { id: "unitCost", header: "Derived Unit Cost", cell: ({ row }) => `Rs. ${wrapperUnitCost(row.original.id).toFixed(2)}` },
    { accessorKey: "stockQty", header: "Stock Qty", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    { accessorKey: "lowStockThreshold", header: "Threshold", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge isLow={row.original.stockQty < row.original.lowStockThreshold} />,
    },
    {
      id: "action", header: "", enableSorting: false,
      cell: ({ row }) => (
        <button onClick={() => setProduceTarget({ kind: "wrapper", item: row.original })}
          className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Produce
        </button>
      ),
    },
  ], [rawMaterials, wrapperUnitCost]);

  const boxColumns = useMemo<ColumnDef<Box, unknown>[]>(() => [
    { accessorKey: "name", header: "Name", cell: ({ getValue }) => <span className="text-[var(--foreground)]">{getValue() as string}</span> },
    { id: "rawMaterial", header: "Underlying Raw Material", cell: ({ row }) => materialName(row.original.rawMaterialId) },
    { accessorKey: "gramsPerUnit", header: "Qty per Unit", cell: ({ row }) => `${row.original.gramsPerUnit.toLocaleString()} ${materialUnitAbbrev(row.original.rawMaterialId)}` },
    { id: "unitCost", header: "Derived Unit Cost", cell: ({ row }) => `Rs. ${boxUnitCost(row.original.id).toFixed(2)}` },
    { accessorKey: "stockQty", header: "Stock Qty", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    { accessorKey: "lowStockThreshold", header: "Threshold", cell: ({ getValue }) => (getValue() as number).toLocaleString() },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge isLow={row.original.stockQty < row.original.lowStockThreshold} />,
    },
    {
      id: "action", header: "", enableSorting: false,
      cell: ({ row }) => (
        <button onClick={() => setProduceTarget({ kind: "box", item: row.original })}
          className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
          Produce
        </button>
      ),
    },
  ], [rawMaterials, boxUnitCost]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Packaging Materials</h1>
        <div className="flex items-center gap-2">
          <NavLink href="/packaging/carton-config" className="rounded-lg border border-neutral-400 dark:border-neutral-600 px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
            Define Carton Configuration
          </NavLink>
          {tab === "wrappers" ? (
            <button onClick={() => setDefineOpen("wrapper")} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
              + Define Wrapper
            </button>
          ) : (
            <button onClick={() => setDefineOpen("box")} className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity">
              + Define Box
            </button>
          )}
        </div>
      </div>

      <div className="flex gap-2 border-b border-[var(--surface-border)]">
        <button onClick={() => setTab("wrappers")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "wrappers" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Wrappers
        </button>
        <button onClick={() => setTab("boxes")} className={`px-4 py-2 text-sm font-medium border-b-2 ${tab === "boxes" ? "border-neutral-900 dark:border-neutral-50 text-[var(--foreground)]" : "border-transparent text-[var(--text-muted)]"}`}>
          Boxes
        </button>
      </div>

      {tab === "wrappers" ? (
        <SortableTable data={wrappers} columns={wrapperColumns} globalFilterPlaceholder="Search wrappers..." onRefresh={loadPackagingModule} />
      ) : (
        <SortableTable data={boxes} columns={boxColumns} globalFilterPlaceholder="Search boxes..." onRefresh={loadPackagingModule} />
      )}

      <DefineDialog kind={defineOpen ?? "wrapper"} open={defineOpen !== null} onClose={() => setDefineOpen(null)} />
      <ProduceDialog target={produceTarget} onClose={() => setProduceTarget(null)} />
    </div>
  );
}