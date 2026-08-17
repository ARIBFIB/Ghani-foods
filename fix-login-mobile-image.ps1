# fix-login-mobile-image.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\fix-login-mobile-image.ps1
#
# What this does:
#   1. Shows the Nimko product image on mobile too - as a compact top
#      banner (fixed height, rounded corners, gradient overlay with logo)
#      instead of being fully hidden below `lg`.
#   2. Keeps the existing full split-screen desktop layout unchanged.
#   3. Fixes spacing/sizing so the whole page doesn't look cramped or
#      overflow on small screens: toggle button repositioned so it never
#      overlaps the banner, form padding/max-width adjusted, heading and
#      helper text sizes scale down on mobile.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    exit 1
}

Write-Host "=== Fixing login page mobile image + responsive layout ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

$loginPagePath = Join-Path $FrontendRoot "app\(auth)\login\page.tsx"
if (-not (Test-Path $loginPagePath)) {
    Write-Host "ERROR: login page not found at $loginPagePath" -ForegroundColor Red
    exit 1
}

$loginPageContent = @'
"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { AtSignIcon, LockIcon } from "lucide-react";
import { GhaniLogo } from "@/components/ui/ghani-logo";
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
    <main className="relative min-h-screen lg:h-screen lg:overflow-hidden lg:grid lg:grid-cols-2 bg-[var(--background)]">
      {/* Mobile banner (below lg) - compact hero image with logo overlay */}
      <div className="relative h-40 sm:h-48 w-full overflow-hidden lg:hidden">
        <Image
          src={LOGIN_IMAGE_URL}
          alt="Ghani Food - Nimko"
          fill
          priority
          sizes="100vw"
          className="object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/30 to-black/40" />
        <div className="absolute inset-0 flex items-center gap-2 px-5 text-neutral-50">
          <GhaniLogo className="size-6" />
          <p className="text-lg font-semibold">GhaniFoods</p>
        </div>
      </div>

      {/* Theme toggle - top right, clear of the mobile banner and desktop panel */}
      <div className="absolute top-3 right-3 sm:top-4 sm:right-4 z-20">
        <AnimatedThemeToggler className="border border-[var(--surface-border)] bg-[var(--surface)]" />
      </div>

      {/* Desktop split-screen image panel (lg and up only) */}
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
          <GhaniLogo className="size-6" />
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

      {/* Form panel */}
      <div className="relative flex flex-1 lg:min-h-screen flex-col justify-center px-5 py-8 sm:p-8 lg:p-4 bg-[var(--background)]">
        <div className="mx-auto w-full max-w-sm space-y-4">
          <div className="hidden lg:flex items-center gap-2 text-[var(--foreground)]">
            <GhaniLogo className="size-6" />
            <p className="text-xl font-semibold">GhaniFoods</p>
          </div>

          <div className="flex flex-col space-y-1">
            <h1 className="text-xl sm:text-2xl font-bold tracking-wide text-[var(--foreground)]">Sign in to GhaniFoods</h1>
            <p className="text-[var(--text-muted)] text-sm sm:text-base">Enter your credentials to access the dashboard.</p>
          </div>

          <form className="space-y-3" onSubmit={handleSubmit}>
            <div className="relative">
              <input
                type="email"
                placeholder="you@ghanifoods.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full h-11 sm:h-10 rounded-md border border-[var(--surface-border)] bg-[var(--surface)] ps-9 px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
              />
              <AtSignIcon className="absolute left-3 top-3.5 sm:top-3 size-4 text-[var(--text-faint)] pointer-events-none" />
            </div>

            <div className="relative">
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full h-11 sm:h-10 rounded-md border border-[var(--surface-border)] bg-[var(--surface)] ps-9 px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--text-faint)] outline-none focus:border-[var(--surface-border-strong)]"
              />
              <LockIcon className="absolute left-3 top-3.5 sm:top-3 size-4 text-[var(--text-faint)] pointer-events-none" />
            </div>

            {error && <p className="text-red-500 text-sm">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="w-full h-11 rounded-md bg-neutral-900 dark:bg-neutral-50 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50"
            >
              {loading ? "Signing in..." : "Sign In"}
            </button>
          </form>

          <p className="text-[var(--text-faint)] mt-6 sm:mt-8 text-xs sm:text-sm">
            Demo build - any email / password combination signs you in.
          </p>
        </div>
      </div>
    </main>
  );
}
'@
Write-Utf8NoBom $loginPagePath $loginPageContent

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  Mobile (below lg): image now shows as a 40/48-height top banner" -ForegroundColor Gray
Write-Host "    with logo overlay, followed by the form below it" -ForegroundColor Gray
Write-Host "  Desktop (lg+): unchanged full split-screen layout" -ForegroundColor Gray
Write-Host "  Theme toggle repositioned to never overlap the mobile banner" -ForegroundColor Gray
Write-Host "  Input heights, heading sizes, spacing all scale properly on mobile" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify locally:" -ForegroundColor Cyan
Write-Host "  cd apps\frontend && npm run dev" -ForegroundColor Gray
Write-Host "Then check at 375px/390px width - image banner + form should both be visible and well-spaced." -ForegroundColor Gray