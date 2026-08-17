# fix-theme-reset-on-reload.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-theme-reset-on-reload.ps1
#
# ROOT CAUSE:
#   A raw <script dangerouslySetInnerHTML> inside a manually-written <head>
#   in App Router is NOT guaranteed by Next.js to execute before React
#   hydrates/streams the page - especially in dev mode with Fast Refresh,
#   or on slower connections. If it runs even slightly late, React's
#   hydration can already have painted the default (light) state, and by
#   the time the script sets .dark, the visual flash reads as "reset to
#   light on reload" even though the class does get set.
#
# FIX:
#   Replace the manual <script> tag with Next.js's own <Script> component
#   using strategy="beforeInteractive" - this is the officially guaranteed
#   way in Next.js App Router to run a script before ANY page JS/hydration,
#   including on every full reload. Also hardens the read/write logic.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Fixing theme reset on reload (using next/script beforeInteractive) ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

$rootLayoutPath = Join-Path $FrontendRoot "app\layout.tsx"
$rootLayoutContent = @'
import type { Metadata } from "next";
import Script from "next/script";
import "./globals.css";
import { ThemeToaster } from "@/components/ui/theme-toaster";

export const metadata: Metadata = {
  title: "GhaniFoods",
  description: "Nimko / Snack Foods Production & Distribution System",
};

// Checks localStorage first, then a cookie fallback, then OS preference.
// Loaded via next/script strategy="beforeInteractive" below, which is
// Next.js's officially guaranteed mechanism to run a script before any
// page JS or hydration happens - on every load, not just the first.
const themeInitScript = `
(function () {
  try {
    function getCookie(name) {
      var match = document.cookie.match(new RegExp("(^| )" + name + "=([^;]+)"));
      return match ? match[2] : null;
    }
    var stored = null;
    try { stored = localStorage.getItem("theme"); } catch (e) {}
    if (!stored) { stored = getCookie("theme"); }
    var prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    var dark = stored ? stored === "dark" : prefersDark;
    if (dark) {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
    if (stored) {
      try { localStorage.setItem("theme", stored); } catch (e) {}
      document.cookie = "theme=" + stored + "; path=/; max-age=31536000; SameSite=Lax";
    }
  } catch (e) {}
})();
`;

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <Script
          id="theme-init"
          strategy="beforeInteractive"
          dangerouslySetInnerHTML={{ __html: themeInitScript }}
        />
      </head>
      <body suppressHydrationWarning>
        {children}
        <ThemeToaster />
      </body>
    </html>
  );
}
'@
Write-Utf8NoBom $rootLayoutPath $rootLayoutContent

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  Theme init script now uses next/script strategy='beforeInteractive'" -ForegroundColor Gray
Write-Host "    This is Next.js's guaranteed pre-hydration execution mechanism -" -ForegroundColor Gray
Write-Host "    much more reliable than a raw <script> tag in a manual <head>." -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT: restart the dev server (required for next/script changes):" -ForegroundColor Yellow
Write-Host "  Ctrl+C, then:" -ForegroundColor Yellow
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host ""
Write-Host "Then in the browser:" -ForegroundColor Cyan
Write-Host "  1. Hard refresh once first (Ctrl+Shift+R) to clear any stale state" -ForegroundColor Gray
Write-Host "  2. Toggle to dark mode" -ForegroundColor Gray
Write-Host "  3. Normal refresh (F5) - should stay dark" -ForegroundColor Gray
Write-Host "  4. Toggle to light mode, refresh again - should stay light" -ForegroundColor Gray