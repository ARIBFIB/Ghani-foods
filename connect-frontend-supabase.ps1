# ============================================================================
# GhaniFoods Frontend - Connect to REAL Supabase Auth (replaces dummy cookie auth)
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>
#   PS D:\...\GhaniFoods> .\connect-frontend-supabase.ps1
# ============================================================================

$ErrorActionPreference = "Stop"
$Root       = Get-Location
$Frontend   = Join-Path $Root "apps\frontend"
$BackendEnv = Join-Path $Root "apps\backend\.env"

if (-not (Test-Path $Frontend)) {
    Write-Host "apps\frontend not found." -ForegroundColor Red
    exit 1
}

$SupaUrl = $null; $AnonKey = $null
if (Test-Path $BackendEnv) {
    Get-Content $BackendEnv | ForEach-Object {
        if ($_ -match '^SUPABASE_URL=(.*)$')             { $SupaUrl = $Matches[1] }
        if ($_ -match '^SUPABASE_PUBLISHABLE_KEY=(.*)$')  { $AnonKey = $Matches[1] }
    }
}
if (-not $SupaUrl) { $SupaUrl = "https://hbvcdxhdkbksknasdqst.supabase.co" }
if (-not $AnonKey) { $AnonKey = "sb_publishable_wb9g0T-w9vWCalNB0Dbivw_Ipzjyfgd" }

Write-Host "==> Installing @supabase/supabase-js + @supabase/ssr..." -ForegroundColor Cyan
Set-Location $Frontend
npm install @supabase/supabase-js @supabase/ssr
Set-Location $Root

# ----------------------------------------------------------------------------
# .env.local
# ----------------------------------------------------------------------------
$EnvLocalPath = Join-Path $Frontend ".env.local"
$EnvLocal = @"
NEXT_PUBLIC_SUPABASE_URL=$SupaUrl
NEXT_PUBLIC_SUPABASE_ANON_KEY=$AnonKey
"@
Set-Content -Path $EnvLocalPath -Value $EnvLocal -Encoding UTF8
Write-Host "==> .env.local written." -ForegroundColor Green

# ----------------------------------------------------------------------------
# lib/supabase/client.ts + server.ts + middleware.ts
# ----------------------------------------------------------------------------
$LibDir = Join-Path $Frontend "lib\supabase"
New-Item -ItemType Directory -Force -Path $LibDir | Out-Null

Set-Content -Path (Join-Path $LibDir "client.ts") -Encoding UTF8 -Value @'
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
'@

Set-Content -Path (Join-Path $LibDir "server.ts") -Encoding UTF8 -Value @'
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
            // Server Component call - middleware refreshes the session instead
          }
        },
      },
    }
  );
}
'@

Set-Content -Path (Join-Path $LibDir "middleware.ts") -Encoding UTF8 -Value @'
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

  const { pathname } = request.nextUrl;
  const isPublic = pathname.startsWith("/login") || pathname.startsWith("/_next") || pathname.startsWith("/api");

  if (!user && !isPublic) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  if (user && pathname.startsWith("/login")) {
    const url = request.nextUrl.clone();
    url.pathname = "/";
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}
'@
Write-Host "==> lib\supabase\client.ts / server.ts / middleware.ts written." -ForegroundColor Green

# ----------------------------------------------------------------------------
# Root middleware.ts - replace dummy cookie check with real Supabase session
# ----------------------------------------------------------------------------
Set-Content -Path (Join-Path $Frontend "middleware.ts") -Encoding UTF8 -Value @'
import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
'@
Write-Host "==> middleware.ts replaced with real Supabase session check." -ForegroundColor Green

# ----------------------------------------------------------------------------
# app/(auth)/login/page.tsx - same UI, real Supabase signInWithPassword
# ----------------------------------------------------------------------------
$LoginPagePath = Join-Path $Frontend "app\(auth)\login\page.tsx"
Set-Content -Path $LoginPagePath -Encoding UTF8 -Value @'
"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { AtSignIcon, LockIcon } from "lucide-react";
import { GhaniLogo } from "@/components/ui/ghani-logo";
import { AnimatedThemeToggler } from "@/components/ui/animated-theme-toggler";
import { createClient } from "@/lib/supabase/client";

const LOGIN_IMAGE_URL = "https://res.cloudinary.com/dr9dwesyo/image/upload/v1787001758/ghanifoods/ghani-nimko-bag.png";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password.trim()) {
      setError("Please enter both email and password.");
      return;
    }
    setLoading(true);
    setError("");

    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    setLoading(false);
    if (signInError) {
      setError(signInError.message);
      return;
    }
    router.push("/");
    router.refresh();
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
        </div>
      </div>
    </main>
  );
}
'@
Write-Host "==> login page.tsx updated to real Supabase auth (same UI kept)." -ForegroundColor Green

# ----------------------------------------------------------------------------
# lib/api.ts - typed bridge to Supabase (RPC + table reads), for gradually
# replacing lib/store.ts mock-data actions page by page.
# ----------------------------------------------------------------------------
Set-Content -Path (Join-Path $Frontend "lib\api.ts") -Encoding UTF8 -Value @'
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

// ---------- simple table reads ----------
export const getSuppliers = () => supabase.from("suppliers").select("*").order("created_at", { ascending: false });
export const getRawMaterials = () => supabase.from("raw_materials").select("*").order("name");
export const getWrappers = () => supabase.from("wrappers").select("*").order("name");
export const getBoxes = () => supabase.from("boxes").select("*").order("name");
export const getCartonConfigurations = () => supabase.from("carton_configurations").select("*").order("created_at", { ascending: false });
export const getProductionBatches = () => supabase.from("production_batches").select("*").order("batch_date", { ascending: false });
export const getFinishedCartons = () => supabase.from("finished_cartons").select("*").order("created_at", { ascending: false });
export const getCustomers = () => supabase.from("customers").select("*").order("name");
export const getInvoices = () => supabase.from("invoices").select("*").order("invoice_date", { ascending: false });
export const getPayments = () => supabase.from("payments").select("*").order("paid_at", { ascending: false });
export const getAppSettings = () => supabase.from("app_settings").select("*").eq("id", 1).single();

// ---------- RPC (business-logic) calls ----------
export const createPurchaseReceipt = (supplierId: string, purchaseDate: string, items: unknown) =>
  supabase.rpc("fn_create_purchase_receipt", { p_supplier_id: supplierId, p_purchase_date: purchaseDate, p_items: items });

export const produceWrapper = (wrapperId: string, qty: number) =>
  supabase.rpc("fn_produce_wrapper", { p_wrapper_id: wrapperId, p_qty: qty });

export const produceBox = (boxId: string, qty: number) =>
  supabase.rpc("fn_produce_box", { p_box_id: boxId, p_qty: qty });

export const createProductionBatch = (
  consumptions: unknown,
  outputYieldKg: number,
  wastageKg: number,
  leftoverBatchId?: string,
  leftoverKgUsed?: number
) =>
  supabase.rpc("fn_create_production_batch", {
    p_consumptions: consumptions,
    p_output_yield_kg: outputYieldKg,
    p_wastage_kg: wastageKg,
    p_leftover_batch_id: leftoverBatchId ?? null,
    p_leftover_kg_used: leftoverKgUsed ?? null,
  });

export const allocateOverhead = (batchId: string, electricity: number, gas: number, rent: number) =>
  supabase.rpc("fn_allocate_overhead", { p_batch_id: batchId, p_electricity: electricity, p_gas: gas, p_rent: rent });

export const packingRunPreview = (batchId: string, configId: string, cartonsProduced: number) =>
  supabase.rpc("fn_packing_run_preview", { p_batch_id: batchId, p_config_id: configId, p_cartons_produced: cartonsProduced });

export const createPackingRun = (batchId: string, configId: string, cartonsProduced: number) =>
  supabase.rpc("fn_create_packing_run", { p_batch_id: batchId, p_config_id: configId, p_cartons_produced: cartonsProduced });

export const priceLookup = (customerId: string, itemId: string) =>
  supabase.rpc("fn_price_lookup", { p_customer_id: customerId, p_item_id: itemId });

export const createInvoice = (customerId: string, lines: unknown) =>
  supabase.rpc("fn_create_invoice", { p_customer_id: customerId, p_lines: lines });

export const recordPayment = (customerId: string, amount: number, direction: "received" | "given", note?: string) =>
  supabase.rpc("fn_record_payment", { p_customer_id: customerId, p_amount: amount, p_direction: direction, p_note: note ?? null });

// ---------- auth ----------
export const signOut = () => supabase.auth.signOut();
export const getCurrentUser = () => supabase.auth.getUser();
'@
Write-Host "==> lib\api.ts written (Supabase bridge for RPCs + tables)." -ForegroundColor Green

Write-Host ""
Write-Host "==> DONE. Login + middleware now use REAL Supabase auth." -ForegroundColor Green
Write-Host "==> lib\store.ts still runs on mock-data - pages still show demo data until wired to lib\api.ts, one page at a time." -ForegroundColor Yellow
Write-Host "==> Try: npm run dev (in apps\frontend) then log in with admin@gmail.com / your password." -ForegroundColor Cyan