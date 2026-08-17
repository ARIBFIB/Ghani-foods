# fix-light-dark-theme.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-light-dark-theme.ps1
#
# What this does:
#   1. Expands globals.css with a full light/dark CSS-variable palette
#      (surface, surface-hover, borders, secondary/muted/faint text)
#   2. Rewrites sidebar + topbar to use those variables instead of
#      hardcoded bg-black / bg-neutral-900 / text-neutral-50 etc.
#   3. Sweeps every page + dialog under app/(dashboard) and components/ui
#      and replaces hardcoded neutral-* classes with the same CSS vars,
#      so cards, tables, dialogs, forms all respond to the toggle.
#   4. Adds the AnimatedThemeToggler button to the LOGIN page too.
#   5. Fixes toasts (sonner) so they follow the manual .dark toggle
#      instead of theme="system" (OS preference).
#
# KNOWN LIMITATION (left as-is, cosmetic only):
#   Status badges (Paid/Unpaid/Partial, Low Stock, etc.) keep their
#   existing bg-red-950/text-red-400 style "dark chip" look in both
#   themes. They still read fine on light backgrounds; ask if you want
#   those converted to full light/dark pill colors too.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Fixing light/dark theme coverage ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. globals.css - full light/dark variable palette
# --------------------------------------------------------------------------

$globalsCssPath = Join-Path $FrontendRoot "app\globals.css"
$globalsCssContent = @'
@import "tailwindcss";

:root {
  --background: #ffffff;
  --foreground: #171717;
  --surface: #f5f6f8;
  --surface-hover: #ebedf0;
  --surface-border: #e3e6ea;
  --surface-border-strong: #c7cbd1;
  --text-secondary: #4b5563;
  --text-muted: #6b7280;
  --text-faint: #9ca3af;
}

.dark {
  --background: #0a0a0a;
  --foreground: #f5f5f5;
  --surface: #171717;
  --surface-hover: #262626;
  --surface-border: #262626;
  --surface-border-strong: #404040;
  --text-secondary: #d4d4d4;
  --text-muted: #a3a3a3;
  --text-faint: #737373;
}

body {
  background: var(--background);
  color: var(--foreground);
  font-family: Arial, Helvetica, sans-serif;
  transition: background-color 0.2s ease, color 0.2s ease, border-color 0.2s ease;
}

::view-transition-old(root),
::view-transition-new(root) {
  animation: none;
  mix-blend-mode: normal;
}
'@
Write-Utf8NoBom $globalsCssPath $globalsCssContent

# --------------------------------------------------------------------------
# 2. theme-aware Toaster wrapper (replaces theme="system")
# --------------------------------------------------------------------------

$themeToasterPath = Join-Path $FrontendRoot "components\ui\theme-toaster.tsx"
$themeToasterContent = @'
"use client";

import { useEffect, useState } from "react";
import { Toaster } from "sonner";

export function ThemeToaster() {
  const [theme, setTheme] = useState<"light" | "dark">("dark");

  useEffect(() => {
    const sync = () =>
      setTheme(document.documentElement.classList.contains("dark") ? "dark" : "light");
    sync();
    const observer = new MutationObserver(sync);
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
    return () => observer.disconnect();
  }, []);

  return <Toaster theme={theme} position="top-right" richColors />;
}

export default ThemeToaster;
'@
Write-Utf8NoBom $themeToasterPath $themeToasterContent

# --------------------------------------------------------------------------
# 3. app/layout.tsx - use ThemeToaster instead of Toaster theme="system"
# --------------------------------------------------------------------------

$rootLayoutPath = Join-Path $FrontendRoot "app\layout.tsx"
$rootLayoutContent = @'
import type { Metadata } from "next";
import "./globals.css";
import { ThemeToaster } from "@/components/ui/theme-toaster";

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
        <ThemeToaster />
      </body>
    </html>
  );
}
'@
Write-Utf8NoBom $rootLayoutPath $rootLayoutContent

# --------------------------------------------------------------------------
# 4. Login page - add the toggle button + switch to CSS variables
# --------------------------------------------------------------------------

$loginPagePath = Join-Path $FrontendRoot "app\(auth)\login\page.tsx"
$loginPageContent = @'
"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { AtSignIcon, LockIcon, Grid2x2PlusIcon } from "lucide-react";
import { AnimatedThemeToggler } from "@/components/ui/animated-theme-toggler";

const LOGIN_IMAGE_URL = "https://res.cloudinary.com/dr9dwesyo/image/upload/v1787001758/ghanifoods/ghani-nimko-bag.png";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password.trim()) {
      setError("Please enter both email and password.");
      return;
    }
    setLoading(true);
    setError("");
    document.cookie = "ghanifoods-auth=1; path=/; max-age=86400";
    router.push("/");
  };

  return (
    <main className="relative md:h-screen md:overflow-hidden lg:grid lg:grid-cols-2 bg-[var(--background)]">
      <div className="absolute top-4 right-4 z-20">
        <AnimatedThemeToggler className="border border-[var(--surface-border)] bg-[var(--surface)]" />
      </div>

      <div className="bg-[var(--surface)] relative hidden h-full flex-col border-r border-[var(--surface-border)] lg:flex overflow-hidden">
        <Image
          src={LOGIN_IMAGE_URL}
          alt="Ghani Food - Nimko"
          fill
          priority
          sizes="50vw"
          className="object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-black/40" />

        <div className="relative z-10 flex items-center gap-2 text-neutral-50 p-10">
          <Grid2x2PlusIcon className="size-6" />
          <p className="text-xl font-semibold">GhaniFoods</p>
        </div>

        <div className="relative z-10 mt-auto p-10">
          <blockquote className="space-y-2">
            <p className="text-xl text-neutral-100">
              Real-time visibility into raw materials, batches, and customer
              ledgers - all in one place.
            </p>
            <footer className="font-mono text-sm font-semibold text-neutral-300">
              ~ GhaniFoods Production Team
            </footer>
          </blockquote>
        </div>
      </div>

      <div className="relative flex min-h-screen flex-col justify-center p-4 bg-[var(--background)]">
        <div className="mx-auto w-full max-w-sm space-y-4">
          <div className="flex items-center gap-2 lg:hidden text-[var(--foreground)]">
            <Grid2x2PlusIcon className="size-6" />
            <p className="text-xl font-semibold">GhaniFoods</p>
          </div>

          <div className="flex flex-col space-y-1">
            <h1 className="text-2xl font-bold tracking-wide text-[var(--foreground)]">Sign in to GhaniFoods</h1>
            <p className="text-[var(--text-muted)] text-base">Enter your credentials to access the dashboard.</p>
          </div>

          <form className="space-y-3" onSubmit={handleSubmit}>
            <div className="relative">
              <input
                type="email"
                placeholder="you@ghanifoods.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full h-10 rounded-md border border-[var(--surface-border)] bg-[var(--surface)] ps-9 px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
              />
              <AtSignIcon className="absolute left-3 top-3 size-4 text-[var(--text-faint)] pointer-events-none" />
            </div>

            <div className="relative">
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full h-10 rounded-md border border-[var(--surface-border)] bg-[var(--surface)] ps-9 px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
              />
              <LockIcon className="absolute left-3 top-3 size-4 text-[var(--text-faint)] pointer-events-none" />
            </div>

            {error && <p className="text-red-500 text-sm">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="w-full h-11 rounded-md bg-neutral-900 dark:bg-neutral-50 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 disabled:opacity-50"
            >
              {loading ? "Signing in..." : "Sign In"}
            </button>
          </form>

          <p className="text-[var(--text-faint)] mt-8 text-sm">
            Demo build - any email / password combination signs you in.
          </p>
        </div>
      </div>
    </main>
  );
}
'@
Write-Utf8NoBom $loginPagePath $loginPageContent

# --------------------------------------------------------------------------
# 5. Sidebar + Topbar - regex swap of hardcoded classes -> CSS variables
# --------------------------------------------------------------------------

function Convert-ToThemeVars([string]$Text) {
    $t = $Text
    $t = [Regex]::Replace($t, 'bg-black(?!/)', 'bg-[var(--background)]')
    $t = $t -replace 'bg-neutral-950', 'bg-[var(--background)]'
    $t = $t -replace 'bg-neutral-900', 'bg-[var(--surface)]'
    $t = $t -replace 'bg-neutral-800', 'bg-[var(--surface-hover)]'
    $t = $t -replace 'divide-neutral-900', 'divide-[var(--surface-border)]'
    $t = $t -replace 'border-neutral-900', 'border-[var(--surface-border)]'
    $t = $t -replace 'border-neutral-800', 'border-[var(--surface-border)]'
    $t = $t -replace 'border-neutral-700', 'border-[var(--surface-border-strong)]'
    $t = $t -replace 'border-neutral-600', 'border-[var(--surface-border-strong)]'
    $t = $t -replace 'text-neutral-50', 'text-[var(--foreground)]'
    $t = $t -replace 'text-neutral-100', 'text-[var(--foreground)]'
    $t = $t -replace 'text-neutral-200', 'text-[var(--foreground)]'
    $t = $t -replace 'text-neutral-300', 'text-[var(--text-secondary)]'
    $t = $t -replace 'text-neutral-400', 'text-[var(--text-muted)]'
    $t = $t -replace 'text-neutral-500', 'text-[var(--text-faint)]'
    $t = $t -replace 'text-neutral-600', 'text-[var(--text-faint)]'
    return $t
}

$targetedFiles = @(
    (Join-Path $FrontendRoot "components\ui\sidebar-component.tsx"),
    (Join-Path $FrontendRoot "components\ui\topbar.tsx")
)

foreach ($file in $targetedFiles) {
    if (-not (Test-Path $file)) { continue }
    $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
    $converted = Convert-ToThemeVars $content
    Write-Utf8NoBom $file $converted
}

# --------------------------------------------------------------------------
# 6. Sweep every dashboard page + remaining ui components
# --------------------------------------------------------------------------

$dashboardAppRoot = Join-Path $FrontendRoot "app\(dashboard)"
$uiComponentsRoot = Join-Path $FrontendRoot "components\ui"

$excludeNames = @(
    "sidebar-component.tsx",
    "topbar.tsx",
    "animated-theme-toggler.tsx",
    "theme-toaster.tsx",
    "button.tsx",
    "input.tsx"
)

$sweepFiles = @()
if (Test-Path $dashboardAppRoot) {
    $sweepFiles += Get-ChildItem -Path $dashboardAppRoot -Recurse -Filter *.tsx -File
}
if (Test-Path $uiComponentsRoot) {
    $sweepFiles += Get-ChildItem -Path $uiComponentsRoot -Recurse -Filter *.tsx -File |
        Where-Object { $excludeNames -notcontains $_.Name }
}

$sweepCount = 0
foreach ($file in $sweepFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $converted = Convert-ToThemeVars $content
    if ($converted -ne $content) {
        Write-Utf8NoBom $file.FullName $converted
        $sweepCount++
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  globals.css expanded with full light/dark palette" -ForegroundColor Gray
Write-Host "  Login page now has the toggle button (top-right corner)" -ForegroundColor Gray
Write-Host "  Toasts now follow the manual toggle, not OS theme" -ForegroundColor Gray
Write-Host "  Sidebar + Topbar converted to theme variables" -ForegroundColor Gray
Write-Host "  $sweepCount additional page/dialog files converted" -ForegroundColor Gray
Write-Host ""
Write-Host "KNOWN LIMITATION:" -ForegroundColor Yellow
Write-Host "  Status badges (Paid/Unpaid/Low Stock etc.) keep their dark-chip" -ForegroundColor Yellow
Write-Host "  look in both themes - still legible, cosmetic only. Ask if you" -ForegroundColor Yellow
Write-Host "  want those converted too." -ForegroundColor Yellow
Write-Host ""
Write-Host "Verify locally:" -ForegroundColor Cyan
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host "Then toggle light/dark on the login page AND inside the dashboard." -ForegroundColor Gray