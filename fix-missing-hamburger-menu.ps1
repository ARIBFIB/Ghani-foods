# fix-missing-hamburger-menu.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-missing-hamburger-menu.ps1
#
# ROOT CAUSE:
#   Multiple chained regex-patch scripts were applied to topbar.tsx and
#   sidebar-component.tsx over several rounds. Somewhere in that chain,
#   the hamburger button JSX either failed to insert cleanly or got
#   silently mangled - so on mobile there is NO way to open the sidebar
#   drawer at all (confirmed by screenshot: topbar shows New Invoice,
#   toggle, bell, avatar - no hamburger icon).
#
# FIX APPROACH:
#   Instead of another patch-on-patch, this script does a full clean
#   REWRITE of both files from a known-good state, so there's no
#   ambiguity about what's actually in them.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Rewriting Topbar + Sidebar cleanly (fixing missing hamburger) ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. Topbar - full clean rewrite with guaranteed hamburger button
# --------------------------------------------------------------------------

$topbarPath = Join-Path $FrontendRoot "components\ui\topbar.tsx"
$topbarContent = @'
"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
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
          <div className="absolute right-0 z-50 mt-2 w-72 max-w-[85vw] rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] shadow-lg overflow-hidden">
            <div className="px-4 py-3 border-b border-[var(--surface-border)] text-sm font-medium text-[var(--foreground)]">
              Low Stock Alerts
            </div>
            <div className="max-h-72 overflow-y-auto">
              {alerts.length === 0 && (
                <div className="px-4 py-6 text-center text-sm text-[var(--text-faint)]">All stock levels are healthy.</div>
              )}
              {alerts.map((a) => (
                <Link
                  key={a.id}
                  href={a.href}
                  onClick={() => setOpen(false)}
                  className="flex items-center justify-between px-4 py-2.5 hover:bg-[var(--surface-hover)] border-b border-[var(--surface-border)] last:border-0"
                >
                  <span className="text-sm text-[var(--foreground)]">{a.name}</span>
                  <span className="text-xs text-red-500">{a.qty} / {a.threshold}</span>
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
        <div className="flex items-center justify-center size-8 rounded-full bg-[var(--surface-hover)] border border-[var(--surface-border)]">
          <UserIcon size={16} className="text-[var(--text-secondary)]" />
        </div>
        <ChevronDownIcon size={14} className="text-[var(--text-muted)] hidden sm:block" />
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
        <Link href="/invoices/new"
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-3 sm:px-4 py-2 text-xs sm:text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity whitespace-nowrap">
          <span className="hidden sm:inline">+ New Invoice</span>
          <span className="sm:hidden">+ Invoice</span>
        </Link>
        <AnimatedThemeToggler />
        <NotificationBell />
        <UserMenu />
      </div>
    </div>
  );
}

export default Topbar;
'@
Write-Utf8NoBom $topbarPath $topbarContent

# --------------------------------------------------------------------------
# 2. Sidebar - full clean rewrite: mobile drawer (icon rail + detail panel
#    combined into ONE panel on mobile, since the two-column desktop rail
#    doesn't fit a phone screen) + unchanged desktop two-column layout.
# --------------------------------------------------------------------------

$sidebarPath = Join-Path $FrontendRoot "components\ui\sidebar-component.tsx"
$sidebarContent = @'
"use client";

import React, { useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  Search as SearchIcon,
  Dashboard,
  Task,
  Folder,
  UserMultiple,
  Analytics,
  DocumentAdd,
  Settings as SettingsIcon,
  User as UserIcon,
  ChevronDown as ChevronDownIcon,
  AddLarge,
  Archive,
  View,
  Report,
  StarFilled,
  ChartBar,
  FolderOpen,
  Security,
  Notification,
  Close as CloseIcon,
} from "@carbon/icons-react";
import { GhaniLogo } from "./ghani-logo";
import { useSidebar } from "@/lib/sidebar-context";

const softSpringEasing = "cubic-bezier(0.25, 1.1, 0.4, 1)";

type SectionId =
  | "dashboard"
  | "raw-materials"
  | "batches"
  | "finished-cartons"
  | "customers"
  | "invoices"
  | "payments"
  | "reports"
  | "settings";

const SECTION_DEFAULT_ROUTE: Record<SectionId, string> = {
  dashboard: "/",
  "raw-materials": "/raw-materials",
  batches: "/batches",
  "finished-cartons": "/finished-cartons",
  customers: "/customers",
  invoices: "/invoices",
  payments: "/payments",
  reports: "/reports",
  settings: "/settings",
};

const ROUTE_PREFIXES: Array<[string, SectionId]> = [
  ["/raw-materials", "raw-materials"],
  ["/packaging", "raw-materials"],
  ["/batches", "batches"],
  ["/finished-cartons", "finished-cartons"],
  ["/customers", "customers"],
  ["/invoices", "invoices"],
  ["/payments", "payments"],
  ["/reports", "reports"],
  ["/settings", "settings"],
];

function getSectionFromPathname(pathname: string): SectionId {
  for (const [prefix, section] of ROUTE_PREFIXES) {
    if (pathname === prefix || pathname.startsWith(prefix + "/")) return section;
  }
  return "dashboard";
}

function BrandBadge() {
  return (
    <div className="relative shrink-0 w-full">
      <div className="flex items-center p-1 w-full">
        <div className="h-10 w-8 flex items-center justify-center pl-2 text-[var(--foreground)]">
          <GhaniLogo className="size-5" />
        </div>
        <div className="px-2 py-1">
          <div className="font-semibold text-[16px] text-[var(--foreground)]">GhaniFoods</div>
        </div>
      </div>
    </div>
  );
}

function AvatarCircle() {
  return (
    <div className="relative rounded-full shrink-0 size-8 bg-[var(--surface-hover)]">
      <div className="flex items-center justify-center size-8">
        <UserIcon size={16} className="text-[var(--foreground)]" />
      </div>
      <div aria-hidden="true" className="absolute inset-0 rounded-full border border-[var(--surface-border)] pointer-events-none" />
    </div>
  );
}

function SearchContainer({ isCollapsed = false }: { isCollapsed?: boolean }) {
  const [searchValue, setSearchValue] = useState("");

  return (
    <div
      className={`relative shrink-0 transition-all duration-500 ${isCollapsed ? "w-full flex justify-center" : "w-full"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      <div
        className={`bg-[var(--background)] h-10 relative rounded-lg flex items-center transition-all duration-500 ${
          isCollapsed ? "w-10 min-w-10 justify-center" : "w-full"
        }`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div
          className={`flex items-center justify-center shrink-0 transition-all duration-500 ${isCollapsed ? "p-1" : "px-1"}`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          <div className="size-8 flex items-center justify-center">
            <SearchIcon size={16} className="text-[var(--foreground)]" />
          </div>
        </div>

        <div
          className={`flex-1 relative transition-opacity duration-500 overflow-hidden ${isCollapsed ? "opacity-0 w-0" : "opacity-100"}`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          <div className="flex flex-col justify-center size-full">
            <div className="flex flex-col gap-2 items-start justify-center pr-2 py-1 w-full">
              <input
                type="text"
                placeholder="Search..."
                value={searchValue}
                onChange={(e) => setSearchValue(e.target.value)}
                className="w-full bg-transparent border-none outline-none text-[14px] text-[var(--foreground)] placeholder:text-[var(--text-muted)] leading-[20px]"
                tabIndex={isCollapsed ? -1 : 0}
              />
            </div>
          </div>
        </div>

        <div aria-hidden="true" className="absolute inset-0 rounded-lg border border-[var(--surface-border)] pointer-events-none" />
      </div>
    </div>
  );
}

interface MenuItemT {
  icon?: React.ReactNode;
  label: string;
  href?: string;
}
interface MenuSectionT {
  title: string;
  items: MenuItemT[];
}
interface SidebarContent {
  title: string;
  sections: MenuSectionT[];
}

function getSidebarContent(activeSection: SectionId): SidebarContent {
  const contentMap: Record<SectionId, SidebarContent> = {
    dashboard: {
      title: "Dashboard",
      sections: [
        { title: "Overview", items: [{ icon: <View size={16} className="text-[var(--foreground)]" />, label: "Dashboard", href: "/" }] },
      ],
    },
    "raw-materials": {
      title: "Raw Materials",
      sections: [
        {
          title: "Inventory",
          items: [
            { icon: <Folder size={16} className="text-[var(--foreground)]" />, label: "All Raw Materials", href: "/raw-materials" },
            { icon: <FolderOpen size={16} className="text-[var(--foreground)]" />, label: "Packaging Materials", href: "/packaging" },
          ],
        },
      ],
    },
    batches: {
      title: "Production Batches",
      sections: [
        {
          title: "Batches",
          items: [
            { icon: <Task size={16} className="text-[var(--foreground)]" />, label: "All Batches", href: "/batches" },
            { icon: <AddLarge size={16} className="text-[var(--foreground)]" />, label: "New Batch", href: "/batches/new" },
          ],
        },
      ],
    },
    "finished-cartons": {
      title: "Finished Cartons",
      sections: [
        { title: "Stock", items: [{ icon: <Archive size={16} className="text-[var(--foreground)]" />, label: "Ready Stock", href: "/finished-cartons" }] },
      ],
    },
    customers: {
      title: "Customers",
      sections: [
        { title: "Customers", items: [{ icon: <UserMultiple size={16} className="text-[var(--foreground)]" />, label: "All Customers", href: "/customers" }] },
      ],
    },
    invoices: {
      title: "Invoices",
      sections: [
        {
          title: "Invoices",
          items: [
            { icon: <DocumentAdd size={16} className="text-[var(--foreground)]" />, label: "All Invoices", href: "/invoices" },
            { icon: <AddLarge size={16} className="text-[var(--foreground)]" />, label: "New Invoice", href: "/invoices/new" },
          ],
        },
      ],
    },
    payments: {
      title: "Payments",
      sections: [
        { title: "Payments", items: [{ icon: <ChartBar size={16} className="text-[var(--foreground)]" />, label: "All Payments", href: "/payments" }] },
      ],
    },
    reports: {
      title: "Reports",
      sections: [
        {
          title: "Analytics",
          items: [
            { icon: <Report size={16} className="text-[var(--foreground)]" />, label: "Inventory Movement", href: "/reports" },
            { icon: <Analytics size={16} className="text-[var(--foreground)]" />, label: "Production Yield", href: "/reports" },
            { icon: <StarFilled size={16} className="text-[var(--foreground)]" />, label: "P&L", href: "/reports" },
          ],
        },
      ],
    },
    settings: {
      title: "Settings",
      sections: [
        {
          title: "Workspace",
          items: [
            { icon: <SettingsIcon size={16} className="text-[var(--foreground)]" />, label: "Business Profile", href: "/settings" },
            { icon: <Security size={16} className="text-[var(--foreground)]" />, label: "Security" },
            { icon: <Notification size={16} className="text-[var(--foreground)]" />, label: "Notifications" },
          ],
        },
      ],
    },
  };

  return contentMap[activeSection];
}

function IconNavButton({
  children,
  isActive = false,
  onClick,
  label,
}: {
  children: React.ReactNode;
  isActive?: boolean;
  onClick: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      className={`flex items-center justify-center rounded-lg size-10 min-w-10 transition-colors duration-500
        ${isActive ? "bg-[var(--surface-hover)] text-[var(--foreground)]" : "hover:bg-[var(--surface-hover)] text-[var(--text-muted)] hover:text-[var(--text-secondary)]"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      onClick={onClick}
    >
      {children}
    </button>
  );
}

function IconNavigation({ activeSection }: { activeSection: SectionId }) {
  const router = useRouter();

  const navItems: Array<{ id: SectionId; icon: React.ReactNode; label: string }> = [
    { id: "dashboard", icon: <Dashboard size={16} />, label: "Dashboard" },
    { id: "raw-materials", icon: <Folder size={16} />, label: "Raw Materials" },
    { id: "batches", icon: <Task size={16} />, label: "Batches" },
    { id: "finished-cartons", icon: <Archive size={16} />, label: "Finished Cartons" },
    { id: "customers", icon: <UserMultiple size={16} />, label: "Customers" },
    { id: "invoices", icon: <DocumentAdd size={16} />, label: "Invoices" },
    { id: "payments", icon: <ChartBar size={16} />, label: "Payments" },
    { id: "reports", icon: <Analytics size={16} />, label: "Reports" },
  ];

  const goTo = (section: SectionId) => router.push(SECTION_DEFAULT_ROUTE[section]);

  return (
    <aside className="hidden lg:flex bg-[var(--background)] flex-col gap-2 items-center p-4 w-16 h-screen border-r border-[var(--surface-border)]">
      <div className="mb-2 size-10 flex items-center justify-center text-[var(--foreground)]">
        <GhaniLogo className="size-6" />
      </div>

      <div className="flex flex-col gap-2 w-full items-center">
        {navItems.map((item) => (
          <IconNavButton key={item.id} isActive={activeSection === item.id} onClick={() => goTo(item.id)} label={item.label}>
            {item.icon}
          </IconNavButton>
        ))}
      </div>

      <div className="flex-1" />

      <div className="flex flex-col gap-2 w-full items-center">
        <IconNavButton isActive={activeSection === "settings"} onClick={() => goTo("settings")} label="Settings">
          <SettingsIcon size={16} />
        </IconNavButton>
        <div className="size-8">
          <AvatarCircle />
        </div>
      </div>
    </aside>
  );
}

function SectionTitle({
  title,
  onToggleCollapse,
  isCollapsed,
}: {
  title: string;
  onToggleCollapse: () => void;
  isCollapsed: boolean;
}) {
  if (isCollapsed) {
    return (
      <div className="w-full hidden lg:flex justify-center transition-all duration-500" style={{ transitionTimingFunction: softSpringEasing }}>
        <button
          type="button"
          onClick={onToggleCollapse}
          className="flex items-center justify-center rounded-lg size-10 min-w-10 transition-all duration-500 hover:bg-[var(--surface-hover)] text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
          style={{ transitionTimingFunction: softSpringEasing }}
          aria-label="Expand sidebar"
        >
          <span className="inline-block rotate-180">
            <ChevronDownIcon size={16} />
          </span>
        </button>
      </div>
    );
  }

  return (
    <div className="w-full overflow-hidden transition-all duration-500" style={{ transitionTimingFunction: softSpringEasing }}>
      <div className="flex items-center justify-between">
        <div className="flex items-center h-10">
          <div className="px-2 py-1">
            <div className="font-semibold text-[18px] text-[var(--foreground)] leading-[27px]">{title}</div>
          </div>
        </div>
        <div className="pr-1 hidden lg:block">
          <button
            type="button"
            onClick={onToggleCollapse}
            className="flex items-center justify-center rounded-lg size-10 min-w-10 transition-all duration-500 hover:bg-[var(--surface-hover)] text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
            style={{ transitionTimingFunction: softSpringEasing }}
            aria-label="Collapse sidebar"
          >
            <ChevronDownIcon size={16} className="-rotate-90" />
          </button>
        </div>
      </div>
    </div>
  );
}

function MenuItem({ item, isCollapsed, isActive }: { item: MenuItemT; isCollapsed?: boolean; isActive: boolean }) {
  const content = (
    <div
      className={`rounded-lg cursor-pointer transition-all duration-500 flex items-center relative ${
        isActive ? "bg-[var(--surface-hover)]" : "hover:bg-[var(--surface-hover)]"
      } ${isCollapsed ? "w-10 min-w-10 h-10 justify-center p-4" : "w-full h-10 px-4 py-2"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      title={isCollapsed ? item.label : undefined}
    >
      <div className="flex items-center justify-center shrink-0">{item.icon}</div>
      <div
        className={`flex-1 relative transition-opacity duration-500 overflow-hidden ${isCollapsed ? "opacity-0 w-0" : "opacity-100 ml-3"}`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div className="text-[14px] text-[var(--foreground)] leading-[20px] truncate">{item.label}</div>
      </div>
    </div>
  );

  return (
    <div
      className={`relative shrink-0 transition-all duration-500 ${isCollapsed ? "w-full flex justify-center" : "w-full"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      {item.href ? (
        <Link href={item.href} className="block w-full">
          {content}
        </Link>
      ) : (
        content
      )}
    </div>
  );
}

function MenuSection({
  section,
  isCollapsed,
  pathname,
}: {
  section: MenuSectionT;
  isCollapsed?: boolean;
  pathname: string;
}) {
  return (
    <div className="flex flex-col w-full">
      <div
        className={`relative shrink-0 w-full transition-all duration-500 overflow-hidden ${isCollapsed ? "h-0 opacity-0" : "h-10 opacity-100"}`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div className="flex items-center h-10 px-4">
          <div className="text-[14px] text-[var(--text-muted)]">{section.title}</div>
        </div>
      </div>

      {section.items.map((item, index) => {
        const isActive = !!item.href && (pathname === item.href || pathname.startsWith(item.href + "/"));
        return <MenuItem key={`${section.title}-${index}`} item={item} isCollapsed={isCollapsed} isActive={isActive} />;
      })}
    </div>
  );
}

function DetailSidebar({ activeSection, pathname }: { activeSection: SectionId; pathname: string }) {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const { isOpen, close } = useSidebar();
  const content = getSidebarContent(activeSection);

  const toggleCollapse = () => setIsCollapsed((s) => !s);

  return (
    <>
      {/* Mobile backdrop - only rendered when the drawer is open */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/60 lg:hidden"
          onClick={close}
          aria-hidden="true"
        />
      )}

      <aside
        className={`bg-[var(--background)] flex flex-col gap-4 items-start p-4 transition-all duration-300 h-screen border-r border-[var(--surface-border)]
          fixed inset-y-0 left-0 z-50 w-72 max-w-[85vw] overflow-y-auto
          ${isOpen ? "translate-x-0" : "-translate-x-full"}
          lg:static lg:z-auto lg:translate-x-0 lg:transition-[width] lg:duration-500 lg:h-screen
          ${isCollapsed ? "lg:w-16 lg:min-w-16 lg:!px-0 lg:justify-center" : "lg:w-72"}
        `}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <button
          type="button"
          onClick={close}
          aria-label="Close menu"
          className="lg:hidden absolute top-4 right-4 flex items-center justify-center size-8 rounded-lg hover:bg-[var(--surface-hover)] text-[var(--text-muted)]"
        >
          <CloseIcon size={18} />
        </button>

        <BrandBadge />
        <SectionTitle title={content.title} onToggleCollapse={toggleCollapse} isCollapsed={isCollapsed} />
        <div className="w-full lg:hidden">
          <SearchContainer isCollapsed={false} />
        </div>
        <div className="w-full hidden lg:block">
          <SearchContainer isCollapsed={isCollapsed} />
        </div>

        <div
          className={`flex flex-col w-full overflow-y-auto transition-all duration-500 gap-4 items-start ${isCollapsed ? "lg:gap-2 lg:items-center" : ""}`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          {content.sections.map((section, index) => (
            <MenuSection key={`${activeSection}-${index}`} section={section} isCollapsed={isCollapsed} pathname={pathname} />
          ))}
        </div>

        <div className="w-full mt-auto pt-2 border-t border-[var(--surface-border)]">
          <div className="flex items-center gap-2 px-2 py-2">
            <AvatarCircle />
            <div className="text-[14px] text-[var(--foreground)]">Owner / Admin</div>
          </div>
        </div>
      </aside>
    </>
  );
}

export function AppSidebar() {
  const pathname = usePathname();
  const activeSection = getSectionFromPathname(pathname);

  return (
    <div className="flex flex-row">
      <IconNavigation activeSection={activeSection} />
      <DetailSidebar activeSection={activeSection} pathname={pathname} />
    </div>
  );
}

export default AppSidebar;
'@
Write-Utf8NoBom $sidebarPath $sidebarContent


Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  Topbar rewritten - hamburger button is guaranteed present now" -ForegroundColor Gray
Write-Host "  Sidebar rewritten - mobile drawer shows full nav (Dashboard, Raw" -ForegroundColor Gray
Write-Host "    Materials, Batches, Customers, Invoices, Payments, Reports," -ForegroundColor Gray
Write-Host "    Settings) since the icon-only rail doesn't fit on mobile" -ForegroundColor Gray
Write-Host "  Desktop (lg+) layout is unchanged - icon rail + detail panel" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT: restart the dev server:" -ForegroundColor Yellow
Write-Host "  Ctrl+C, then:" -ForegroundColor Yellow
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify: tap the hamburger icon (top-left, mobile) - full nav drawer should slide in." -ForegroundColor Cyan