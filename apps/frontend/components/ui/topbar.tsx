"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Notification, User as UserIcon, ChevronDown as ChevronDownIcon } from "@carbon/icons-react";
import { useStore } from "@/lib/store";
import { AnimatedThemeToggler } from "@/components/ui/animated-theme-toggler";

function NotificationBell() {
  const [open, setOpen] = useState(false);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const packagingMaterials = useStore((s) => s.packagingMaterials);

  const alerts = [
    ...rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold })),
    ...packagingMaterials
      .filter((p) => p.stockQty < p.lowStockThreshold)
      .map((p) => ({ id: p.id, name: p.name, href: `/packaging`, qty: p.stockQty, threshold: p.lowStockThreshold })),
  ];

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="relative flex items-center justify-center size-9 rounded-lg hover:bg-[var(--surface-hover)] text-[var(--text-secondary)]"
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
          <div className="absolute right-0 z-50 mt-2 w-72 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] shadow-lg overflow-hidden">
            <div className="px-4 py-3 border-b border-[var(--surface-border)] text-sm font-medium text-[var(--foreground)]">
              Low Stock Alerts
            </div>
            <div className="max-h-72 overflow-y-auto">
              {alerts.length === 0 && (
                <div className="px-4 py-6 text-center text-sm text-[var(--foreground)]0">All stock levels are healthy.</div>
              )}
              {alerts.map((a) => (
                <Link
                  key={a.id}
                  href={a.href}
                  onClick={() => setOpen(false)}
                  className="flex items-center justify-between px-4 py-2.5 hover:bg-[var(--surface-hover)] border-b border-[var(--surface-border)] last:border-0"
                >
                  <span className="text-sm text-[var(--foreground)]">{a.name}</span>
                  <span className="text-xs text-red-400">{a.qty} / {a.threshold}</span>
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

  const handleLogout = () => {
    setOpen(false);
    document.cookie = "ghanifoods-auth=; path=/; max-age=0";
    router.push("/login");
  };

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-1.5 rounded-lg px-1.5 py-1 hover:bg-[var(--surface-hover)]"
        aria-label="User menu"
      >
        <div className="flex items-center justify-center size-8 rounded-full bg-[var(--surface-hover)] border border-[var(--surface-border-strong)]">
          <UserIcon size={16} className="text-[var(--foreground)]" />
        </div>
        <ChevronDownIcon size={14} className="text-[var(--text-muted)]" />
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 w-48 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] shadow-lg overflow-hidden">
            <Link href="/settings" onClick={() => setOpen(false)}
              className="block px-4 py-2.5 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
              Settings
            </Link>
            <button onClick={handleLogout}
              className="w-full text-left px-4 py-2.5 text-sm text-red-400 hover:bg-[var(--surface-hover)]">
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
    <div className="flex items-center justify-end gap-3 border-b border-[var(--surface-border)] bg-[var(--background)] px-6 py-3 sticky top-0 z-30">
      <Link href="/invoices/new"
        className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
        + New Invoice
      </Link>
      <AnimatedThemeToggler />
      <NotificationBell />
      <UserMenu />
    </div>
  );
}

export default Topbar;