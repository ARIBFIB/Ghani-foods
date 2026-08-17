# add-loading-and-404-animations.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\add-loading-and-404-animations.ps1
#
# What this does:
#   1. Adds "lottie-react" dependency (renders .json Lottie files - the
#      format your loading.json and 404errorpagewithcat.json are in).
#   2. Creates a reusable <LottieLoader /> component with a skeleton/
#      shimmer fallback shown while the Lottie JSON itself is loading.
#   3. Adds app/(dashboard)/loading.tsx - Next.js App Router automatically
#      shows this during route transitions/data loading across ALL
#      dashboard pages, using loading.json + a shimmer skeleton grid.
#   4. Adds app/not-found.tsx - shown on any unmatched route (404),
#      using 404errorpagewithcat.json, with a "Back to Dashboard" button.
#   5. Adds a <NetworkStatus /> component + wires it into the root layout
#      so that if the browser goes offline, the same cat animation shows
#      as a full-screen "No internet connection" overlay until it's back.
#
# NOTE: this assumes the two files already exist at:
#   apps\frontend\public\loading\loading.json
#   apps\frontend\public\loading\404errorpagewithcat.json
# (as you specified) - the script does not create/move those files.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

$loadingJsonPath = Join-Path $FrontendRoot "public\loading\loading.json"
$catJsonPath = Join-Path $FrontendRoot "public\loading\404errorpagewithcat.json"

if (-not (Test-Path $loadingJsonPath)) {
    Write-Host "WARNING: $loadingJsonPath not found. The component will still be created," -ForegroundColor Yellow
    Write-Host "         but will show a broken animation until you add that file." -ForegroundColor Yellow
}
if (-not (Test-Path $catJsonPath)) {
    Write-Host "WARNING: $catJsonPath not found. The component will still be created," -ForegroundColor Yellow
    Write-Host "         but will show a broken animation until you add that file." -ForegroundColor Yellow
}

Write-Host "=== Adding Lottie loading + 404 + offline animations ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. package.json - add lottie-react
# --------------------------------------------------------------------------

$pkgPath = Join-Path $FrontendRoot "package.json"
$text = [System.IO.File]::ReadAllText($pkgPath, [System.Text.Encoding]::UTF8)
$pkgJson = $text | ConvertFrom-Json

if (-not ($pkgJson.dependencies.PSObject.Properties.Name -contains "lottie-react")) {
    $pkgJson.dependencies | Add-Member -MemberType NoteProperty -Name "lottie-react" -Value "^2.4.1"
    Write-Host "  Added dependency: lottie-react" -ForegroundColor Green
} else {
    Write-Host "  lottie-react already present" -ForegroundColor Gray
}

$outText = $pkgJson | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pkgPath, $outText, $utf8NoBom)
Write-Host "  Updated: apps\frontend\package.json" -ForegroundColor Green

# --------------------------------------------------------------------------
# 2. components/ui/lottie-loader.tsx - reusable Lottie + shimmer fallback
# --------------------------------------------------------------------------

$lottieLoaderPath = Join-Path $FrontendRoot "components\ui\lottie-loader.tsx"
$lottieLoaderContent = @'
"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

type LottieLoaderProps = {
  src: string;
  size?: number;
  className?: string;
  loop?: boolean;
};

// Shows a pulsing skeleton circle while the Lottie JSON file itself is
// still being fetched, then swaps to the real animation once it's ready.
export function LottieLoader({ src, size = 160, className = "", loop = true }: LottieLoaderProps) {
  const [animationData, setAnimationData] = useState<object | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    fetch(src)
      .then((res) => {
        if (!res.ok) throw new Error(`Failed to load ${src}`);
        return res.json();
      })
      .then((data) => {
        if (!cancelled) setAnimationData(data);
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });
    return () => {
      cancelled = true;
    };
  }, [src]);

  if (failed) {
    // Fallback if the animation file itself can't be fetched (e.g. offline
    // before the app shell even cached it) - a simple pulsing dot.
    return (
      <div
        className={`rounded-full bg-[var(--surface-hover)] animate-pulse ${className}`}
        style={{ width: size, height: size }}
      />
    );
  }

  if (!animationData) {
    return (
      <div
        className={`rounded-full bg-[var(--surface-hover)] animate-pulse ${className}`}
        style={{ width: size, height: size }}
      />
    );
  }

  return (
    <div className={className} style={{ width: size, height: size }}>
      <Lottie animationData={animationData} loop={loop} />
    </div>
  );
}

export default LottieLoader;
'@
Write-Utf8NoBom $lottieLoaderPath $lottieLoaderContent

# --------------------------------------------------------------------------
# 3. components/ui/skeleton.tsx - shimmer building blocks for page skeletons
# --------------------------------------------------------------------------

$skeletonPath = Join-Path $FrontendRoot "components\ui\skeleton.tsx"
$skeletonContent = @'
export function Skeleton({ className = "" }: { className?: string }) {
  return (
    <div
      className={`animate-pulse rounded-md bg-[var(--surface-hover)] ${className}`}
    />
  );
}

export function SkeletonCard() {
  return (
    <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-4 space-y-3">
      <Skeleton className="h-3 w-24" />
      <Skeleton className="h-6 w-32" />
    </div>
  );
}

export function SkeletonTableRow({ cols = 4 }: { cols?: number }) {
  return (
    <div className="flex items-center gap-4 px-4 py-3 border-b border-[var(--surface-border)] last:border-0">
      {Array.from({ length: cols }).map((_, i) => (
        <Skeleton key={i} className="h-4 flex-1" />
      ))}
    </div>
  );
}

export default Skeleton;
'@
Write-Utf8NoBom $skeletonPath $skeletonContent

# --------------------------------------------------------------------------
# 4. app/(dashboard)/loading.tsx - Next.js auto-shows this during
#    navigation/data loading for every page under (dashboard)
# --------------------------------------------------------------------------

$dashboardLoadingPath = Join-Path $FrontendRoot "app\(dashboard)\loading.tsx"
$dashboardLoadingContent = @'
import { LottieLoader } from "@/components/ui/lottie-loader";
import { SkeletonCard, SkeletonTableRow } from "@/components/ui/skeleton";

export default function DashboardLoading() {
  return (
    <div className="space-y-6">
      <div className="flex flex-col items-center justify-center py-6">
        <LottieLoader src="/loading/loading.json" size={140} />
        <p className="text-sm text-[var(--text-muted)] mt-2">Loading...</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <SkeletonCard />
        <SkeletonCard />
        <SkeletonCard />
        <SkeletonCard />
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] overflow-hidden">
        <SkeletonTableRow cols={4} />
        <SkeletonTableRow cols={4} />
        <SkeletonTableRow cols={4} />
        <SkeletonTableRow cols={4} />
      </div>
    </div>
  );
}
'@
Write-Utf8NoBom $dashboardLoadingPath $dashboardLoadingContent

# --------------------------------------------------------------------------
# 5. app/not-found.tsx - 404 page with the cat Lottie animation
# --------------------------------------------------------------------------

$notFoundPath = Join-Path $FrontendRoot "app\not-found.tsx"
$notFoundContent = @'
import Link from "next/link";
import { LottieLoader } from "@/components/ui/lottie-loader";

export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-[var(--background)] px-4 text-center">
      <LottieLoader src="/loading/404errorpagewithcat.json" size={280} />
      <h1 className="text-2xl font-semibold text-[var(--foreground)] mt-4">Page not found</h1>
      <p className="text-[var(--text-muted)] mt-2 max-w-sm">
        The page you're looking for doesn't exist or may have been moved.
      </p>
      <Link
        href="/"
        className="mt-6 rounded-lg bg-neutral-900 dark:bg-neutral-50 px-5 py-2.5 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity"
      >
        Back to Dashboard
      </Link>
    </div>
  );
}
'@
Write-Utf8NoBom $notFoundPath $notFoundContent

# --------------------------------------------------------------------------
# 6. components/ui/network-status.tsx - offline overlay using the cat
#    animation, shown whenever navigator.onLine goes false
# --------------------------------------------------------------------------

$networkStatusPath = Join-Path $FrontendRoot "components\ui\network-status.tsx"
$networkStatusContent = @'
"use client";

import { useEffect, useState } from "react";
import { LottieLoader } from "@/components/ui/lottie-loader";

export function NetworkStatus() {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    setIsOnline(navigator.onLine);
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  if (isOnline) return null;

  return (
    <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-[var(--background)] px-4 text-center">
      <LottieLoader src="/loading/404errorpagewithcat.json" size={260} />
      <h1 className="text-xl font-semibold text-[var(--foreground)] mt-4">No internet connection</h1>
      <p className="text-[var(--text-muted)] mt-2 max-w-sm">
        Please check your connection. This page will keep working once you're back online.
      </p>
    </div>
  );
}

export default NetworkStatus;
'@
Write-Utf8NoBom $networkStatusPath $networkStatusContent

# --------------------------------------------------------------------------
# 7. app/layout.tsx - wire NetworkStatus in globally (alongside ThemeToaster)
# --------------------------------------------------------------------------

$rootLayoutPath = Join-Path $FrontendRoot "app\layout.tsx"
if (Test-Path $rootLayoutPath) {
    $layout = [System.IO.File]::ReadAllText($rootLayoutPath, [System.Text.Encoding]::UTF8)

    if ($layout -notmatch 'NetworkStatus') {
        $layout = $layout -replace '(import \{ ThemeToaster \} from "@/components/ui/theme-toaster";)', "`$1`nimport { NetworkStatus } from `"@/components/ui/network-status`";"
        $layout = $layout -replace '(\{children\}\s*\n\s*<ThemeToaster />)', "`$1`n        <NetworkStatus />"
        Write-Utf8NoBom $rootLayoutPath $layout
    } else {
        Write-Host "  NetworkStatus already wired into layout.tsx - skipping" -ForegroundColor Gray
    }
} else {
    Write-Host "  SKIPPED: app\layout.tsx not found" -ForegroundColor Yellow
}

# --------------------------------------------------------------------------
# 8. Install the new dependency
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
Write-Host "  loading.json  -> shown on every dashboard page transition/load" -ForegroundColor Gray
Write-Host "    (app/(dashboard)/loading.tsx, plus shimmer skeleton cards/rows)" -ForegroundColor Gray
Write-Host "  404errorpagewithcat.json -> shown on:" -ForegroundColor Gray
Write-Host "    1. Any unmatched route (app/not-found.tsx)" -ForegroundColor Gray
Write-Host "    2. Whenever the browser goes offline (full-screen overlay," -ForegroundColor Gray
Write-Host "       auto-dismisses when connection returns)" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify locally:" -ForegroundColor Cyan
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host "  - Visit any bad URL e.g. /this-does-not-exist -> should show cat 404" -ForegroundColor Gray
Write-Host "  - Navigate between dashboard pages -> brief loading.json + shimmer" -ForegroundColor Gray
Write-Host "  - DevTools -> Network tab -> throttle to 'Offline' -> overlay should appear" -ForegroundColor Gray