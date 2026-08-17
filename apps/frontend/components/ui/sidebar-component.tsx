"use client";

import React, { useState } from "react";
import {
  Search as SearchIcon,
  Dashboard,
  Task,
  Folder,
  Calendar as CalendarIcon,
  UserMultiple,
  Analytics,
  DocumentAdd,
  Settings as SettingsIcon,
  User as UserIcon,
  ChevronDown as ChevronDownIcon,
  AddLarge,
  Filter,
  Time,
  InProgress,
  CheckmarkOutline,
  Flag,
  Archive,
  View,
  Report,
  StarFilled,
  Group,
  ChartBar,
  FolderOpen,
  Share,
  CloudUpload,
  Security,
  Notification,
  Integration,
} from "@carbon/icons-react";

const softSpringEasing = "cubic-bezier(0.25, 1.1, 0.4, 1)";

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
      <div
        aria-hidden="true"
        className="absolute inset-0 rounded-full border border-neutral-800 pointer-events-none"
      />
    </div>
  );
}

function SearchContainer({ isCollapsed = false }: { isCollapsed?: boolean }) {
  const [searchValue, setSearchValue] = useState("");

  return (
    <div
      className={`relative shrink-0 transition-all duration-500 ${
        isCollapsed ? "w-full flex justify-center" : "w-full"
      }`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      <div
        className={`bg-black h-10 relative rounded-lg flex items-center transition-all duration-500 ${
          isCollapsed ? "w-10 min-w-10 justify-center" : "w-full"
        }`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div
          className={`flex items-center justify-center shrink-0 transition-all duration-500 ${
            isCollapsed ? "p-1" : "px-1"
          }`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          <div className="size-8 flex items-center justify-center">
            <SearchIcon size={16} className="text-neutral-50" />
          </div>
        </div>

        <div
          className={`flex-1 relative transition-opacity duration-500 overflow-hidden ${
            isCollapsed ? "opacity-0 w-0" : "opacity-100"
          }`}
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

        <div
          aria-hidden="true"
          className="absolute inset-0 rounded-lg border border-neutral-800 pointer-events-none"
        />
      </div>
    </div>
  );
}

interface MenuItemT {
  icon?: React.ReactNode;
  label: string;
  href?: string;
  hasDropdown?: boolean;
  isActive?: boolean;
  children?: MenuItemT[];
}
interface MenuSectionT {
  title: string;
  items: MenuItemT[];
}
interface SidebarContent {
  title: string;
  sections: MenuSectionT[];
}

// GhaniFoods-specific nav map (mirrors the 17-page routing map from the spec)
function getSidebarContent(activeSection: string): SidebarContent {
  const contentMap: Record<string, SidebarContent> = {
    dashboard: {
      title: "Dashboard",
      sections: [
        {
          title: "Overview",
          items: [{ icon: <View size={16} className="text-neutral-50" />, label: "Dashboard", href: "/", isActive: true }],
        },
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
        {
          title: "Stock",
          items: [{ icon: <Archive size={16} className="text-neutral-50" />, label: "Ready Stock", href: "/finished-cartons" }],
        },
      ],
    },
    customers: {
      title: "Customers",
      sections: [
        {
          title: "Customers",
          items: [{ icon: <UserMultiple size={16} className="text-neutral-50" />, label: "All Customers", href: "/customers" }],
        },
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
        {
          title: "Payments",
          items: [{ icon: <ChartBar size={16} className="text-neutral-50" />, label: "All Payments", href: "/payments" }],
        },
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

  return contentMap[activeSection] || contentMap.dashboard;
}

function IconNavButton({
  children,
  isActive = false,
  onClick,
}: {
  children: React.ReactNode;
  isActive?: boolean;
  onClick?: () => void;
}) {
  return (
    <button
      type="button"
      className={`flex items-center justify-center rounded-lg size-10 min-w-10 transition-colors duration-500
        ${isActive ? "bg-neutral-800 text-neutral-50" : "hover:bg-neutral-800 text-neutral-400 hover:text-neutral-300"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      onClick={onClick}
    >
      {children}
    </button>
  );
}

function IconNavigation({
  activeSection,
  onSectionChange,
}: {
  activeSection: string;
  onSectionChange: (section: string) => void;
}) {
  const navItems = [
    { id: "dashboard", icon: <Dashboard size={16} />, label: "Dashboard" },
    { id: "raw-materials", icon: <Folder size={16} />, label: "Raw Materials" },
    { id: "batches", icon: <Task size={16} />, label: "Batches" },
    { id: "finished-cartons", icon: <Archive size={16} />, label: "Finished Cartons" },
    { id: "customers", icon: <UserMultiple size={16} />, label: "Customers" },
    { id: "invoices", icon: <DocumentAdd size={16} />, label: "Invoices" },
    { id: "payments", icon: <ChartBar size={16} />, label: "Payments" },
    { id: "reports", icon: <Analytics size={16} />, label: "Reports" },
  ];

  return (
    <aside className="bg-black flex flex-col gap-2 items-center p-4 w-16 h-screen border-r border-neutral-800">
      <div className="mb-2 size-10 flex items-center justify-center">
        <div className="size-7">
          <InterfacesLogoSquare />
        </div>
      </div>

      <div className="flex flex-col gap-2 w-full items-center">
        {navItems.map((item) => (
          <IconNavButton key={item.id} isActive={activeSection === item.id} onClick={() => onSectionChange(item.id)}>
            {item.icon}
          </IconNavButton>
        ))}
      </div>

      <div className="flex-1" />

      <div className="flex flex-col gap-2 w-full items-center">
        <IconNavButton isActive={activeSection === "settings"} onClick={() => onSectionChange("settings")}>
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
      <div
        className="w-full flex justify-center transition-all duration-500"
        style={{ transitionTimingFunction: softSpringEasing }}
      >
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

function MenuItem({
  item,
  isExpanded,
  onToggle,
  isCollapsed,
}: {
  item: MenuItemT;
  isExpanded?: boolean;
  onToggle?: () => void;
  isCollapsed?: boolean;
}) {
  const content = (
    <div
      className={`rounded-lg cursor-pointer transition-all duration-500 flex items-center relative ${
        item.isActive ? "bg-neutral-800" : "hover:bg-neutral-800"
      } ${isCollapsed ? "w-10 min-w-10 h-10 justify-center p-4" : "w-full h-10 px-4 py-2"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
      onClick={item.hasDropdown ? onToggle : undefined}
      title={isCollapsed ? item.label : undefined}
    >
      <div className="flex items-center justify-center shrink-0">{item.icon}</div>
      <div
        className={`flex-1 relative transition-opacity duration-500 overflow-hidden ${
          isCollapsed ? "opacity-0 w-0" : "opacity-100 ml-3"
        }`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div className="text-[14px] text-neutral-50 leading-[20px] truncate">{item.label}</div>
      </div>
      {item.hasDropdown && (
        <div
          className={`flex items-center justify-center shrink-0 transition-opacity duration-500 ${
            isCollapsed ? "opacity-0 w-0" : "opacity-100 ml-2"
          }`}
          style={{ transitionTimingFunction: softSpringEasing }}
        >
          <ChevronDownIcon
            size={16}
            className="text-neutral-50 transition-transform duration-500"
            style={{
              transitionTimingFunction: softSpringEasing,
              transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)",
            }}
          />
        </div>
      )}
    </div>
  );

  return (
    <div
      className={`relative shrink-0 transition-all duration-500 ${isCollapsed ? "w-full flex justify-center" : "w-full"}`}
      style={{ transitionTimingFunction: softSpringEasing }}
    >
      {item.href && !item.hasDropdown ? (
        <a href={item.href} className="block w-full">
          {content}
        </a>
      ) : (
        content
      )}
    </div>
  );
}

function SubMenuItem({ item }: { item: MenuItemT }) {
  const inner = (
    <div className="h-10 w-full rounded-lg cursor-pointer transition-colors hover:bg-neutral-800 flex items-center px-3 py-1">
      <div className="flex-1 min-w-0">
        <div className="text-[14px] text-neutral-300 leading-[18px] truncate">{item.label}</div>
      </div>
    </div>
  );
  return (
    <div className="w-full pl-9 pr-1 py-[1px]">
      {item.href ? <a href={item.href}>{inner}</a> : inner}
    </div>
  );
}

function MenuSection({
  section,
  expandedItems,
  onToggleExpanded,
  isCollapsed,
}: {
  section: MenuSectionT;
  expandedItems: Set<string>;
  onToggleExpanded: (itemKey: string) => void;
  isCollapsed?: boolean;
}) {
  return (
    <div className="flex flex-col w-full">
      <div
        className={`relative shrink-0 w-full transition-all duration-500 overflow-hidden ${
          isCollapsed ? "h-0 opacity-0" : "h-10 opacity-100"
        }`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        <div className="flex items-center h-10 px-4">
          <div className="text-[14px] text-neutral-400">{section.title}</div>
        </div>
      </div>

      {section.items.map((item, index) => {
        const itemKey = `${section.title}-${index}`;
        const isExpanded = expandedItems.has(itemKey);
        return (
          <div key={itemKey} className="w-full flex flex-col">
            <MenuItem item={item} isExpanded={isExpanded} onToggle={() => onToggleExpanded(itemKey)} isCollapsed={isCollapsed} />
            {isExpanded && item.children && !isCollapsed && (
              <div className="flex flex-col gap-1 mb-2">
                {item.children.map((child, childIndex) => (
                  <SubMenuItem key={`${itemKey}-${childIndex}`} item={child} />
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function DetailSidebar({ activeSection }: { activeSection: string }) {
  const [expandedItems, setExpandedItems] = useState<Set<string>>(new Set());
  const [isCollapsed, setIsCollapsed] = useState(false);
  const content = getSidebarContent(activeSection);

  const toggleExpanded = (itemKey: string) => {
    setExpandedItems((prev) => {
      const next = new Set(prev);
      if (next.has(itemKey)) next.delete(itemKey);
      else next.add(itemKey);
      return next;
    });
  };

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
        className={`flex flex-col w-full overflow-y-auto transition-all duration-500 ${
          isCollapsed ? "gap-2 items-center" : "gap-4 items-start"
        }`}
        style={{ transitionTimingFunction: softSpringEasing }}
      >
        {content.sections.map((section, index) => (
          <MenuSection
            key={`${activeSection}-${index}`}
            section={section}
            expandedItems={expandedItems}
            onToggleExpanded={toggleExpanded}
            isCollapsed={isCollapsed}
          />
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

export function AppSidebar({ activeSection = "dashboard" }: { activeSection?: string }) {
  const [section, setSection] = useState(activeSection);
  return (
    <div className="flex flex-row">
      <IconNavigation activeSection={section} onSectionChange={setSection} />
      <DetailSidebar activeSection={section} />
    </div>
  );
}

export default AppSidebar;
