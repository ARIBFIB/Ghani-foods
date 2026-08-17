# fix-sidebar-navigation.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\fix-sidebar-navigation.ps1
#
# Fixes: sidebar icon clicks weren't changing the URL, and clicking menu
# links (plain <a> tags) caused a full page reload that reset the sidebar's
# active section back to "Dashboard" even though the URL was correct.
#
# Fix: sidebar's active section is now derived from the real route
# (usePathname), and all internal links use next/link so navigation is
# client-side (no reload, no state reset).

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

Write-Host "=== Fixing sidebar navigation ===" -ForegroundColor Cyan

Write-CodeFile "components\ui\sidebar-component.tsx" @'
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
} from "@carbon/icons-react";

const softSpringEasing = "cubic-bezier(0.25, 1.1, 0.4, 1)";

// Section ids, in priority order for path matching (most specific first).
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

// Each section's default landing route (used when clicking its icon).
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

// Route prefixes -> section id. Order matters: checked longest/most-specific first.
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

function InterfacesLogoSquare() {
  return (
    <div className="aspect-[24/24] grow min-h-px min-w-px overflow-clip relative shrink-0">
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="size-4 rounded-sm bg-neutral-50" />
      </div>
    </div>
  );
}

function BrandBadge() {
  return (
    <div className="relative shrink-0 w-full">
      <div className="flex items-center p-1 w-full">
        <div className="h-10 w-8 flex items-center justify-center pl-2">
          <InterfacesLogoSquare />
        </div>
        <div className="px-2 py-1">
          <div className="font-semibold text-[16px] text-neutral-50">GhaniFoods</div>
        </div>
      </div>
    </div>
  );
}

function AvatarCircle() {
  return (
    <div className="relative rounded-full shrink-0 size-8 bg-black">
      <div className="flex items-center justify-center size-8">
        <UserIcon size={16} className="text-neutral-50" />
      </div>
      <div aria-hidden="true" className="absolute inset-0 rounded-full border border-neutral-800 pointer-events-none" />
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
        className={`bg-black h-10 relative rounded-lg flex items-center transition-all duration-500 ${
          isCollapsed ? "w-10 min-w-10 justify-center" : "w-full"
        }`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div
          className={`flex items-center justify-center shrink-0 transition-all duration-500 ${isCollapsed ? "p-1" : "px-1"}`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          <div className="size-8 flex items-center justify-center">
            <SearchIcon size={16} className="text-neutral-50" />
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
                className="w-full bg-transparent border-none outline-none text-[14px] text-neutral-50 placeholder:text-neutral-400 leading-[20px]"
                tabIndex={isCollapsed ? -1 : 0}
              />
            </div>
          </div>
        </div>

        <div aria-hidden="true" className="absolute inset-0 rounded-lg border border-neutral-800 pointer-events-none" />
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
        { title: "Overview", items: [{ icon: <View size={16} className="text-neutral-50" />, label: "Dashboard", href: "/" }] },
      ],
    },
    "raw-materials": {
      title: "Raw Materials",
      sections: [
        {
          title: "Inventory",
          items: [
            { icon: <Folder size={16} className="text-neutral-50" />, label: "All Raw Materials", href: "/raw-materials" },
            { icon: <FolderOpen size={16} className="text-neutral-50" />, label: "Packaging Materials", href: "/packaging" },
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
            { icon: <Task size={16} className="text-neutral-50" />, label: "All Batches", href: "/batches" },
            { icon: <AddLarge size={16} className="text-neutral-50" />, label: "New Batch", href: "/batches/new" },
          ],
        },
      ],
    },
    "finished-cartons": {
      title: "Finished Cartons",
      sections: [
        { title: "Stock", items: [{ icon: <Archive size={16} className="text-neutral-50" />, label: "Ready Stock", href: "/finished-cartons" }] },
      ],
    },
    customers: {
      title: "Customers",
      sections: [
        { title: "Customers", items: [{ icon: <UserMultiple size={16} className="text-neutral-50" />, label: "All Customers", href: "/customers" }] },
      ],
    },
    invoices: {
      title: "Invoices",
      sections: [
        {
          title: "Invoices",
          items: [
            { icon: <DocumentAdd size={16} className="text-neutral-50" />, label: "All Invoices", href: "/invoices" },
            { icon: <AddLarge size={16} className="text-neutral-50" />, label: "New Invoice", href: "/invoices/new" },
          ],
        },
      ],
    },
    payments: {
      title: "Payments",
      sections: [
        { title: "Payments", items: [{ icon: <ChartBar size={16} className="text-neutral-50" />, label: "All Payments", href: "/payments" }] },
      ],
    },
    reports: {
      title: "Reports",
      sections: [
        {
          title: "Analytics",
          items: [
            { icon: <Report size={16} className="text-neutral-50" />, label: "Inventory Movement", href: "/reports" },
            { icon: <Analytics size={16} className="text-neutral-50" />, label: "Production Yield", href: "/reports" },
            { icon: <StarFilled size={16} className="text-neutral-50" />, label: "P&L", href: "/reports" },
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
            { icon: <SettingsIcon size={16} className="text-neutral-50" />, label: "Business Profile", href: "/settings" },
            { icon: <Security size={16} className="text-neutral-50" />, label: "Security" },
            { icon: <Notification size={16} className="text-neutral-50" />, label: "Notifications" },
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
        ${isActive ? "bg-neutral-800 text-neutral-50" : "hover:bg-neutral-800 text-neutral-400 hover:text-neutral-300"}`}
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
    <aside className="bg-black flex flex-col gap-2 items-center p-4 w-16 h-screen border-r border-neutral-800">
      <div className="mb-2 size-10 flex items-center justify-center">
        <div className="size-7">
          <InterfacesLogoSquare />
        </div>
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
      <div className="w-full flex justify-center transition-all duration-500" style={{ transitionTimingFunction: softSpringEasing }}>
        <button
          type="button"
          onClick={onToggleCollapse}
          className="flex items-center justify-center rounded-lg size-10 min-w-10 transition-all duration-500 hover:bg-neutral-800 text-neutral-400 hover:text-neutral-300"
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
            <div className="font-semibold text-[18px] text-neutral-50 leading-[27px]">{title}</div>
          </div>
        </div>
        <div className="pr-1">
          <button
            type="button"
            onClick={onToggleCollapse}
            className="flex items-center justify-center rounded-lg size-10 min-w-10 transition-all duration-500 hover:bg-neutral-800 text-neutral-400 hover:text-neutral-300"
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
        isActive ? "bg-neutral-800" : "hover:bg-neutral-800"
      } ${isCollapsed ? "w-10 min-w-10 h-10 justify-center p-4" : "w-full h-10 px-4 py-2"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      title={isCollapsed ? item.label : undefined}
    >
      <div className="flex items-center justify-center shrink-0">{item.icon}</div>
      <div
        className={`flex-1 relative transition-opacity duration-500 overflow-hidden ${isCollapsed ? "opacity-0 w-0" : "opacity-100 ml-3"}`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div className="text-[14px] text-neutral-50 leading-[20px] truncate">{item.label}</div>
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
          <div className="text-[14px] text-neutral-400">{section.title}</div>
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
  const content = getSidebarContent(activeSection);

  const toggleCollapse = () => setIsCollapsed((s) => !s);

  return (
    <aside
      className={`bg-black flex flex-col gap-4 items-start p-4 transition-all duration-500 h-screen border-r border-neutral-800 ${
        isCollapsed ? "w-16 min-w-16 !px-0 justify-center" : "w-72"
      }`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      {!isCollapsed && <BrandBadge />}
      <SectionTitle title={content.title} onToggleCollapse={toggleCollapse} isCollapsed={isCollapsed} />
      {!isCollapsed && <SearchContainer isCollapsed={isCollapsed} />}

      <div
        className={`flex flex-col w-full overflow-y-auto transition-all duration-500 ${isCollapsed ? "gap-2 items-center" : "gap-4 items-start"}`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        {content.sections.map((section, index) => (
          <MenuSection key={`${activeSection}-${index}`} section={section} isCollapsed={isCollapsed} pathname={pathname} />
        ))}
      </div>

      {!isCollapsed && (
        <div className="w-full mt-auto pt-2 border-t border-neutral-800">
          <div className="flex items-center gap-2 px-2 py-2">
            <AvatarCircle />
            <div className="text-[14px] text-neutral-50">Owner / Admin</div>
          </div>
        </div>
      )}
    </aside>
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

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "Sidebar now derives its active section from the real URL (usePathname)" -ForegroundColor Green
Write-Host "and uses next/link everywhere, so:" -ForegroundColor Green
Write-Host "  - Clicking a left icon actually navigates (router.push) to that section." -ForegroundColor Yellow
Write-Host "  - Clicking a detail-menu link (e.g. All Raw Materials) no longer reloads" -ForegroundColor Yellow
Write-Host "    the page, so the sidebar stays in sync with the URL." -ForegroundColor Yellow
Write-Host "  - Browser back/forward also keeps the sidebar correct." -ForegroundColor Yellow