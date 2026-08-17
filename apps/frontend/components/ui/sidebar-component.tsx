"use client";

import React, { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Search as SearchIcon,
  Dashboard,
  Grain,
  Archive,
  Package,
  UserMultiple,
  Analytics,
  DocumentAdd,
  Settings as SettingsIcon,
  User as UserIcon,
  ChevronDown as ChevronDownIcon,
  Money,
} from "@carbon/icons-react";

const softSpringEasing = "cubic-bezier(0.25, 1.1, 0.4, 1)";

function LogoBadge() {
  return (
    <div className="relative shrink-0 w-full">
      <div className="flex items-center p-1 w-full">
        <div className="h-10 w-8 flex items-center justify-center">
          <div className="size-6 rounded-md bg-neutral-50" />
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
    <div className="relative rounded-full shrink-0 size-8 bg-neutral-800 flex items-center justify-center">
      <UserIcon size={16} className="text-neutral-50" />
    </div>
  );
}

function SearchBox({ isCollapsed }: { isCollapsed: boolean }) {
  const [value, setValue] = useState("");
  return (
    <div
      className={`bg-neutral-900 h-10 relative rounded-lg flex items-center transition-all duration-500 w-full ${
        isCollapsed ? "justify-center" : ""
      }`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      <div className="size-8 flex items-center justify-center shrink-0">
        <SearchIcon size={16} className="text-neutral-50" />
      </div>
      {!isCollapsed && (
        <input
          type="text"
          placeholder="Search..."
          value={value}
          onChange={(e) => setValue(e.target.value)}
          className="w-full bg-transparent border-none outline-none text-[14px] text-neutral-50 placeholder:text-neutral-500"
        />
      )}
      <div className="absolute inset-0 rounded-lg border border-neutral-800 pointer-events-none" />
    </div>
  );
}

type NavItem = { href: string; label: string; icon: React.ReactNode };

const NAV_ITEMS: NavItem[] = [
  { href: "/", label: "Dashboard", icon: <Dashboard size={16} /> },
  { href: "/raw-materials", label: "Raw Materials", icon: <Grain size={16} /> },
  { href: "/packaging", label: "Packaging", icon: <Archive size={16} /> },
  { href: "/batches", label: "Production Batches", icon: <Package size={16} /> },
  { href: "/finished-cartons", label: "Finished Cartons", icon: <Archive size={16} /> },
  { href: "/customers", label: "Customers", icon: <UserMultiple size={16} /> },
  { href: "/invoices", label: "Invoices", icon: <DocumentAdd size={16} /> },
  { href: "/payments", label: "Payments", icon: <Money size={16} /> },
  { href: "/reports", label: "Reports", icon: <Analytics size={16} /> },
];

function IconNavButton({
  children,
  isActive,
  href,
}: {
  children: React.ReactNode;
  isActive: boolean;
  href: string;
}) {
  return (
    <Link
      href={href}
      className={`flex items-center justify-center rounded-lg size-10 min-w-10 transition-colors duration-500 ${
        isActive
          ? "bg-neutral-800 text-neutral-50"
          : "hover:bg-neutral-800 text-neutral-400 hover:text-neutral-300"
      }`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      {children}
    </Link>
  );
}

function IconRail({ pathname }: { pathname: string }) {
  return (
    <aside className="bg-black flex flex-col gap-2 items-center p-4 w-16 min-h-screen border-r border-neutral-800">
      <div className="mb-2 size-10 flex items-center justify-center">
        <div className="size-7 rounded-md bg-neutral-50" />
      </div>
      <div className="flex flex-col gap-2 w-full items-center">
        {NAV_ITEMS.map((item) => (
          <IconNavButton key={item.href} href={item.href} isActive={pathname === item.href}>
            {item.icon}
          </IconNavButton>
        ))}
      </div>
      <div className="flex-1" />
      <div className="flex flex-col gap-2 w-full items-center">
        <IconNavButton href="/settings" isActive={pathname === "/settings"}>
          <SettingsIcon size={16} />
        </IconNavButton>
        <AvatarCircle />
      </div>
    </aside>
  );
}

function DetailPanel({ pathname }: { pathname: string }) {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const active = NAV_ITEMS.find((n) => n.href === pathname);

  return (
    <aside
      className={`bg-black flex flex-col gap-4 items-start p-4 transition-all duration-500 min-h-screen border-r border-neutral-800 ${
        isCollapsed ? "w-16 !px-0 items-center" : "w-64"
      }`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      {!isCollapsed && <LogoBadge />}

      <div className="w-full flex items-center justify-between">
        {!isCollapsed && (
          <div className="px-2 py-1 text-[16px] font-semibold text-neutral-50">
            {active?.label ?? "GhaniFoods"}
          </div>
        )}
        <button
          type="button"
          onClick={() => setIsCollapsed((s) => !s)}
          className="flex items-center justify-center rounded-lg size-10 min-w-10 hover:bg-neutral-800 text-neutral-400"
          aria-label="Toggle sidebar"
        >
          <ChevronDownIcon size={16} className={isCollapsed ? "rotate-180" : "-rotate-90"} />
        </button>
      </div>

      {!isCollapsed && <SearchBox isCollapsed={isCollapsed} />}

      <nav className="flex flex-col gap-1 w-full">
        {NAV_ITEMS.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`h-10 rounded-lg flex items-center px-3 gap-3 transition-colors ${
              pathname === item.href ? "bg-neutral-800" : "hover:bg-neutral-800"
            } ${isCollapsed ? "justify-center px-0" : ""}`}
          >
            <span className="text-neutral-50 shrink-0">{item.icon}</span>
            {!isCollapsed && (
              <span className="text-[14px] text-neutral-50 truncate">{item.label}</span>
            )}
          </Link>
        ))}
      </nav>

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
  return (
    <div className="flex flex-row">
      <IconRail pathname={pathname} />
      <DetailPanel pathname={pathname} />
    </div>
  );
}

export default AppSidebar;