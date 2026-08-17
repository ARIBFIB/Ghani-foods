# add-topbar-and-dashboard.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\add-topbar-and-dashboard.ps1
#
# Adds:
#   - components/ui/topbar.tsx (New Invoice button, notification bell w/ low-stock
#     popover, user avatar dropdown)
#   - Wires Topbar into the dashboard layout
#   - Completes the Dashboard page: low-stock alerts, recent invoices table,
#     quick action buttons + Add Raw Material dialog

$ErrorActionPreference = "Stop"
$Root = Get-Location
$Frontend = Join-Path $Root "apps\frontend"

function Write-CodeFile {
    param([string]$RelativePath, [string]$Content)
    $fullPath = Join-Path $Frontend $RelativePath
    $dir = Split-Path $fullPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "  wrote $RelativePath" -ForegroundColor Green
}

Write-Host "=== Adding Topbar + completing Dashboard ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# components/ui/topbar.tsx
# ---------------------------------------------------------------------------
Write-CodeFile "components\ui\topbar.tsx" @'
"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Notification, User as UserIcon, ChevronDown as ChevronDownIcon } from "@carbon/icons-react";
import { rawMaterials } from "@/lib/mock-data/raw-materials";
import { packagingMaterials } from "@/lib/mock-data/packaging";

type LowStockAlert = {
  id: string;
  name: string;
  href: string;
  qty: number;
  threshold: number;
};

function getLowStockAlerts(): LowStockAlert[] {
  const rawAlerts: LowStockAlert[] = rawMaterials
    .filter((m) => m.quantityInStock < m.lowStockThreshold)
    .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold }));

  const packagingAlerts: LowStockAlert[] = packagingMaterials
    .filter((p) => p.stockQty < p.lowStockThreshold)
    .map((p) => ({ id: p.id, name: p.name, href: `/packaging`, qty: p.stockQty, threshold: p.lowStockThreshold }));

  return [...rawAlerts, ...packagingAlerts];
}

function NotificationBell() {
  const [open, setOpen] = useState(false);
  const alerts = getLowStockAlerts();

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="relative flex items-center justify-center size-9 rounded-lg hover:bg-neutral-800 text-neutral-300"
        aria-label="Notifications"
      >
        <Notification size={18} />
        {alerts.length > 0 && (
          <span className="absolute -top-0.5 -right-0.5 flex items-center justify-center size-4 rounded-full bg-red-500 text-[10px] font-semibold text-white">
            {alerts.length}
          </span>
        )}
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 w-72 rounded-xl border border-neutral-800 bg-neutral-900 shadow-lg overflow-hidden">
            <div className="px-4 py-3 border-b border-neutral-800 text-sm font-medium text-neutral-200">
              Low Stock Alerts
            </div>
            <div className="max-h-72 overflow-y-auto">
              {alerts.length === 0 && (
                <div className="px-4 py-6 text-center text-sm text-neutral-500">All stock levels are healthy.</div>
              )}
              {alerts.map((a) => (
                <Link
                  key={a.id}
                  href={a.href}
                  onClick={() => setOpen(false)}
                  className="flex items-center justify-between px-4 py-2.5 hover:bg-neutral-800 border-b border-neutral-900 last:border-0"
                >
                  <span className="text-sm text-neutral-50">{a.name}</span>
                  <span className="text-xs text-red-400">
                    {a.qty} / {a.threshold}
                  </span>
                </Link>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function UserMenu() {
  const [open, setOpen] = useState(false);
  const router = useRouter();

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-1.5 rounded-lg px-1.5 py-1 hover:bg-neutral-800"
        aria-label="User menu"
      >
        <div className="flex items-center justify-center size-8 rounded-full bg-neutral-800 border border-neutral-700">
          <UserIcon size={16} className="text-neutral-200" />
        </div>
        <ChevronDownIcon size={14} className="text-neutral-400" />
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 w-48 rounded-xl border border-neutral-800 bg-neutral-900 shadow-lg overflow-hidden">
            <Link
              href="/settings"
              onClick={() => setOpen(false)}
              className="block px-4 py-2.5 text-sm text-neutral-200 hover:bg-neutral-800"
            >
              Settings
            </Link>
            <button
              onClick={() => {
                setOpen(false);
                router.push("/login");
              }}
              className="w-full text-left px-4 py-2.5 text-sm text-red-400 hover:bg-neutral-800"
            >
              Log out
            </button>
          </div>
        </>
      )}
    </div>
  );
}

export function Topbar() {
  return (
    <div className="flex items-center justify-end gap-3 border-b border-neutral-800 bg-neutral-950 px-6 py-3 sticky top-0 z-30">
      <Link
        href="/invoices/new"
        className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
      >
        + New Invoice
      </Link>
      <NotificationBell />
      <UserMenu />
    </div>
  );
}

export default Topbar;
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/layout.tsx — wire in the Topbar
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\layout.tsx" @'
import type { ReactNode } from "react";
import { AppSidebar } from "@/components/ui/sidebar-component";
import { Topbar } from "@/components/ui/topbar";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-neutral-950">
      <AppSidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <Topbar />
        <main className="flex-1 p-6 overflow-y-auto text-neutral-50">{children}</main>
      </div>
    </div>
  );
}
'@

# ---------------------------------------------------------------------------
# app/(dashboard)/page.tsx — complete Dashboard
# ---------------------------------------------------------------------------
Write-CodeFile "app\(dashboard)\page.tsx" @'
"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { dashboardKpis as kpis } from "@/lib/mock-data/kpis";
import { rawMaterials as initialRawMaterials, type RawMaterial } from "@/lib/mock-data/raw-materials";
import { packagingMaterials } from "@/lib/mock-data/packaging";
import { invoices } from "@/lib/mock-data/invoices";

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-4">
      <div className="text-neutral-400 text-sm">{label}</div>
      <div className="text-2xl font-semibold text-neutral-50 mt-1">{value}</div>
    </div>
  );
}

function StatusBadge({ status }: { status: "unpaid" | "partial" | "paid" }) {
  const styles: Record<string, string> = {
    paid: "bg-green-950 text-green-400 border border-green-900",
    partial: "bg-amber-950 text-amber-400 border border-amber-900",
    unpaid: "bg-red-950 text-red-400 border border-red-900",
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${styles[status]}`}>
      {status[0].toUpperCase() + status.slice(1)}
    </span>
  );
}

function AddRawMaterialDialog({
  open,
  onClose,
  onAdd,
}: {
  open: boolean;
  onClose: () => void;
  onAdd: (item: RawMaterial) => void;
}) {
  const [name, setName] = useState("");
  const [unit, setUnit] = useState("kg");
  const [threshold, setThreshold] = useState("50");

  if (!open) return null;

  const handleSave = () => {
    if (!name.trim()) return;
    onAdd({
      id: `rm-${Date.now()}`,
      name: name.trim(),
      unit,
      quantityInStock: 0,
      avgUnitCost: 0,
      lowStockThreshold: Number(threshold) || 0,
    });
    setName("");
    setUnit("kg");
    setThreshold("50");
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Add Raw Material</h2>
        <div className="space-y-3">
          <div>
            <label className="text-sm text-neutral-400">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Atta (Flour)"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Unit of Purchase</label>
            <input
              value={unit}
              onChange={(e) => setUnit(e.target.value)}
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
          <div>
            <label className="text-sm text-neutral-400">Low Stock Threshold</label>
            <input
              value={threshold}
              onChange={(e) => setThreshold(e.target.value)}
              type="number"
              className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
            />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button onClick={onClose} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const [rawMaterials, setRawMaterials] = useState<RawMaterial[]>(initialRawMaterials);
  const [dialogOpen, setDialogOpen] = useState(false);

  const lowStockItems = useMemo(() => {
    const rawAlerts = rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold }));
    const packagingAlerts = packagingMaterials
      .filter((p) => p.stockQty < p.lowStockThreshold)
      .map((p) => ({ id: p.id, name: p.name, href: `/packaging`, qty: p.stockQty, threshold: p.lowStockThreshold }));
    return [...rawAlerts, ...packagingAlerts];
  }, [rawMaterials]);

  const recentInvoices = invoices.slice(0, 5);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Dashboard</h1>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Total Raw Material Value" value={`Rs. ${kpis.totalRawMaterialValue.toLocaleString()}`} />
        <KpiCard label="Batches This Month" value={kpis.batchesThisMonth} />
        <KpiCard label="Finished Cartons Ready" value={kpis.finishedCartonsReady} />
        <KpiCard label="Total Receivables" value={`Rs. ${kpis.totalReceivables.toLocaleString()}`} />
      </div>

      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => setDialogOpen(true)}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800"
        >
          + Add Raw Material
        </button>
        <button
          onClick={() => router.push("/batches/new")}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800"
        >
          + New Batch
        </button>
        <button
          onClick={() => router.push("/invoices/new")}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          + New Invoice
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="rounded-xl border border-neutral-800 bg-neutral-900 overflow-hidden">
          <div className="px-4 py-3 border-b border-neutral-800">
            <h2 className="text-sm font-semibold text-neutral-200">Low Stock Alerts</h2>
          </div>
          <div className="divide-y divide-neutral-900">
            {lowStockItems.length === 0 && (
              <div className="px-4 py-6 text-center text-sm text-neutral-500">All stock levels are healthy.</div>
            )}
            {lowStockItems.map((item) => (
              <Link
                key={item.id}
                href={item.href}
                className="flex items-center justify-between px-4 py-3 hover:bg-neutral-800/60"
              >
                <span className="text-sm text-neutral-50">{item.name}</span>
                <span className="text-xs text-red-400">
                  {item.qty} / {item.threshold}
                </span>
              </Link>
            ))}
          </div>
        </div>

        <div className="rounded-xl border border-neutral-800 bg-neutral-900 overflow-hidden">
          <div className="px-4 py-3 border-b border-neutral-800 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-neutral-200">Recent Invoices</h2>
            <Link href="/invoices" className="text-xs text-neutral-400 hover:text-neutral-200 hover:underline">
              View all
            </Link>
          </div>
          <table className="w-full text-sm">
            <tbody>
              {recentInvoices.map((inv) => (
                <tr key={inv.id} className="border-b border-neutral-900 last:border-0">
                  <td className="px-4 py-3">
                    <Link href={`/invoices/${inv.id}`} className="text-neutral-50 hover:underline">
                      {inv.id}
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-neutral-300">{inv.customerName}</td>
                  <td className="px-4 py-3 text-neutral-300">Rs. {inv.totalAmount.toLocaleString()}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={inv.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <AddRawMaterialDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        onAdd={(item) => setRawMaterials((prev) => [...prev, item])}
      />
    </div>
  );
}
'@

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "Topbar added (New Invoice button, low-stock notification bell, user menu)." -ForegroundColor Green
Write-Host "Dashboard now shows: KPIs, quick actions, low-stock alerts, recent invoices." -ForegroundColor Green