# fix-sidebar-navigation-loading.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\fix-sidebar-navigation-loading.ps1
#
# Adds a Lottie loading overlay (public/loading/loading.json) that shows
# for the brief gap when switching sidebar tabs, so the screen never looks
# blank/frozen during route changes.
#
# Creates:
#   apps/frontend/lib/navigation-loading-context.tsx
#   apps/frontend/components/ui/navigation-loading-overlay.tsx
# Overwrites:
#   apps/frontend/app/(dashboard)/layout.tsx
#   apps/frontend/components/ui/sidebar-component.tsx

$FrontendRoot = Join-Path (Get-Location) "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: Could not find apps\frontend under $(Get-Location)" -ForegroundColor Red
    Write-Host "Make sure you run this script from the GhaniFoods project root." -ForegroundColor Yellow
    exit 1
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Host "=== Adding sidebar navigation loading overlay ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. New file: lib/navigation-loading-context.tsx
# ---------------------------------------------------------------------------
$navContextPath = Join-Path $FrontendRoot "lib\navigation-loading-context.tsx"
$navContextContent = @'
"use client";

import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  useTransition,
  type ReactNode,
} from "react";
import { useRouter } from "next/navigation";

type NavigationLoadingContextValue = {
  isLoading: boolean;
  navigate: (href: string) => void;
};

const MIN_VISIBLE_MS = 300;

const NavigationLoadingContext = createContext<NavigationLoadingContextValue | null>(null);

export function NavigationLoadingProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [minTimeElapsed, setMinTimeElapsed] = useState(true);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const navigate = (href: string) => {
    setMinTimeElapsed(false);
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => setMinTimeElapsed(true), MIN_VISIBLE_MS);
    startTransition(() => {
      router.push(href);
    });
  };

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, []);

  const isLoading = isPending || !minTimeElapsed;

  return (
    <NavigationLoadingContext.Provider value={{ isLoading, navigate }}>
      {children}
    </NavigationLoadingContext.Provider>
  );
}

export function useNavigationLoading() {
  const ctx = useContext(NavigationLoadingContext);
  if (!ctx) throw new Error("useNavigationLoading must be used within NavigationLoadingProvider");
  return ctx;
}
'@
Write-Utf8NoBom $navContextPath $navContextContent
Write-Host "  Created: lib\navigation-loading-context.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. New file: components/ui/navigation-loading-overlay.tsx
# ---------------------------------------------------------------------------
$overlayPath = Join-Path $FrontendRoot "components\ui\navigation-loading-overlay.tsx"
$overlayContent = @'
"use client";

import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { LottieLoader } from "@/components/ui/lottie-loader";

export function NavigationLoadingOverlay() {
  const { isLoading } = useNavigationLoading();

  if (!isLoading) return null;

  return (
    <div className="fixed inset-0 z-[90] flex flex-col items-center justify-center bg-[var(--background)]/70 backdrop-blur-sm">
      <LottieLoader src="/loading/loading.json" size={120} />
    </div>
  );
}

export default NavigationLoadingOverlay;
'@
Write-Utf8NoBom $overlayPath $overlayContent
Write-Host "  Created: components\ui\navigation-loading-overlay.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. Overwrite: app/(dashboard)/layout.tsx
# ---------------------------------------------------------------------------
$layoutPath = Join-Path $FrontendRoot "app\(dashboard)\layout.tsx"
$layoutContent = @'
import type { ReactNode } from "react";
import { AppSidebar } from "@/components/ui/sidebar-component";
import { Topbar } from "@/components/ui/topbar";
import { SidebarProvider } from "@/lib/sidebar-context";
import { NavigationLoadingProvider } from "@/lib/navigation-loading-context";
import { NavigationLoadingOverlay } from "@/components/ui/navigation-loading-overlay";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <NavigationLoadingProvider>
      <SidebarProvider>
        <div className="flex min-h-screen bg-[var(--background)]">
          <AppSidebar />
          <div className="flex-1 flex flex-col min-w-0">
            <Topbar />
            <main className="flex-1 p-4 sm:p-6 overflow-y-auto overflow-x-hidden text-[var(--foreground)]">
              {children}
            </main>
          </div>
        </div>
        <NavigationLoadingOverlay />
      </SidebarProvider>
    </NavigationLoadingProvider>
  );
}
'@
Write-Utf8NoBom $layoutPath $layoutContent
Write-Host "  Updated: app\(dashboard)\layout.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Overwrite: components/ui/sidebar-component.tsx
#    (sidebar tab clicks now go through navigate() so the overlay shows)
# ---------------------------------------------------------------------------
$sidebarPath = Join-Path $FrontendRoot "components\ui\sidebar-component.tsx"
$sidebarContent = @'
"use client";

import React, { useState } from "react";
import { usePathname } from "next/navigation";
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
import { useNavigationLoading } from "@/lib/navigation-loading-context";

const softSpringEasing = "cubic-bezier(0.25, 1.1, 0.4, 1)";

type SectionId =
  | "dashboard"
  | "suppliers"
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
  suppliers: "/suppliers",
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
  ["/suppliers", "suppliers"],
  ["/raw-materials", "raw-materials"],
  ["/packaging", "raw-materials"],
  ["/packaging/carton-config", "raw-materials"],
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
            { icon: <Archive size={16} className="text-[var(--foreground)]" />, label: "Carton Configurations", href: "/packaging/carton-config" },
          ],
        },
      ],
    },
    suppliers: {
      title: "Suppliers",
      sections: [
        { title: "Suppliers", items: [{ icon: <UserMultiple size={16} className="text-[var(--foreground)]" />, label: "All Suppliers", href: "/suppliers" }] },
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
  const { navigate } = useNavigationLoading();

  const navItems: Array<{ id: SectionId; icon: React.ReactNode; label: string }> = [
    { id: "dashboard", icon: <Dashboard size={16} />, label: "Dashboard" },
    { id: "raw-materials", icon: <Folder size={16} />, label: "Raw Materials" },
    { id: "suppliers", icon: <UserMultiple size={16} />, label: "Suppliers" },
    { id: "batches", icon: <Task size={16} />, label: "Batches" },
    { id: "finished-cartons", icon: <Archive size={16} />, label: "Finished Cartons" },
    { id: "customers", icon: <UserMultiple size={16} />, label: "Customers" },
    { id: "invoices", icon: <DocumentAdd size={16} />, label: "Invoices" },
    { id: "payments", icon: <ChartBar size={16} />, label: "Payments" },
    { id: "reports", icon: <Analytics size={16} />, label: "Reports" },
  ];

  const goTo = (section: SectionId) => navigate(SECTION_DEFAULT_ROUTE[section]);

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


function MobileSectionNav({ activeSection }: { activeSection: SectionId }) {
  const { navigate } = useNavigationLoading();

  const navItems: Array<{ id: SectionId; icon: React.ReactNode; label: string }> = [
    { id: "dashboard", icon: <Dashboard size={18} />, label: "Dashboard" },
    { id: "raw-materials", icon: <Folder size={18} />, label: "Raw Materials" },
    { id: "suppliers", icon: <UserMultiple size={18} />, label: "Suppliers" },
    { id: "batches", icon: <Task size={18} />, label: "Batches" },
    { id: "finished-cartons", icon: <Archive size={18} />, label: "Finished Cartons" },
    { id: "customers", icon: <UserMultiple size={18} />, label: "Customers" },
    { id: "invoices", icon: <DocumentAdd size={18} />, label: "Invoices" },
    { id: "payments", icon: <ChartBar size={18} />, label: "Payments" },
    { id: "reports", icon: <Analytics size={18} />, label: "Reports" },
    { id: "settings", icon: <SettingsIcon size={18} />, label: "Settings" },
  ];

  const goTo = (section: SectionId) => navigate(SECTION_DEFAULT_ROUTE[section]);

  return (
    <div className="w-full lg:hidden flex flex-col gap-1">
      <div className="px-2 py-1 text-[14px] text-[var(--text-muted)]">Sections</div>
      <div className="grid grid-cols-1 gap-1">
        {navItems.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => goTo(item.id)}
            className={`flex items-center gap-3 rounded-lg px-4 py-2.5 text-left transition-colors duration-300 ${
              activeSection === item.id
                ? "bg-[var(--surface-hover)] text-[var(--foreground)]"
                : "text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]"
            }`}
          >
            <span className="shrink-0">{item.icon}</span>
            <span className="text-[14px]">{item.label}</span>
          </button>
        ))}
      </div>
      <div className="h-px w-full bg-[var(--surface-border)] my-2" />
    </div>
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
  const { navigate } = useNavigationLoading();

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
        <button type="button" onClick={() => navigate(item.href!)} className="block w-full text-left">
          {content}
        </button>
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
        <MobileSectionNav activeSection={activeSection} />
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
Write-Host "  Updated: components\ui\sidebar-component.tsx" -ForegroundColor Green

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Please review with 'git diff', test locally (npm run dev:frontend), then commit and redeploy." -ForegroundColor Yellow