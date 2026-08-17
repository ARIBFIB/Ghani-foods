# upload-image-to-cloudinary.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage:    .\upload-image-to-cloudinary.ps1
#
# What this does:
#   1. Uploads apps\frontend\public\images\ghani-nimko-bag.png to your
#      Cloudinary account (cloud name: dr9dwesyo) using a SIGNED upload
#      (so it works even though upload presets aren't configured).
#   2. Updates the login page to load the image from Cloudinary instead
#      of the local /public folder - so it works on Vercel without you
#      having to commit a binary image file to git.
#   3. Whitelists res.cloudinary.com in next.config so next/image is
#      allowed to optimize/serve it.
#
# IMPORTANT SECURITY NOTE:
#   Do NOT hardcode your API secret into this script or commit it to git.
#   This script reads your credentials from environment variables you set
#   in THIS PowerShell session only (they disappear when you close the
#   window). Set them right before running this script:
#
#     $env:CLOUDINARY_CLOUD_NAME = "dr9dwesyo"
#     $env:CLOUDINARY_API_KEY    = "482531422298962"
#     $env:CLOUDINARY_API_SECRET = "PASTE_YOUR_SECRET_HERE"
#     .\upload-image-to-cloudinary.ps1
#
#   Also: since your API secret was pasted into a chat earlier, go to
#   Cloudinary Dashboard -> Settings -> API Keys -> regenerate/rotate
#   that key after you're done here, and use the NEW secret going forward.

$ErrorActionPreference = "Stop"
$Root = Get-Location
$FrontendRoot = Join-Path $Root "apps\frontend"

if (-not (Test-Path $FrontendRoot)) {
    Write-Host "ERROR: apps\frontend not found under $Root" -ForegroundColor Red
    Write-Host "Make sure you're running this from the GhaniFoods root folder." -ForegroundColor Red
    exit 1
}

$CloudName  = $env:CLOUDINARY_CLOUD_NAME
$ApiKey     = $env:CLOUDINARY_API_KEY
$ApiSecret  = $env:CLOUDINARY_API_SECRET

if (-not $CloudName -or -not $ApiKey -or -not $ApiSecret) {
    Write-Host "ERROR: Missing Cloudinary credentials." -ForegroundColor Red
    Write-Host ""
    Write-Host "Set these environment variables first, then re-run this script:" -ForegroundColor Yellow
    Write-Host '  $env:CLOUDINARY_CLOUD_NAME = "dr9dwesyo"' -ForegroundColor Gray
    Write-Host '  $env:CLOUDINARY_API_KEY    = "482531422298962"' -ForegroundColor Gray
    Write-Host '  $env:CLOUDINARY_API_SECRET = "your-secret-here"' -ForegroundColor Gray
    Write-Host "  .\upload-image-to-cloudinary.ps1" -ForegroundColor Gray
    exit 1
}

$imagePath = Join-Path $FrontendRoot "public\images\ghani-nimko-bag.png"
if (-not (Test-Path $imagePath)) {
    Write-Host "ERROR: Image not found at $imagePath" -ForegroundColor Red
    Write-Host "Place your product photo there (named ghani-nimko-bag.png) and re-run." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Uploading image to Cloudinary ===" -ForegroundColor Cyan

# --------------------------------------------------------------------------
# Build a SIGNED upload request (Cloudinary requires all extra params to be
# included in the signature, sorted alphabetically, then SHA1-hashed with
# the api_secret appended).
# --------------------------------------------------------------------------

$publicId  = "ghani-nimko-bag"
$folder    = "ghanifoods"
$timestamp = [int][double]::Parse((Get-Date -UFormat %s))

# Params that will be signed - MUST be sorted alphabetically by key
$paramsToSign = [ordered]@{
    folder    = $folder
    public_id = $publicId
    timestamp = $timestamp
}

$sortedKeys = $paramsToSign.Keys | Sort-Object
$stringToSign = ($sortedKeys | ForEach-Object { "$($_)=$($paramsToSign[$_])" }) -join "&"
$stringToSign = "$stringToSign$ApiSecret"

$sha1 = [System.Security.Cryptography.SHA1]::Create()
$hashBytes = $sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))
$signature = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })

Write-Host "  Cloud name: $CloudName" -ForegroundColor Gray
Write-Host "  Public ID:  $folder/$publicId" -ForegroundColor Gray

# --------------------------------------------------------------------------
# Perform the multipart upload via curl (bundled with Windows 10/11)
# --------------------------------------------------------------------------

$uploadUrl = "https://api.cloudinary.com/v1_1/$CloudName/image/upload"

$response = curl.exe -s -X POST $uploadUrl `
    -F "file=@$imagePath" `
    -F "api_key=$ApiKey" `
    -F "timestamp=$timestamp" `
    -F "signature=$signature" `
    -F "public_id=$publicId" `
    -F "folder=$folder"

$json = $response | ConvertFrom-Json

if (-not $json.secure_url) {
    Write-Host "ERROR: Upload failed. Cloudinary response:" -ForegroundColor Red
    Write-Host $response -ForegroundColor Red
    exit 1
}

$secureUrl = $json.secure_url
Write-Host "  Uploaded successfully:" -ForegroundColor Green
Write-Host "  $secureUrl" -ForegroundColor Green

# --------------------------------------------------------------------------
# Update login page to use the Cloudinary URL
# --------------------------------------------------------------------------

function Write-Utf8NoBom($Path, $Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Updated: $($Path.Substring($Root.Path.Length).TrimStart('\'))" -ForegroundColor Green
}

$loginPagePath = Join-Path $FrontendRoot "app\(auth)\login\page.tsx"

$loginPageContent = @"
"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { AtSignIcon, LockIcon, Grid2x2PlusIcon } from "lucide-react";

const LOGIN_IMAGE_URL = "$secureUrl";

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
"@
Write-Utf8NoBom $loginPagePath $loginPageContent

# --------------------------------------------------------------------------
# Whitelist res.cloudinary.com in next.config so next/image can serve it
# --------------------------------------------------------------------------

$nextConfigMjs = Join-Path $FrontendRoot "next.config.mjs"
$nextConfigJs  = Join-Path $FrontendRoot "next.config.js"
$nextConfigTs  = Join-Path $FrontendRoot "next.config.ts"

$existingConfig = @($nextConfigMjs, $nextConfigJs, $nextConfigTs) | Where-Object { Test-Path $_ } | Select-Object -First 1
$configPath = if ($existingConfig) { $existingConfig } else { $nextConfigMjs }

$nextConfigContent = @'
/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "res.cloudinary.com",
        pathname: "/**",
      },
    ],
  },
};

export default nextConfig;
'@
Write-Utf8NoBom $configPath $nextConfigContent

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Image is now hosted on Cloudinary:" -ForegroundColor Green
Write-Host "  $secureUrl" -ForegroundColor Green
Write-Host ""
Write-Host "SECURITY REMINDER:" -ForegroundColor Yellow
Write-Host "  Since your API secret was shared in chat earlier, rotate it now at:" -ForegroundColor Yellow
Write-Host "  Cloudinary Dashboard -> Settings -> API Keys -> Generate New API Key" -ForegroundColor Yellow
Write-Host "  (or regenerate the existing 'Root' key)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  cd apps\frontend && npm run build   (verify it still builds)" -ForegroundColor Gray
Write-Host "  git add -A" -ForegroundColor Gray
Write-Host "  git commit -m `"feat: serve login page image from Cloudinary`"" -ForegroundColor Gray
Write-Host "  git push origin main" -ForegroundColor Gray