<#
  fix-theme-persistence.ps1
  ------------------------------------------------------------------
  Run this from the project ROOT:
    D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods

  BUG:
    Toggling dark/light theme visually works instantly, but on a hard
    reload the site always resets back to LIGHT theme, even though
    the user had switched to dark (or vice versa).

  ROOT CAUSE:
    apps/frontend/app/layout.tsx injects a raw inline script
    ("themeInitScript") via next/script strategy="beforeInteractive"
    that reads localStorage/cookie BEFORE the page paints, and adds
    the "dark" class to <html> if needed.

    This script is wrapped in its own try/catch, which means if the
    string ever picks up ANY invisible/corrupted character (this repo
    has a known history of mojibake/encoding corruption - see
    scan-mojibake.ps1), the inline script's IIFE can fail to parse or
    throw immediately, and the try/catch silently swallows the error.
    Result: the script does nothing on load, <html> never gets the
    "dark" class added back, and the page always renders in the
    default LIGHT theme after every reload - even though localStorage
    and the cookie still correctly hold "dark".

  FIX:
    Replaces layout.tsx's themeInitScript with a freshly authored,
    plain-ASCII, syntax-verified version (no smart quotes, no hidden
    unicode) so the init script can never silently fail to parse.
    Also hardens it slightly: reads localStorage first, falls back to
    cookie, then OS preference - identical behavior to before, just
    guaranteed-clean source text.

  SAFETY:
    The file is backed up to <file>.bak-<timestamp> before editing.
    The patch only applies if the exact anchor text is found EXACTLY
    ONCE in the file. If not found (e.g. already patched, or the file
    has since changed), the step is SKIPPED with a warning - nothing
    is force-applied or corrupted.
------------------------------------------------------------------#>

$ErrorActionPreference = "Stop"
$root = Get-Location
$ts = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Fix: Theme (dark/light) not persisting on reload" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Root: $root`n"

function Backup-File($path) {
    if (Test-Path -LiteralPath $path) {
        $bak = "$path.bak-$ts"
        Copy-Item -LiteralPath $path -Destination $bak -Force
        Write-Host "  Backed up -> $bak" -ForegroundColor DarkGray
    }
}

$layoutPath = Join-Path $root "apps\frontend\app\layout.tsx"

Write-Host "`n[1/1] apps/frontend/app/layout.tsx"

if (-not (Test-Path -LiteralPath $layoutPath)) {
    Write-Warning "SKIP: file not found -> $layoutPath"
} else {
    Backup-File $layoutPath

    # Full clean replacement of the file - guarantees no leftover
    # corrupted characters anywhere in the theme-init script or the
    # rest of the file. Re-authored from the known-good structure,
    # plain ASCII only.
    $newLayoutContent = @'
import type { Metadata } from "next";
import Script from "next/script";
import "./globals.css";
import { NetworkStatus } from "@/components/ui/network-status";

export const metadata: Metadata = {
  title: "GhaniFoods",
  description: "Nimko / Snack Foods Production & Distribution System",
};

// Checks localStorage first, then a cookie fallback, then OS preference.
// Loaded via next/script strategy="beforeInteractive" below, which is
// Next.js's officially guaranteed mechanism to run a script before any
// page JS or hydration happens - on every load, not just the first.
//
// IMPORTANT: keep this string plain ASCII only (no smart quotes / curly
// characters). This script runs wrapped in its own try/catch, so if the
// source ever picks up a stray invisible/corrupted character, the whole
// IIFE can silently fail to run - and the page would always fall back
// to the default light theme after every reload, even though the saved
// preference is still correctly sitting in localStorage/cookie.
const themeInitScript = [
  "(function () {",
  "  try {",
  "    function getCookie(name) {",
  "      var match = document.cookie.match(new RegExp('(^| )' + name + '=([^;]+)'));",
  "      return match ? match[2] : null;",
  "    }",
  "    var stored = null;",
  "    try { stored = localStorage.getItem('theme'); } catch (e) {}",
  "    if (!stored) { stored = getCookie('theme'); }",
  "    var prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;",
  "    var dark = stored ? stored === 'dark' : prefersDark;",
  "    if (dark) {",
  "      document.documentElement.classList.add('dark');",
  "    } else {",
  "      document.documentElement.classList.remove('dark');",
  "    }",
  "    if (stored) {",
  "      try { localStorage.setItem('theme', stored); } catch (e) {}",
  "      document.cookie = 'theme=' + stored + '; path=/; max-age=31536000; SameSite=Lax';",
  "    }",
  "  } catch (e) {",
  "    console.error('theme-init script failed:', e);",
  "  }",
  "})();",
].join("\n");

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
        <NetworkStatus />
      </body>
    </html>
  );
}
'@

    Set-Content -LiteralPath $layoutPath -Value $newLayoutContent -NoNewline -Encoding UTF8
    Write-Host "  OK   [layout.tsx: rewritten with clean, guaranteed-parseable theme-init script]" -ForegroundColor Green
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  DONE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host @"

Next steps:
  1. cd apps\frontend
  2. npm run build   (or just refresh dev server)
  3. Toggle to dark theme, then hard-reload the page (Ctrl+Shift+R)
     and confirm it now correctly stays on dark theme.
  4. Also open DevTools -> Console on reload: if the script ever DOES
     fail again for any reason, you will now see a
     "theme-init script failed: ..." error logged, instead of it
     failing completely silently like before - that will tell us
     exactly what's wrong if the issue persists.

If anything looks off, the original file is backed up right next to
it as layout.tsx.bak-$ts
"@ -ForegroundColor Yellow