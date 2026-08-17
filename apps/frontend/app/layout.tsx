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