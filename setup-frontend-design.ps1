# setup-frontend-design.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\setup-frontend-design.ps1

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FE = Join-Path $Root "apps\frontend"

function Write-FileNoBom {
    param([string]$RelPath, [string]$Content)
    $full = Join-Path $FE $RelPath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
    Write-Host "  + apps\frontend\$RelPath" -ForegroundColor DarkGray
}

if (-not (Test-Path $FE)) {
    Write-Host "ERROR: apps\frontend not found. Run this from the GhaniFoods root folder." -ForegroundColor Red
    exit 1
}

Write-Host "=== Setting up frontend design system (sidebar + auth) ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------
# 1. lib/utils.ts (shadcn cn helper)
# ---------------------------------------------------------------------
Write-Host "`n[1/8] lib/utils.ts" -ForegroundColor Yellow
$utils = @'
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
'@
Write-FileNoBom "lib\utils.ts" $utils

# ---------------------------------------------------------------------
# 2. components/ui/button.tsx
# ---------------------------------------------------------------------
Write-Host "`n[2/8] components/ui/button.tsx" -ForegroundColor Yellow
$button = @'
import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />
    );
  }
);
Button.displayName = "Button";

export { Button, buttonVariants };
'@
Write-FileNoBom "components\ui\button.tsx" $button

# ---------------------------------------------------------------------
# 3. components/ui/input.tsx
# ---------------------------------------------------------------------
Write-Host "`n[3/8] components/ui/input.tsx" -ForegroundColor Yellow
$input = @'
import * as React from "react";

import { cn } from "@/lib/utils";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          "flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
          className
        )}
        ref={ref}
        {...props}
      />
    );
  }
);
Input.displayName = "Input";

export { Input };
'@
Write-FileNoBom "components\ui\input.tsx" $input

# ---------------------------------------------------------------------
# 4. components/ui/sidebar-component.tsx (adapted for GhaniFoods nav)
# ---------------------------------------------------------------------
Write-Host "`n[4/8] components/ui/sidebar-component.tsx" -ForegroundColor Yellow
$sidebar = @'
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
'@
Write-FileNoBom "components\ui\sidebar-component.tsx" $sidebar

# ---------------------------------------------------------------------
# 5. components/ui/auth-page.tsx
# ---------------------------------------------------------------------
Write-Host "`n[5/8] components/ui/auth-page.tsx" -ForegroundColor Yellow
$auth = @'
"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import { AtSignIcon, LockIcon, Grid2x2PlusIcon } from "lucide-react";
import { Button } from "./button";
import { Input } from "./input";

export function AuthPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setError("Please enter both email and password.");
      return;
    }
    // Dummy auth: any non-empty credentials succeed
    setError("");
    router.push("/");
  };

  return (
    <main className="relative md:h-screen md:overflow-hidden lg:grid lg:grid-cols-2">
      <div className="bg-neutral-900 relative hidden h-full flex-col border-r border-neutral-800 p-10 lg:flex">
        <div className="z-10 flex items-center gap-2 text-neutral-50">
          <Grid2x2PlusIcon className="size-6" />
          <p className="text-xl font-semibold">GhaniFoods</p>
        </div>
        <div className="z-10 mt-auto">
          <blockquote className="space-y-2">
            <p className="text-xl text-neutral-100">
              Real-time visibility into raw materials, batches, and customer ledgers -
              all in one place.
            </p>
            <footer className="font-mono text-sm font-semibold text-neutral-400">
              ~ GhaniFoods Production Team
            </footer>
          </blockquote>
        </div>
      </div>

      <div className="relative flex min-h-screen flex-col justify-center p-4 bg-black">
        <div className="mx-auto w-full max-w-sm space-y-4">
          <div className="flex items-center gap-2 lg:hidden text-neutral-50">
            <Grid2x2PlusIcon className="size-6" />
            <p className="text-xl font-semibold">GhaniFoods</p>
          </div>

          <div className="flex flex-col space-y-1">
            <h1 className="text-2xl font-bold tracking-wide text-neutral-50">
              Sign in to GhaniFoods
            </h1>
            <p className="text-neutral-400 text-base">
              Enter your credentials to access the dashboard.
            </p>
          </div>

          <form className="space-y-3" onSubmit={handleSubmit}>
            <div className="relative h-max">
              <Input
                placeholder="you@ghanifoods.com"
                className="peer ps-9 bg-neutral-900 border-neutral-800 text-neutral-50 placeholder:text-neutral-500"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
              <div className="text-neutral-500 pointer-events-none absolute inset-y-0 start-0 flex items-center justify-center ps-3">
                <AtSignIcon className="size-4" aria-hidden="true" />
              </div>
            </div>

            <div className="relative h-max">
              <Input
                placeholder="Password"
                className="peer ps-9 bg-neutral-900 border-neutral-800 text-neutral-50 placeholder:text-neutral-500"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <div className="text-neutral-500 pointer-events-none absolute inset-y-0 start-0 flex items-center justify-center ps-3">
                <LockIcon className="size-4" aria-hidden="true" />
              </div>
            </div>

            {error && <p className="text-red-400 text-sm">{error}</p>}

            <Button type="submit" className="w-full" size="lg">
              Sign In
            </Button>
          </form>

          <p className="text-neutral-500 mt-8 text-sm">
            Demo build - any email/password combination signs you in.
          </p>
        </div>
      </div>
    </main>
  );
}

export default AuthPage;
'@
Write-FileNoBom "components\ui\auth-page.tsx" $auth

# ---------------------------------------------------------------------
# 6. app/(auth)/login/page.tsx
# ---------------------------------------------------------------------
Write-Host "`n[6/8] app/(auth)/login/page.tsx" -ForegroundColor Yellow
$loginPage = @'
import { AuthPage } from "@/components/ui/auth-page";

export default function LoginPage() {
  return <AuthPage />;
}
'@
Write-FileNoBom "app\(auth)\login\page.tsx" $loginPage

# ---------------------------------------------------------------------
# 7. app/(dashboard)/layout.tsx - wraps all dashboard pages with sidebar
# ---------------------------------------------------------------------
Write-Host "`n[7/8] app/(dashboard)/layout.tsx" -ForegroundColor Yellow
$dashboardLayout = @'
import type { ReactNode } from "react";
import { AppSidebar } from "@/components/ui/sidebar-component";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-neutral-950">
      <AppSidebar />
      <main className="flex-1 p-6 overflow-y-auto text-neutral-50">{children}</main>
    </div>
  );
}
'@
Write-FileNoBom "app\(dashboard)\layout.tsx" $dashboardLayout

# ---------------------------------------------------------------------
# 8. Dummy dashboard page using existing mock data (lib/mock-data/kpis.ts)
# ---------------------------------------------------------------------
Write-Host "`n[8/8] app/(dashboard)/page.tsx (KPI dashboard, dummy data)" -ForegroundColor Yellow
$dashboardPage = @'
import { kpis } from "@/lib/mock-data/kpis";

function KpiCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-4">
      <div className="text-neutral-400 text-sm">{label}</div>
      <div className="text-2xl font-semibold text-neutral-50 mt-1">{value}</div>
    </div>
  );
}

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">Dashboard</h1>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Total Raw Material Value" value={`Rs. ${kpis.totalRawMaterialValue.toLocaleString()}`} />
        <KpiCard label="Batches This Month" value={kpis.batchesThisMonth} />
        <KpiCard label="Finished Cartons Ready" value={kpis.finishedCartonsReady} />
        <KpiCard label="Total Receivables" value={`Rs. ${kpis.totalReceivables.toLocaleString()}`} />
      </div>
    </div>
  );
}
'@
Write-FileNoBom "app\(dashboard)\page.tsx" $dashboardPage

# ---------------------------------------------------------------------
# 9. lib/mock-data/kpis.ts (in case it does not already export `kpis`)
# ---------------------------------------------------------------------
$kpisPath = Join-Path $FE "lib\mock-data\kpis.ts"
if (-not (Test-Path $kpisPath)) {
    Write-Host "`n  lib/mock-data/kpis.ts missing - creating it" -ForegroundColor Yellow
    $kpis = @'
export const kpis = {
  totalRawMaterialValue: 128450,
  batchesThisMonth: 6,
  finishedCartonsReady: 127,
  totalReceivables: 15900,
};
'@
    Write-FileNoBom "lib\mock-data\kpis.ts" $kpis
}

# ---------------------------------------------------------------------
# 10. tailwind.config.ts + globals.css (only create if missing)
# ---------------------------------------------------------------------
$twConfigPath = Join-Path $FE "tailwind.config.ts"
if (-not (Test-Path $twConfigPath)) {
    Write-Host "`n  tailwind.config.ts missing - creating it" -ForegroundColor Yellow
    $twConfig = @'
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};

export default config;
'@
    Write-FileNoBom "tailwind.config.ts" $twConfig
}

$globalsCssPath = Join-Path $FE "app\globals.css"
if (-not (Test-Path $globalsCssPath)) {
    Write-Host "  app/globals.css missing - creating it" -ForegroundColor Yellow
    $globalsCss = @'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --background: 0 0% 100%;
  --foreground: 0 0% 4%;
  --primary: 0 0% 9%;
  --primary-foreground: 0 0% 98%;
  --border: 0 0% 89%;
  --input: 0 0% 89%;
  --ring: 0 0% 4%;
  --muted-foreground: 0 0% 45%;
  --accent: 0 0% 96%;
  --accent-foreground: 0 0% 9%;
  --secondary: 0 0% 96%;
  --secondary-foreground: 0 0% 9%;
  --destructive: 0 84% 60%;
  --destructive-foreground: 0 0% 98%;
}

body {
  background-color: #0a0a0a;
}
'@
    Write-FileNoBom "app\globals.css" $globalsCss
}

# ---------------------------------------------------------------------
# 11. Patch package.json to add required dependencies
# ---------------------------------------------------------------------
Write-Host "`n=== Patching package.json dependencies ===" -ForegroundColor Cyan
$pkgPath = Join-Path $FE "package.json"
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json

$depsToAdd = @{
    "tailwindcss"             = "^4.0.0"
    "postcss"                 = "^8.4.47"
    "autoprefixer"            = "^10.4.20"
    "clsx"                    = "^2.1.1"
    "tailwind-merge"          = "^2.5.4"
    "class-variance-authority"= "^0.7.1"
    "@radix-ui/react-slot"    = "^1.1.0"
    "lucide-react"            = "^0.460.0"
    "framer-motion"           = "^11.11.17"
    "@carbon/icons-react"     = "^11.53.0"
}

foreach ($dep in $depsToAdd.Keys) {
    if (-not $pkg.dependencies.$dep) {
        $pkg.dependencies | Add-Member -NotePropertyName $dep -NotePropertyValue $depsToAdd[$dep] -Force
        Write-Host "  + $dep" -ForegroundColor Green
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$jsonOut = $pkg | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($pkgPath, $jsonOut, $utf8NoBom)
Write-Host "  package.json updated (UTF-8, no BOM)." -ForegroundColor Green

# ---------------------------------------------------------------------
# 12. Reinstall
# ---------------------------------------------------------------------
Write-Host "`n=== Installing dependencies ===" -ForegroundColor Cyan
Push-Location $FE
npm install
Pop-Location

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host "  2. Visit http://localhost:3000/login and http://localhost:3000/" -ForegroundColor Gray
Write-Host "  3. If it looks good, commit and push:" -ForegroundColor Gray
Write-Host "       git add ." -ForegroundColor Gray
Write-Host "       git commit -m `"feat: add sidebar layout + login page with dummy data`"" -ForegroundColor Gray
Write-Host "       git push" -ForegroundColor Gray