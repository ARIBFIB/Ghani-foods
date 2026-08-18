# apply-quick-nav.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\apply-quick-nav.ps1
#
# Implements "instant navigation, loader-only-if-actually-slow" behavior:
#   1. Rewrites lib/navigation-loading-context.tsx with a delay-threshold
#      model (no forced minimum visible time - loader only appears if the
#      route takes longer than ~150ms to resolve).
#   2. Adds a shared NavLink component (components/ui/nav-link.tsx) that
#      wraps next/link but routes clicks through the same navigate() logic
#      used by the sidebar, so ALL links get the same fast/slow behavior.
#   3. Sweeps every .tsx file under app/ and components/ and:
#        - swaps `import Link from "next/link"` -> NavLink import
#        - swaps <Link ...> / </Link> -> <NavLink ...> / </NavLink>
#        - swaps router.push(...) -> navigate(...) for files that
#          programmatically navigate (adds the hook import/usage if needed)
#
# Safe to re-run - skips files already migrated.

$ProjectRoot = Get-Location
$FrontendRoot = Join-Path $ProjectRoot "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: Could not find apps\frontend under $(Get-Location)" -ForegroundColor Red
    Write-Host "Make sure you run this script from the GhaniFoods project root." -ForegroundColor Yellow
    exit 1
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Read-FileSmart($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -eq 0) { return "" }
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true)
    $text = $reader.ReadToEnd()
    $reader.Close()
    return ($text -replace "`0", "")
}

Write-Host "=== Applying quick-navigation changes ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Rewrite navigation-loading-context.tsx (delay-threshold, no min-visible)
# ---------------------------------------------------------------------------
$navContextPath = Join-Path $FrontendRoot "lib\navigation-loading-context.tsx"
$navContextContent = @'
"use client";

import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  useTransition,
  type ReactNode,
} from "react";
import { useRouter } from "next/navigation";

type NavigationLoadingContextValue = {
  isLoading: boolean;
  navigate: (href: string) => void;
};

// If the route resolves before this much time has passed, the loader never
// appears at all - navigation just feels instant. If it takes longer than
// this, the loader is shown immediately and stays up until the transition
// actually finishes (no artificial minimum visible time).
const SHOW_LOADER_AFTER_MS = 150;

const NavigationLoadingContext = createContext<NavigationLoadingContextValue | null>(null);

export function NavigationLoadingProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [showLoader, setShowLoader] = useState(false);
  const showTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const navigate = (href: string) => {
    if (showTimerRef.current) clearTimeout(showTimerRef.current);

    // Don't show anything yet - only arm a timer. If the transition below
    // finishes before this fires, the timer gets cleared and the user never
    // sees a loader at all (this is the common case for prefetched routes).
    showTimerRef.current = setTimeout(() => {
      setShowLoader(true);
    }, SHOW_LOADER_AFTER_MS);

    startTransition(() => {
      router.push(href);
    });
  };

  // As soon as the transition settles, cancel any pending "show loader"
  // timer and hide the loader immediately - no minimum visible duration.
  useEffect(() => {
    if (!isPending) {
      if (showTimerRef.current) {
        clearTimeout(showTimerRef.current);
        showTimerRef.current = null;
      }
      setShowLoader(false);
    }
  }, [isPending]);

  useEffect(() => {
    return () => {
      if (showTimerRef.current) clearTimeout(showTimerRef.current);
    };
  }, []);

  const isLoading = isPending && showLoader;

  return (
    <NavigationLoadingContext.Provider value={{ isLoading, navigate }}>
      {children}
    </NavigationLoadingContext.Provider>
  );
}

export function useNavigationLoading() {
  const ctx = useContext(NavigationLoadingContext);
  if (!ctx) throw new Error("useNavigationLoading must be used within NavigationLoadingProvider");
  return ctx;
}
'@
Write-Utf8NoBom $navContextPath $navContextContent
Write-Host "  Updated: lib\navigation-loading-context.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. New shared NavLink component
# ---------------------------------------------------------------------------
$navLinkPath = Join-Path $FrontendRoot "components\ui\nav-link.tsx"
$navLinkContent = @'
"use client";

import NextLink, { type LinkProps } from "next/link";
import { forwardRef, type AnchorHTMLAttributes } from "react";
import { useNavigationLoading } from "@/lib/navigation-loading-context";

type NavLinkProps = LinkProps &
  Omit<AnchorHTMLAttributes<HTMLAnchorElement>, keyof LinkProps | "href"> & {
    children?: React.ReactNode;
  };

// Drop-in replacement for next/link. Keeps Next's built-in prefetching
// (hover/viewport) so most routes are already warm by the time they're
// clicked, but routes the actual click through the shared navigate()
// context so every link in the app gets the same instant-nav /
// only-show-loader-if-actually-slow behavior as the sidebar.
export const NavLink = forwardRef<HTMLAnchorElement, NavLinkProps>(
  ({ href, onClick, children, ...rest }, ref) => {
    const { navigate } = useNavigationLoading();

    const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
      onClick?.(e);
      if (e.defaultPrevented) return;
      // Let modified clicks (new tab, etc.) behave natively.
      if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;
      e.preventDefault();
      navigate(typeof href === "string" ? href : href.toString());
    };

    return (
      <NextLink ref={ref} href={href} onClick={handleClick} {...rest}>
        {children}
      </NextLink>
    );
  }
);
NavLink.displayName = "NavLink";

export default NavLink;
'@
Write-Utf8NoBom $navLinkPath $navLinkContent
Write-Host "  Created: components\ui\nav-link.tsx" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. Sweep app/ and components/ .tsx files
# ---------------------------------------------------------------------------
$targets = @(
    (Join-Path $FrontendRoot "app"),
    (Join-Path $FrontendRoot "components")
) | Where-Object { Test-Path $_ }

$files = Get-ChildItem -Path $targets -Recurse -Filter "*.tsx" -File |
    Where-Object { $_.FullName -ne $navLinkPath }

$changedCount = 0

foreach ($file in $files) {
    $original = Read-FileSmart $file.FullName
    $content = $original
    $touched = $false

    # --- Swap next/link default import for NavLink -------------------------
    if ($content -match 'import\s+Link\s+from\s+["'']next/link["''];?') {
        $content = [regex]::Replace(
            $content,
            'import\s+Link\s+from\s+["'']next/link["''];?',
            'import { NavLink } from "@/components/ui/nav-link";'
        )
        $touched = $true
    }

    # --- Swap JSX <Link ...> / </Link> for <NavLink ...> / </NavLink> -----
    if ($content -match '<Link\b' -or $content -match '</Link>') {
        $content = [regex]::Replace($content, '<Link\b', '<NavLink')
        $content = [regex]::Replace($content, '</Link>', '</NavLink>')
        $touched = $true
    }

    # --- Swap programmatic router.push(...) for navigate(...) -------------
    if ($content -match 'router\.push\(' -and $content -notmatch 'useNavigationLoading') {
        $hasUseRouter = $content -match 'from\s+["'']next/navigation["'']'
        if ($hasUseRouter) {
            # add the hook import right after the next/navigation import line
            $content = [regex]::Replace(
                $content,
                '(import\s+\{[^}]*\}\s+from\s+["'']next/navigation["''];?\r?\n)',
                "`$1import { useNavigationLoading } from `"@/lib/navigation-loading-context`";`n",
                1
            )
        } else {
            # fallback: add import near the top, after the "use client" line
            $content = [regex]::Replace(
                $content,
                '("use client";\r?\n)',
                "`$1import { useNavigationLoading } from `"@/lib/navigation-loading-context`";`n",
                1
            )
        }

        # add the hook call right after the useRouter() assignment
        if ($content -match 'const\s+router\s*=\s*useRouter\(\);?') {
            $content = [regex]::Replace(
                $content,
                '(const\s+router\s*=\s*useRouter\(\);?\r?\n)',
                "`$1  const { navigate } = useNavigationLoading();`n",
                1
            )
        }

        $content = [regex]::Replace($content, 'router\.push\(', 'navigate(')
        $touched = $true
    }

    if ($touched -and $content -ne $original) {
        Write-Utf8NoBom $file.FullName $content
        $changedCount++
        $rel = $file.FullName.Substring($FrontendRoot.Length).TrimStart('\')
        Write-Host "  Migrated: $rel" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Files migrated: $changedCount" -ForegroundColor Green
Write-Host ""
Write-Host "Please review with 'git diff' - check that:" -ForegroundColor Yellow
Write-Host "  - Any files using both router.push() and router.back()/router.replace() still work correctly" -ForegroundColor Yellow
Write-Host "  - No duplicate 'const { navigate }' lines were introduced in files that already had one" -ForegroundColor Yellow
Write-Host "Then test locally (npm run dev:frontend), and commit + redeploy to Vercel." -ForegroundColor Yellow