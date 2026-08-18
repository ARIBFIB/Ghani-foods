"use client";

import { useState } from "react";
import { NavLink } from "@/components/ui/nav-link";
import { useRouter } from "next/navigation";
import { useNavigationLoading } from "@/lib/navigation-loading-context";
import {
  Notification,
  User as UserIcon,
  ChevronDown as ChevronDownIcon,
  Menu as MenuIcon,
} from "@carbon/icons-react";
import { useStore } from "@/lib/store";
import { AnimatedThemeToggler } from "@/components/ui/animated-theme-toggler";
import { useSidebar } from "@/lib/sidebar-context";

function NotificationBell() {
  const [open, setOpen] = useState(false);
  const rawMaterials = useStore((s) => s.rawMaterials);
  const wrappers = useStore((s) => s.wrappers);
  const boxes = useStore((s) => s.boxes);

  const alerts = [
    ...rawMaterials
      .filter((m) => m.quantityInStock < m.lowStockThreshold)
      .map((m) => ({ id: m.id, name: m.name, href: `/raw-materials/${m.id}`, qty: m.quantityInStock, threshold: m.lowStockThreshold })),
    ...wrappers
      .filter((w) => w.stockQty < w.lowStockThreshold)
      .map((w) => ({ id: w.id, name: w.name, href: `/packaging`, qty: w.stockQty, threshold: w.lowStockThreshold })),
    ...boxes
      .filter((b) => b.stockQty < b.lowStockThreshold)
      .map((b) => ({ id: b.id, name: b.name, href: `/packaging`, qty: b.stockQty, threshold: b.lowStockThreshold })),
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
          <div className="absolute right-0 z-50 mt-2 w-72 max-w-[85vw] rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] shadow-lg overflow-hidden">
            <div className="px-4 py-3 border-b border-[var(--surface-border)] text-sm font-medium text-[var(--foreground)]">
              Low Stock Alerts
            </div>
            <div className="max-h-72 overflow-y-auto">
              {alerts.length === 0 && (
                <div className="px-4 py-6 text-center text-sm text-[var(--text-faint)]">All stock levels are healthy.</div>
              )}
              {alerts.map((a) => (
                <NavLink
                  key={a.id}
                  href={a.href}
                  onClick={() => setOpen(false)}
                  className="flex items-center justify-between px-4 py-2.5 hover:bg-[var(--surface-hover)] border-b border-[var(--surface-border)] last:border-0"
                >
                  <span className="text-sm text-[var(--foreground)]">{a.name}</span>
                  <span className="text-xs text-red-500">{a.qty} / {a.threshold}</span>
                </NavLink>
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
  const { navigate } = useNavigationLoading();

  const handleLogout = () => {
    setOpen(false);
    document.cookie = "ghanifoods-auth=; path=/; max-age=0";
    navigate("/login");
  };

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-1.5 rounded-lg px-1.5 py-1 hover:bg-[var(--surface-hover)]"
        aria-label="User menu"
      >
        <div className="flex items-center justify-center size-8 rounded-full bg-[var(--surface-hover)] border border-[var(--surface-border)]">
          <UserIcon size={16} className="text-[var(--text-secondary)]" />
        </div>
        <ChevronDownIcon size={14} className="text-[var(--text-muted)] hidden sm:block" />
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 w-48 rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] shadow-lg overflow-hidden">
            <NavLink href="/settings" onClick={() => setOpen(false)}
              className="block px-4 py-2.5 text-sm text-[var(--foreground)] hover:bg-[var(--surface-hover)]">
              Settings
            </NavLink>
            <button onClick={handleLogout}
              className="w-full text-left px-4 py-2.5 text-sm text-red-500 hover:bg-[var(--surface-hover)]">
              Log out
            </button>
          </div>
        </>
      )}
    </div>
  );
}

export function Topbar() {
  const { toggle } = useSidebar();

  return (
    <div className="flex items-center gap-2 sm:gap-3 border-b border-[var(--surface-border)] bg-[var(--background)] px-3 sm:px-6 py-3 sticky top-0 z-30">
      <button
        type="button"
        onClick={toggle}
        aria-label="Open menu"
        className="lg:hidden flex items-center justify-center size-9 rounded-lg hover:bg-[var(--surface-hover)] text-[var(--foreground)] shrink-0 border border-[var(--surface-border)]"
      >
        <MenuIcon size={20} />
      </button>

      <div className="flex items-center gap-2 sm:gap-3 ml-auto">
        <NavLink href="/invoices/new"
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-3 sm:px-4 py-2 text-xs sm:text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity whitespace-nowrap">
          <span className="hidden sm:inline">+ New Invoice</span>
          <span className="sm:hidden">+ Invoice</span>
        </NavLink>
        <AnimatedThemeToggler />
        <NotificationBell />
        <UserMenu />
      </div>
    </div>
  );
}

export default Topbar;