# fix-theme-not-persisting.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-theme-not-persisting.ps1
#
# ROOT CAUSE (two combined issues):
#   1. React hydrates <html lang="en"> from app/layout.tsx. Without
#      suppressHydrationWarning, React can reconcile/repaint the <html>
#      element on hydration and wipe out the "dark" class that the
#      blocking inline script added BEFORE React loaded - so on reload,
#      dark mode "flashes" correctly for a split second then gets reset.
#   2. The toggle only wrote to localStorage - if that write ever raced
#      with a reload (or localStorage got cleared by browser privacy
#      settings), there was no fallback, so the site fell back to system
#      preference (usually light).
#
# FIX:
#   - Add suppressHydrationWarning to <html> so React never touches its
#     attributes after the init script sets them.
#   - Write theme to BOTH localStorage AND a cookie (1 year expiry) on
#     every toggle, and have the init script check localStorage first,
#     then fall back to the cookie, then system preference.
#   - Make the localStorage/cookie write happen synchronously and
#     immediately on click - not deferred behind the view-transition
#     animation promise.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Fixing theme not persisting across reload ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. app/layout.tsx - suppressHydrationWarning + cookie-aware init script
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

// Runs before paint to avoid a light/dark flash on load. Checks
// localStorage first, then a cookie fallback, then OS preference.
// This MUST run before React hydrates, and suppressHydrationWarning on
// <html> below stops React from reconciling away the class it sets.
const themeInitScript = `
(function () {
  try {
    function getCookie(name) {
      var match = document.cookie.match(new RegExp("(^| )" + name + "=([^;]+)"));
      return match ? match[2] : null;
    }
    var stored = localStorage.getItem("theme") || getCookie("theme");
    var prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    var dark = stored ? stored === "dark" : prefersDark;
    document.documentElement.classList.toggle("dark", dark);
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
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
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

# --------------------------------------------------------------------------
# 2. animated-theme-toggler.tsx - write to localStorage AND cookie,
#    immediately and synchronously (not deferred behind the transition).
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

function persistTheme(theme: "dark" | "light") {
  try {
    localStorage.setItem("theme", theme)
  } catch (e) {
    // localStorage may be unavailable (private mode, disabled) - cookie below still works
  }
  document.cookie = `theme=${theme}; path=/; max-age=31536000; SameSite=Lax`
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

    const toggled = !darkMode

    const applyToggle = () => {
      setDarkMode(toggled)
      document.documentElement.classList.toggle("dark", toggled)
    }

    // Persist FIRST, synchronously, before any animation/await - so a
    // reload at any point after this line always sees the new theme.
    persistTheme(toggled ? "dark" : "light")

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
        "flex items-center justify-center p-2 rounded-full outline-none focus:outline-none active:outline-none focus:ring-0 cursor-pointer hover:bg-[var(--surface-hover)] transition-colors",
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
            className="text-[var(--foreground)]"
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
            className="text-[var(--foreground)]"
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

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  <html> now has suppressHydrationWarning - React will no longer" -ForegroundColor Gray
Write-Host "    reconcile away the .dark class the init script sets" -ForegroundColor Gray
Write-Host "  Theme now persists to BOTH localStorage and a 1-year cookie" -ForegroundColor Gray
Write-Host "  Toggle writes the new theme IMMEDIATELY and synchronously," -ForegroundColor Gray
Write-Host "    before any animation - a reload right after clicking is safe" -ForegroundColor Gray
Write-Host "  Init script checks localStorage first, cookie as fallback" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT: restart the dev server:" -ForegroundColor Yellow
Write-Host "  Ctrl+C, then:" -ForegroundColor Yellow
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify: toggle to dark mode, hard refresh (Ctrl+Shift+R) - should stay dark." -ForegroundColor Cyan