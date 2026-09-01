"use client";

import { useMemo, useState } from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "@/components/ui/toast";
import { type ColumnDef } from "@tanstack/react-table";
import { useStore, type CartonConfiguration, computePackagingUnitCost, packagingQtyLabel, packagingUnitAbbrev } from "@/lib/store";
import { cartonConfigSchema, type CartonConfigFormValues } from "@/lib/schemas";
import { SortableTable } from "@/components/ui/sortable-table";
import { InfoTip } from "@/components/ui/info-tip";
import { SearchableSelect } from "@/components/ui/searchable-select";

function StatusBadge({ used }: { used: boolean }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
      used ? "bg-amber-950 text-amber-400 border border-amber-900" : "bg-green-950 text-green-400 border border-green-900"
    }`}>
      {used ? "Used in Packing Run" : "Available"}
    </span>
  );
}

function AddConfigDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const addCartonConfiguration = useStore((s) => s.addCartonConfiguration);

  // Packaging cost build-up (BRS v1.2 sec 1.1; Frontend spec v2.2 sec 5.13
  // "Carton Configuration cost preview"). ISSUE 8 FIX: this used to assume
  // every raw material was tracked in kg/g and hardcoded a /1000
  // conversion for anything that was not literally "g" - silently wrong
  // for piece/dozen/litre/etc. Now reuses the shared, unit-aware
  // computePackagingUnitCost() from the store, which multiplies directly
  // in the raw material's own unit with no assumed conversion.

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

  const onSubmit = async (values: CartonConfigFormValues) => {
    try {
      await addCartonConfiguration(values);
      toast.success("Carton configuration created");
      reset();
      onClose();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to create carton configuration");
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 sm:p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4 max-h-[90vh] overflow-y-auto">
        <h2 className="text-lg font-semibold text-[var(--foreground)]">New Carton Configuration</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-[var(--text-muted)]">Configuration Name</label>
            <input {...register("name")} type="text" placeholder='e.g. "Carton A" or "Rs.5 Nimko 48pk"'
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.name && <p className="text-xs text-red-400 mt-1">{errors.name.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Wrapper</label>
            <Controller
              control={control}
              name="wrapperId"
              render={({ field }) => (
                <SearchableSelect
                  value={field.value}
                  onChange={field.onChange}
                  options={wrappers.map((w) => ({ value: w.id, label: w.name }))}
                  placeholder="Select wrapper..."
                  searchPlaceholder="Search wrappers..."
                  className="mt-1"
                />
              )}
            />
            {errors.wrapperId && <p className="text-xs text-red-400 mt-1">{errors.wrapperId.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Packets per Box</label>
            <input {...register("packetsPerBox")} type="number"
              className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            {errors.packetsPerBox && <p className="text-xs text-red-400 mt-1">{errors.packetsPerBox.message}</p>}
          </div>

          <div>
            <label className="text-sm text-[var(--text-muted)]">Box</label>
            <Controller
              control={control}
              name="boxId"
              render={({ field }) => (
                <SearchableSelect
                  value={field.value}
                  onChange={field.onChange}
                  options={boxes.map((b) => ({ value: b.id, label: b.name }))}
                  placeholder="Select box..."
                  searchPlaceholder="Search boxes..."
                  className="mt-1"
                />
              )}
            />
            {errors.boxId && <p className="text-xs text-red-400 mt-1">{errors.boxId.message}</p>}
          </div>

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
            <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 text-xs text-[var(--text-muted)]">
              {name?.trim() ? <span className="text-[var(--foreground)] font-medium">"{name.trim()}"</span> : "This configuration"} yields{" "}
              <span className="text-[var(--foreground)] font-medium">{totalPacketsPerCarton} packets</span> per carton.
            </div>
          )}

          {wrapperId && boxId && totalPacketsPerCarton > 0 && (
            <div className="rounded-lg border border-[var(--surface-border)] bg-[var(--background)] p-3 text-xs text-[var(--text-muted)] space-y-1.5">
              <div className="flex items-center text-[var(--foreground)] font-medium">
                Cost Build-Up
                <InfoTip text="Derived from each Wrapper/Box/Carton Material's quantity-per-unit x its raw material's current weighted-average cost. Wrapper cost = per packet. Box cost + (Packets/Box x Wrapper cost) = per box. (Boxes/Carton x Box cost) + Carton Material cost = per carton. Excludes bulk product cost, which varies per batch." />
              </div>
              <div className="grid grid-cols-2 gap-x-3 gap-y-1">
                <span>Cost / Wrapper (Packet)</span><span className="text-right text-[var(--foreground)]">Rs. {costPerPacket.toFixed(2)}</span>
                <span>Cost / Box</span><span className="text-right text-[var(--foreground)]">Rs. {costPerBox.toFixed(2)}</span>
                <span>Cost / Box (assembled)</span><span className="text-right text-[var(--foreground)]">Rs. {costPerBoxAssembled.toFixed(2)}</span>
                <span>Cost / Carton Material</span><span className="text-right text-[var(--foreground)]">Rs. {costPerCartonMaterial.toFixed(2)}</span>
                <span className="font-medium">Cost / Carton</span><span className="text-right text-[var(--foreground)] font-medium">Rs. {costPerCarton.toFixed(2)}</span>
              </div>
            </div>
          )}
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

export default function CartonConfigPage() {
  const configs = useStore((s) => s.cartonConfigurations);
  const loadCartonConfigurations = useStore((s) => s.loadCartonConfigurations);
  const deleteCartonConfiguration = useStore((s) => s.deleteCartonConfiguration);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const handleDelete = async (id: string, name: string, usedInPackingRun: boolean) => {
    if (usedInPackingRun) return;
    if (!window.confirm(`Delete carton configuration "${name}"? This cannot be undone.`)) return;
    setDeletingId(id);
    try {
      await deleteCartonConfiguration(id);
      toast.success("Carton configuration deleted");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to delete carton configuration");
    } finally {
      setDeletingId(null);
    }
  };
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const [dialogOpen, setDialogOpen] = useState(false);

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

  const columns = useMemo<ColumnDef<Row, unknown>[]>(() => [
    { accessorKey: "name", header: "Name", cell: ({ getValue }) => <span className="text-[var(--foreground)] font-medium">{getValue() as string}</span> },
    { accessorKey: "wrapperName", header: "Wrapper" },
    { accessorKey: "packetsPerBox", header: "Packets / Box" },
    { accessorKey: "boxName", header: "Box" },
    { accessorKey: "boxesPerCarton", header: "Boxes / Carton" },
    { accessorKey: "cartonMaterialName", header: "Carton Material" },
    { accessorKey: "packetsPerCarton", header: "Packets / Carton" },
    {
      id: "status", header: "Status", enableSorting: false,
      cell: ({ row }) => <StatusBadge used={row.original.usedInPackingRun} />,
    },
    {
      id: "actions", header: "Actions", enableSorting: false,
      cell: ({ row }) => (
        <button
          type="button"
          onClick={() => handleDelete(row.original.id, row.original.name, row.original.usedInPackingRun)}
          disabled={row.original.usedInPackingRun || deletingId === row.original.id}
          title={row.original.usedInPackingRun ? "Already used in a packing run - cannot be deleted" : undefined}
          className="rounded-lg border border-red-900 px-2.5 py-1 text-xs font-medium text-red-400 hover:bg-red-950 disabled:opacity-50"
        >
          {deletingId === row.original.id ? "Deleting..." : "Delete"}
        </button>
      ),
    },
  ], [deletingId]);

  const canCreate = wrappers.length > 0 && boxes.length > 0 && rawMaterials.length > 0;

  return (
    <div className="space-y-6">
      <div className="text-sm text-[var(--text-muted)]">
        <a href="/packaging" className="hover:underline text-[var(--text-secondary)]">Packaging Materials</a>{" "}
        / <span className="text-[var(--foreground)]">Carton Configurations</span>
      </div>

      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-[var(--foreground)]">Carton Configurations</h1>
        <button
          onClick={() => setDialogOpen(true)}
          disabled={!canCreate}
          title={canCreate ? undefined : "Add at least one Wrapper, one Box, and one Raw Material first"}
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50"
        >
          + New Configuration
        </button>
      </div>

      {!canCreate && (
        <div className="rounded-xl border border-amber-900 bg-amber-950 p-4 text-sm text-amber-400">
          You need at least one Wrapper, one Box, and one Raw Material before creating a carton configuration.
        </div>
      )}

      <SortableTable data={rows} columns={columns} globalFilterPlaceholder="Search configurations..." onRefresh={loadCartonConfigurations} />
      <AddConfigDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </div>
  );
}