# apply-login-image.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\apply-login-image.ps1
#
# What this does:
#   1. Creates apps\frontend\public\images\ (if missing)
#   2. Updates the login page to display the Ghani Nimko product image
#      on the left panel using next/image
#
# BEFORE RUNNING: copy your product photo into:
#   apps\frontend\public\images\ghani-nimko-bag.png
# (any image format works - just update the filename below if you use
#  a different name/extension, e.g. .jpg)

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    Write-Host "Make sure you're running this from the GhaniFoods root folder." -ForegroundColor Red
    exit 1
}

Write-Host "=== Adding product image to login page ===" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

# --------------------------------------------------------------------------
# 1. Make sure public\images exists
# --------------------------------------------------------------------------

$imagesDir = Join-Path $FrontendRoot "public\images"
if (-not (Test-Path $imagesDir)) {
    New-Item -ItemType Directory -Path $imagesDir -Force | Out-Null
    Write-Host "  Created: apps\frontend\public\images\" -ForegroundColor Green
} else {
    Write-Host "  Exists:  apps\frontend\public\images\" -ForegroundColor Gray
}

$expectedImagePath = Join-Path $imagesDir "ghani-nimko-bag.png"
if (-not (Test-Path $expectedImagePath)) {
    Write-Host ""
    Write-Host "  WARNING: Image not found at:" -ForegroundColor Yellow
    Write-Host "    $expectedImagePath" -ForegroundColor Yellow
    Write-Host "  Copy your product photo there (as ghani-nimko-bag.png) before" -ForegroundColor Yellow
    Write-Host "  running 'npm run dev', otherwise the login page will show a broken image." -ForegroundColor Yellow
    Write-Host ""
}

# --------------------------------------------------------------------------
# 2. Update app/(auth)/login/page.tsx to show the image
# --------------------------------------------------------------------------

$loginPagePath = Join-Path $FrontendRoot "app\(auth)\login\page.tsx"
$loginPageContent = @'
"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { AtSignIcon, LockIcon, Grid2x2PlusIcon } from "lucide-react";

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
    <main className="relative md:h-screen md:overflow-hidden lg:grid lg:grid-cols-2">
      <div className="bg-neutral-900 relative hidden h-full flex-col border-r border-neutral-800 lg:flex overflow-hidden">
        <Image
          src="/images/ghani-nimko-bag.png"
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

      <div className="relative flex min-h-screen flex-col justify-center p-4 bg-black">
        <div className="mx-auto w-full max-w-sm space-y-4">
          <div className="flex items-center gap-2 lg:hidden text-neutral-50">
            <Grid2x2PlusIcon className="size-6" />
            <p className="text-xl font-semibold">GhaniFoods</p>
          </div>

          <div className="flex flex-col space-y-1">
            <h1 className="text-2xl font-bold tracking-wide text-neutral-50">Sign in to GhaniFoods</h1>
            <p className="text-neutral-400 text-base">Enter your credentials to access the dashboard.</p>
          </div>

          <form className="space-y-3" onSubmit={handleSubmit}>
            <div className="relative">
              <input
                type="email"
                placeholder="you@ghanifoods.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full h-10 rounded-md border border-neutral-800 bg-neutral-900 ps-9 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
              />
              <AtSignIcon className="absolute left-3 top-3 size-4 text-neutral-500 pointer-events-none" />
            </div>

            <div className="relative">
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full h-10 rounded-md border border-neutral-800 bg-neutral-900 ps-9 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
              />
              <LockIcon className="absolute left-3 top-3 size-4 text-neutral-500 pointer-events-none" />
            </div>

            {error && <p className="text-red-400 text-sm">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="w-full h-11 rounded-md bg-neutral-50 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
            >
              {loading ? "Signing in..." : "Sign In"}
            </button>
          </form>

          <p className="text-neutral-500 mt-8 text-sm">
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
Write-Host "Reminder: place your image at:" -ForegroundColor Yellow
Write-Host "  apps\frontend\public\images\ghani-nimko-bag.png" -ForegroundColor Yellow
Write-Host "Then run 'npm run dev' to see it on the login page." -ForegroundColor Yellow