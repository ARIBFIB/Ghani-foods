#
# fix-settings-export-tab.ps1
# ----------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Fixes: Settings page tabs (sidebar > Settings > Business Profile / Export & Data)
#        were not actually switching content - everything (Business Profile form,
#        Export panel, Danger Zone) rendered on top of each other on one page.
#
# This script:
#   1. Updates settings/page.tsx to use a ?tab= query param to show ONLY the
#      selected tab's content (profile OR export).
#   2. Updates sidebar-component.tsx so "Business Profile" links to
#      /settings?tab=profile and "Export & Data" links to /settings?tab=export.
#
# NOTE: "Security" and "Notifications" sidebar items are left untouched for now
#       (no href yet) - as requested, those will be handled separately.
#
# Safe to re-run. Backups made before any edit: <file>.bak-<timestamp>
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
        Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
    } else {
        Write-Host "  ERROR: File not found: $path" -ForegroundColor Red
        exit 1
    }
}

# -----------------------------------------------------------------
# 1. settings/page.tsx - add tab switching via ?tab= query param
# -----------------------------------------------------------------
$settingsPagePath = Join-Path $root "apps\frontend\app\(dashboard)\settings\page.tsx"

if (-not (Test-Path -LiteralPath $settingsPagePath)) {
    Write-Host "ERROR: Could not find $settingsPagePath" -ForegroundColor Red
    exit 1
}

Backup-File $settingsPagePath

$newSettingsPage = @'
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useRouter, useSearchParams } from "next/navigation";
import { toast } from "@/components/ui/toast";
import { useStore } from "@/lib/store";
import { ExportDataPanel } from "@/components/ui/export-data-panel";
import { DangerZonePanel } from "@/components/ui/danger-zone-panel";

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
  const router = useRouter();
  const searchParams = useSearchParams();

  // ?tab=profile (default) | export
  const activeTab = searchParams.get("tab") === "export" ? "export" : "profile";

  const goToTab = (tab: "profile" | "export") => {
    router.push(`/settings?tab=${tab}`);
  };

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting, isDirty },
  } = useForm<SettingsFormValues>({
    resolver: zodResolver(settingsSchema),
    defaultValues: settings,
  });

  const onSubmit = async (values: SettingsFormValues) => {
    try {
      await updateSettings(values);
      toast.success("Settings saved");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to save settings");
    }
  };

  return (
    <div className="max-w-2xl space-y-6">
      <h1 className="text-xl font-semibold text-[var(--foreground)]">Settings</h1>

      {/* Local tab strip - kept in addition to the left sidebar, so the page
          works correctly even if the sidebar link/query param changes later. */}
      <div className="flex gap-2 border-b border-[var(--surface-border)]">
        <button
          type="button"
          onClick={() => goToTab("profile")}
          className={`px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
            activeTab === "profile"
              ? "border-[var(--foreground)] text-[var(--foreground)]"
              : "border-transparent text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
          }`}
        >
          Business Profile
        </button>
        <button
          type="button"
          onClick={() => goToTab("export")}
          className={`px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
            activeTab === "export"
              ? "border-[var(--foreground)] text-[var(--foreground)]"
              : "border-transparent text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
          }`}
        >
          Export & Data
        </button>
      </div>

      {activeTab === "profile" && (
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
            <h2 className="text-sm font-semibold text-[var(--foreground)]">Business Profile</h2>

            <div>
              <label className="text-sm text-[var(--text-muted)]">Business Name</label>
              <input {...register("businessName")}
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.businessName && <p className="text-xs text-red-400 mt-1">{errors.businessName.message}</p>}
            </div>

            <div>
              <label className="text-sm text-[var(--text-muted)]">Address</label>
              <input {...register("address")}
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.address && <p className="text-xs text-red-400 mt-1">{errors.address.message}</p>}
            </div>

            <div>
              <label className="text-sm text-[var(--text-muted)]">Invoice Footer Text</label>
              <input {...register("invoiceFooterText")}
                className="mt-1 w-full rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
            </div>
          </div>

          <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
            <h2 className="text-sm font-semibold text-[var(--foreground)]">Defaults</h2>

            <div>
              <label className="text-sm text-[var(--text-muted)]">Default Profit Margin %</label>
              <input {...register("defaultProfitMarginPercent")} type="number" step="any"
                className="mt-1 w-48 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.defaultProfitMarginPercent && <p className="text-xs text-red-400 mt-1">{errors.defaultProfitMarginPercent.message}</p>}
            </div>

            <div>
              <label className="text-sm text-[var(--text-muted)]">Low-Stock Threshold Default</label>
              <input {...register("lowStockThresholdDefault")} type="number"
                className="mt-1 w-48 rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]" />
              {errors.lowStockThresholdDefault && <p className="text-xs text-red-400 mt-1">{errors.lowStockThresholdDefault.message}</p>}
            </div>
          </div>

          <button
            type="submit"
            disabled={isSubmitting || !isDirty}
            className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-50 dark:text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
          >
            {isSubmitting ? "Saving..." : "Save Settings"}
          </button>
        </form>
      )}

      {activeTab === "export" && (
        <div className="space-y-6">
          <ExportDataPanel />
          <DangerZonePanel />
        </div>
      )}
    </div>
  );
}
'@

Set-Content -LiteralPath $settingsPagePath -Value $newSettingsPage -NoNewline
Write-Host "settings/page.tsx -> updated with tab switching (Business Profile / Export & Data)." -ForegroundColor Green

# -----------------------------------------------------------------
# 2. sidebar-component.tsx - point Business Profile / Export & Data
#    to the correct ?tab= query params
# -----------------------------------------------------------------
$sidebarPath = Join-Path $root "apps\frontend\components\ui\sidebar-component.tsx"

if (-not (Test-Path -LiteralPath $sidebarPath)) {
    Write-Host "ERROR: Could not find $sidebarPath" -ForegroundColor Red
    exit 1
}

$sidebarContent = Get-Content -Raw -LiteralPath $sidebarPath

$oldBlock = '            { icon: <SettingsIcon size={16} className="text-[var(--foreground)]" />, label: "Business Profile", href: "/settings" },
            { icon: <Security size={16} className="text-[var(--foreground)]" />, label: "Security" },
            { icon: <Notification size={16} className="text-[var(--foreground)]" />, label: "Notifications" },
            { icon: <Download size={16} className="text-[var(--foreground)]" />, label: "Export & Data", href: "/settings" },'

$newBlock = '            { icon: <SettingsIcon size={16} className="text-[var(--foreground)]" />, label: "Business Profile", href: "/settings?tab=profile" },
            { icon: <Security size={16} className="text-[var(--foreground)]" />, label: "Security" },
            { icon: <Notification size={16} className="text-[var(--foreground)]" />, label: "Notifications" },
            { icon: <Download size={16} className="text-[var(--foreground)]" />, label: "Export & Data", href: "/settings?tab=export" },'

if ($sidebarContent -match [regex]::Escape('href: "/settings?tab=export"')) {
    Write-Host "sidebar-component.tsx already has the fixed Export & Data link - skipping." -ForegroundColor Yellow
}
elseif ($sidebarContent -match [regex]::Escape($oldBlock)) {
    Backup-File $sidebarPath
    $updatedSidebar = $sidebarContent.Replace($oldBlock, $newBlock)
    Set-Content -LiteralPath $sidebarPath -Value $updatedSidebar -NoNewline
    Write-Host "sidebar-component.tsx -> Business Profile / Export & Data links updated." -ForegroundColor Green
}
else {
    Write-Host "WARNING: Could not find the expected settings menu block in sidebar-component.tsx." -ForegroundColor Yellow
    Write-Host "The file may have changed since this script was written - please update the link manually:" -ForegroundColor Yellow
    Write-Host '  Business Profile -> href: "/settings?tab=profile"' -ForegroundColor Yellow
    Write-Host '  Export & Data    -> href: "/settings?tab=export"' -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Sidebar > Settings > Business Profile ab /settings?tab=profile khole ga," -ForegroundColor Green
Write-Host "aur Export & Data /settings?tab=export khole ga - sirf wahi tab ka content dikhega." -ForegroundColor Green
Write-Host "Security aur Notifications abhi tak wese hi hain (unwired) - agli baar fix karenge." -ForegroundColor DarkGray