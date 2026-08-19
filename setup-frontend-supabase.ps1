# ============================================================================
# GhaniFoods Frontend - Supabase Client + Auth Setup
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>
#   PS D:\...\GhaniFoods> .\setup-frontend-supabase.ps1
# Requires apps\frontend to already be a Next.js 15 App Router project.
# ============================================================================

$ErrorActionPreference = "Stop"
$Root      = Get-Location
$Frontend  = Join-Path $Root "apps\frontend"
$BackendEnv = Join-Path $Root "apps\backend\.env"

if (-not (Test-Path $Frontend)) {
    Write-Host "apps\frontend not found. Adjust `$Frontend path in this script if your frontend lives elsewhere." -ForegroundColor Red
    exit 1
}

$SupaUrl = $null; $AnonKey = $null
if (Test-Path $BackendEnv) {
    Get-Content $BackendEnv | ForEach-Object {
        if ($_ -match '^SUPABASE_URL=(.*)$')               { $SupaUrl = $Matches[1] }
        if ($_ -match '^SUPABASE_PUBLISHABLE_KEY=(.*)$')   { $AnonKey = $Matches[1] }
    }
}
if (-not $SupaUrl)  { $SupaUrl = "https://hbvcdxhdkbksknasdqst.supabase.co" }
if (-not $AnonKey)  { $AnonKey = "sb_publishable_wb9g0T-w9vWCalNB0Dbivw_Ipzjyfgd" }

Write-Host "==> Installing @supabase/supabase-js + @supabase/ssr in apps\frontend..." -ForegroundColor Cyan
Set-Location $Frontend
npm install @supabase/supabase-js @supabase/ssr
Set-Location $Root

# ----------------------------------------------------------------------------
# .env.local (public URL/anon key only - safe for frontend)
# ----------------------------------------------------------------------------
$EnvLocalPath = Join-Path $Frontend ".env.local"
if (-not (Test-Path $EnvLocalPath)) {
    $EnvLocal = @"
NEXT_PUBLIC_SUPABASE_URL=$SupaUrl
NEXT_PUBLIC_SUPABASE_ANON_KEY=$AnonKey
"@
    Set-Content -Path $EnvLocalPath -Value $EnvLocal -Encoding UTF8
    Write-Host "==> apps\frontend\.env.local written." -ForegroundColor Green
} else {
    Write-Host "==> apps\frontend\.env.local already exists, leaving it untouched." -ForegroundColor Yellow
}

# ----------------------------------------------------------------------------
# lib/supabase/client.ts  (browser client - Client Components)
# ----------------------------------------------------------------------------
$LibDir = Join-Path $Frontend "lib\supabase"
New-Item -ItemType Directory -Force -Path $LibDir | Out-Null

$ClientTs = @'
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
'@
Set-Content -Path (Join-Path $LibDir "client.ts") -Value $ClientTs -Encoding UTF8

# ----------------------------------------------------------------------------
# lib/supabase/server.ts  (Server Components / Route Handlers / Server Actions)
# ----------------------------------------------------------------------------
$ServerTs = @'
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // called from a Server Component - safe to ignore,
            // middleware refreshes the session instead
          }
        },
      },
    }
  );
}
'@
Set-Content -Path (Join-Path $LibDir "server.ts") -Value $ServerTs -Encoding UTF8

# ----------------------------------------------------------------------------
# lib/supabase/middleware.ts  (session refresh helper used by middleware.ts)
# ----------------------------------------------------------------------------
$MiddlewareLibTs = @'
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isAuthRoute = request.nextUrl.pathname.startsWith("/login");

  if (!user && !isAuthRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  if (user && isAuthRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/";
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}
'@
Set-Content -Path (Join-Path $LibDir "middleware.ts") -Value $MiddlewareLibTs -Encoding UTF8

Write-Host "==> lib\supabase\client.ts / server.ts / middleware.ts written." -ForegroundColor Green

# ----------------------------------------------------------------------------
# middleware.ts at project root (Next.js convention)
# ----------------------------------------------------------------------------
$RootMiddlewarePath = Join-Path $Frontend "middleware.ts"
if (-not (Test-Path $RootMiddlewarePath)) {
    $RootMiddleware = @'
import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function middleware(request: NextRequest) {
  return await updateSession(request);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
'@
    Set-Content -Path $RootMiddlewarePath -Value $RootMiddleware -Encoding UTF8
    Write-Host "==> middleware.ts written at frontend root." -ForegroundColor Green
} else {
    Write-Host "==> middleware.ts already exists at frontend root - not overwritten. Merge the updateSession() call manually." -ForegroundColor Yellow
}

# ----------------------------------------------------------------------------
# app/(auth)/login/page.tsx  (basic login page wired to Supabase Auth)
# ----------------------------------------------------------------------------
$LoginDir = Join-Path $Frontend "app\(auth)\login"
New-Item -ItemType Directory -Force -Path $LoginDir | Out-Null
$LoginPagePath = Join-Path $LoginDir "page.tsx"
if (-not (Test-Path $LoginPagePath)) {
    $LoginPage = @'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { error } = await supabase.auth.signInWithPassword({ email, password });

    setLoading(false);
    if (error) {
      setError(error.message);
      return;
    }
    router.push("/");
    router.refresh();
  }

  return (
    <div style={{ maxWidth: 360, margin: "80px auto" }}>
      <h1>GhaniFoods Login</h1>
      <form onSubmit={handleSubmit}>
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          style={{ display: "block", width: "100%", marginBottom: 8 }}
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          style={{ display: "block", width: "100%", marginBottom: 8 }}
        />
        {error && <p style={{ color: "red" }}>{error}</p>}
        <button type="submit" disabled={loading}>
          {loading ? "Logging in..." : "Log in"}
        </button>
      </form>
    </div>
  );
}
'@
    Set-Content -Path $LoginPagePath -Value $LoginPage -Encoding UTF8
    Write-Host "==> app\(auth)\login\page.tsx written (basic - restyle with shadcn/ui as needed)." -ForegroundColor Green
} else {
    Write-Host "==> login page already exists - not overwritten." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> DONE. Supabase client wired into apps\frontend." -ForegroundColor Green
Write-Host "==> Example RPC call from a Client Component:" -ForegroundColor Cyan
Write-Host '    const supabase = createClient();' -ForegroundColor Cyan
Write-Host '    const { data, error } = await supabase.rpc("fn_create_purchase_receipt", { p_supplier_id, p_purchase_date, p_items });' -ForegroundColor Cyan
Write-Host "==> Example table read: await supabase.from('raw_materials').select('*');" -ForegroundColor Cyan