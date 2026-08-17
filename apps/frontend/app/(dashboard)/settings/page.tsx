"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";

const settingsSchema = z.object({
  businessName: z.string().trim().min(2, "Business name required"),
  address: z.string().trim().min(5, "Address required"),
  invoiceFooterText: z.string().trim(),
  defaultProfitMarginPercent: z.coerce.number().min(0, "Cannot be negative"),
  lowStockThresholdDefault: z.coerce.number().min(0, "Cannot be negative"),
});
type SettingsFormValues = z.infer<typeof settingsSchema>;

export default function SettingsPage() {
  const settings = useStore((s) => s.settings);
  const updateSettings = useStore((s) => s.updateSettings);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting, isDirty },
  } = useForm<SettingsFormValues>({
    resolver: zodResolver(settingsSchema),
    defaultValues: settings,
  });

  const onSubmit = async (values: SettingsFormValues) => {
    updateSettings(values);
    toast.success("Settings saved");
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-2xl">
      <h1 className="text-xl font-semibold text-neutral-50">Settings</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-sm font-semibold text-neutral-200">Business Profile</h2>

        <div>
          <label className="text-sm text-neutral-400">Business Name</label>
          <input {...register("businessName")}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.businessName && <p className="text-xs text-red-400 mt-1">{errors.businessName.message}</p>}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Address</label>
          <input {...register("address")}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.address && <p className="text-xs text-red-400 mt-1">{errors.address.message}</p>}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Invoice Footer Text</label>
          <input {...register("invoiceFooterText")}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-sm font-semibold text-neutral-200">Defaults</h2>

        <div>
          <label className="text-sm text-neutral-400">Default Profit Margin %</label>
          <input {...register("defaultProfitMarginPercent")} type="number" step="any"
            className="mt-1 w-48 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.defaultProfitMarginPercent && <p className="text-xs text-red-400 mt-1">{errors.defaultProfitMarginPercent.message}</p>}
        </div>

        <div>
          <label className="text-sm text-neutral-400">Low-Stock Threshold Default</label>
          <input {...register("lowStockThresholdDefault")} type="number"
            className="mt-1 w-48 rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.lowStockThresholdDefault && <p className="text-xs text-red-400 mt-1">{errors.lowStockThresholdDefault.message}</p>}
        </div>
      </div>

      <button
        type="submit"
        disabled={isSubmitting || !isDirty}
        className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
      >
        {isSubmitting ? "Saving..." : "Save Settings"}
      </button>
    </form>
  );
}