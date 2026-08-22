import type { Metadata } from "next";
import Script from "next/script";
import "./globals.css";
import { NetworkStatus } from "@/components/ui/network-status";
import { Analytics } from "@vercel/analytics/next";

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
  "    try { stored = localStorage.getItem('theme'); } catch (e) { console.warn('theme-init: could not read localStorage', e); }",
  "    if (!stored) { stored = getCookie('theme'); }",
  "    var prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;",
  "    var dark = stored ? stored === 'dark' : prefersDark;",
  "    if (dark) {",
  "      document.documentElement.classList.add('dark');",
  "    } else {",
  "      document.documentElement.classList.remove('dark');",
  "    }",
  "    if (stored) {",
  "      try { localStorage.setItem('theme', stored); } catch (e) { console.warn('theme-init: could not write localStorage', e); }",
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
        <Analytics />
      </body>
    </html>
  );
}