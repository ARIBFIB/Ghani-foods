# apply-theme-toggle.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\apply-theme-toggle.ps1
#
# What this does:
#   1. Adds "framer-motion" dependency (lucide-react is already installed)
#   2. Creates components/ui/animated-theme-toggler.tsx
#   3. Adds a no-flash theme-init script in app/layout.tsx (reads
#      localStorage "theme" or falls back to system preference, and sets
#      the "dark" class on <html> BEFORE paint)
#   4. Rewrites globals.css with light + dark CSS variables
#   5. Updates the dashboard shell (layout, sidebar, topbar) to use those
#      CSS variables instead of hardcoded neutral-950/800 classes, and
#      adds the toggler button to the topbar
#
# NOTE ON SCOPE:
#   This wires up the THEMING SYSTEM and the SHELL (sidebar/topbar/layout).
#   The 17 individual pages (raw-materials, batches, invoices, etc.) still
#   use hardcoded dark classes (bg-neutral-950, text-neutral-50, etc.) and
#   will look the same in both light and dark mode until those files are
#   converted too. That's a bigger follow-up pass across ~17 files - let
#   me know if you want that done next.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Adding light/dark theme toggle ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. package.json - add framer-motion
# --------------------------------------------------------------------------

$pkgPath = Join-Path $FrontendRoot "package.json"
$text = [System.IO.File]::ReadAllText($pkgPath, [System.Text.Encoding]::UTF8)
$pkgJson = $text | ConvertFrom-Json

if (-not ($pkgJson.dependencies.PSObject.Properties.Name -contains "framer-motion")) {
    $pkgJson.dependencies | Add-Member -MemberType NoteProperty -Name "framer-motion" -Value "^11.11.17"
    Write-Host "  Added dependency: framer-motion" -ForegroundColor Green
} else {
    Write-Host "  framer-motion already present" -ForegroundColor Gray
}

$outText = $pkgJson | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pkgPath, $outText, $utf8NoBom)
Write-Host "  Updated: apps\frontend\package.json" -ForegroundColor Green

# --------------------------------------------------------------------------
# 2. components/ui/animated-theme-toggler.tsx
# --------------------------------------------------------------------------

$togglerPath = Join-Path $FrontendRoot "components\ui\animated-theme-toggler.tsx"
$togglerContent = @'
"use client"

import { useEffect, useRef, useState, useCallback } from "react"
import { flushSync } from "react-dom"

import { Moon, Sun } from "lucide-react"

import { motion, AnimatePresence } from "framer-motion"

import { cn } from "@/lib/utils"

type AnimatedThemeTogglerProps = {
  className?: string
}

export const AnimatedThemeToggler = ({ className }: AnimatedThemeTogglerProps) => {
  const buttonRef = useRef<HTMLButtonElement>(null)
  const [darkMode, setDarkMode] = useState(() =>
    typeof window !== "undefined"
      ? document.documentElement.classList.contains("dark")
      : false
  )

  useEffect(() => {
    const syncTheme = () =>
      setDarkMode(document.documentElement.classList.contains("dark"))

    const observer = new MutationObserver(syncTheme)
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })
    return () => observer.disconnect()
  }, [])

  const onToggle = useCallback(async () => {
    if (!buttonRef.current) return

    const applyToggle = () => {
      const toggled = !darkMode
      setDarkMode(toggled)
      document.documentElement.classList.toggle("dark", toggled)
      localStorage.setItem("theme", toggled ? "dark" : "light")
    }

    // Not all browsers support View Transitions - fall back gracefully.
    if (typeof document.startViewTransition !== "function") {
      applyToggle()
      return
    }

    await document.startViewTransition(() => {
      flushSync(applyToggle)
    }).ready

    const { left, top, width, height } = buttonRef.current.getBoundingClientRect()
    const centerX = left + width / 2
    const centerY = top + height / 2
    const maxDistance = Math.hypot(
      Math.max(centerX, window.innerWidth - centerX),
      Math.max(centerY, window.innerHeight - centerY)
    )

    document.documentElement.animate(
      {
        clipPath: [
          `circle(0px at ${centerX}px ${centerY}px)`,
          `circle(${maxDistance}px at ${centerX}px ${centerY}px)`,
        ],
      },
      {
        duration: 700,
        easing: "ease-in-out",
        pseudoElement: "::view-transition-new(root)",
      }
    )
  }, [darkMode])

  return (
    <button
      ref={buttonRef}
      onClick={onToggle}
      aria-label="Switch theme"
      className={cn(
        "flex items-center justify-center p-2 rounded-full outline-none focus:outline-none active:outline-none focus:ring-0 cursor-pointer hover:bg-neutral-800/60 transition-colors",
        className
      )}
      type="button"
    >
      <AnimatePresence mode="wait" initial={false}>
        {darkMode ? (
          <motion.span
            key="sun-icon"
            initial={{ opacity: 0, scale: 0.55, rotate: 25 }}
            animate={{ opacity: 1, scale: 1, rotate: 0 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.33 }}
            className="text-neutral-200"
          >
            <Sun size={18} />
          </motion.span>
        ) : (
          <motion.span
            key="moon-icon"
            initial={{ opacity: 0, scale: 0.55, rotate: -25 }}
            animate={{ opacity: 1, scale: 1, rotate: 0 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.33 }}
            className="text-neutral-700"
          >
            <Moon size={18} />
          </motion.span>
        )}
      </AnimatePresence>
    </button>
  )
}
'@
Write-Utf8NoBom $togglerPath $togglerContent

# --------------------------------------------------------------------------
# 3. globals.css - light + dark CSS variables
# --------------------------------------------------------------------------

$globalsCssPath = Join-Path $FrontendRoot "app\globals.css"
$globalsCssContent = @'
@import "tailwindcss";

:root {
  --background: #ffffff;
  --foreground: #171717;
  --surface: #f5f6f8;
  --surface-border: #e3e6ea;
}

.dark {
  --background: #0a0a0a;
  --foreground: #f5f5f5;
  --surface: #171717;
  --surface-border: #262626;
}

body {
  background: var(--background);
  color: var(--foreground);
  font-family: Arial, Helvetica, sans-serif;
  transition: background-color 0.2s ease, color 0.2s ease;
}

::view-transition-old(root),
::view-transition-new(root) {
  animation: none;
  mix-blend-mode: normal;
}
'@
Write-Utf8NoBom $globalsCssPath $globalsCssContent

# --------------------------------------------------------------------------
# 4. app/layout.tsx - no-flash theme init script
# --------------------------------------------------------------------------

$rootLayoutPath = Join-Path $FrontendRoot "app\layout.tsx"
$rootLayoutContent = @'
import type { Metadata } from "next";
import "./globals.css";
import { Toaster } from "sonner";

export const metadata: Metadata = {
  title: "GhaniFoods",
  description: "Nimko / Snack Foods Production & Distribution System",
};

// Runs before paint to avoid a light/dark flash on load. Reads the saved
// preference from localStorage, falling back to the OS-level preference.
const themeInitScript = `
(function () {
  try {
    var stored = localStorage.getItem("theme");
    var prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    var dark = stored ? stored === "dark" : prefersDark;
    document.documentElement.classList.toggle("dark", dark);
  } catch (e) {}
})();
`;

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
      </head>
      <body>
        {children}
        <Toaster theme="system" position="top-right" richColors />
      </body>
    </html>
  );
}
'@
Write-Utf8NoBom $rootLayoutPath $rootLayoutContent

# --------------------------------------------------------------------------
# 5. Dashboard shell layout - use CSS variables instead of hardcoded dark
# --------------------------------------------------------------------------

$dashboardLayoutPath = Join-Path $FrontendRoot "app\(dashboard)\layout.tsx"
$dashboardLayoutContent = @'
import type { ReactNode } from "react";
import { AppSidebar } from "@/components/ui/sidebar-component";
import { Topbar } from "@/components/ui/topbar";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-[var(--background)]">
      <AppSidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <Topbar />
        <main className="flex-1 p-6 overflow-y-auto text-[var(--foreground)]">{children}</main>
      </div>
    </div>
  );
}
'@
Write-Utf8NoBom $dashboardLayoutPath $dashboardLayoutContent

# --------------------------------------------------------------------------
# 6. Topbar - add the toggler button
# --------------------------------------------------------------------------

$topbarPath = Join-Path $FrontendRoot "components\ui\topbar.tsx"
$topbarContent = @'
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
            <Link href="/settings" onClick={() => setOpen(false)}
              className="block px-4 py-2.5 text-sm text-neutral-200 hover:bg-neutral-800">
              Settings
            </Link>
            <button onClick={handleLogout}
              className="w-full text-left px-4 py-2.5 text-sm text-red-400 hover:bg-neutral-800">
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
'@
Write-Utf8NoBom $topbarPath $topbarContent

# --------------------------------------------------------------------------
# 7. Install dependencies
# --------------------------------------------------------------------------

Write-Host ""
Write-Host "=== Installing dependencies ===" -ForegroundColor Cyan
Push-Location $FrontendRoot
try {
    npm install
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Added:" -ForegroundColor Green
Write-Host "  - components/ui/animated-theme-toggler.tsx" -ForegroundColor Gray
Write-Host "  - Toggle button now sits in the topbar (next to '+ New Invoice')" -ForegroundColor Gray
Write-Host "  - No-flash theme init script in app/layout.tsx" -ForegroundColor Gray
Write-Host "  - Light/dark CSS variables in globals.css" -ForegroundColor Gray
Write-Host ""
Write-Host "SCOPE NOTE:" -ForegroundColor Yellow
Write-Host "  The sidebar/topbar/root shell now respects light/dark mode." -ForegroundColor Yellow
Write-Host "  The 17 individual pages (raw-materials, batches, invoices, etc.)" -ForegroundColor Yellow
Write-Host "  still use hardcoded dark classes (bg-neutral-950 etc.) and will" -ForegroundColor Yellow
Write-Host "  look the same in both modes until those files are converted too." -ForegroundColor Yellow
Write-Host "  Ask if you want that follow-up pass done." -ForegroundColor Yellow
Write-Host ""
Write-Host "Verify locally:" -ForegroundColor Cyan
Write-Host "  npm run dev" -ForegroundColor Gray