# Run from repo root: PS D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods> .\fix-middleware-timeout.ps1
# Optional: .\fix-middleware-timeout.ps1 -Push   (git add/commit/push so Vercel redeploys)
param([switch]$Push)
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$mwPath  = Join-Path $PWD "apps\frontend\middleware.ts"
$libPath = Join-Path $PWD "apps\frontend\lib\supabase\middleware.ts"
if (-not (Test-Path $mwPath) -or -not (Test-Path $libPath)) { throw "Repo root se run karo (apps\frontend nahi mila)." }

Copy-Item $mwPath  "$mwPath.bak"  -Force
Copy-Item $libPath "$libPath.bak" -Force

$mw = @'
import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  // Static files / images / favicon pe middleware nahi chalega
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|json|lottie|css|js|map)$).*)"],
};
'@

$lib = @'
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

const AUTH_TIMEOUT_MS = 3000;

function withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const t = setTimeout(() => reject(new Error("auth timeout")), ms);
    p.then((v) => { clearTimeout(t); resolve(v); }, (e) => { clearTimeout(t); reject(e); });
  });
}

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });
  const { pathname } = request.nextUrl;
  const isPublic = pathname.startsWith("/login") || pathname.startsWith("/_next") || pathname.startsWith("/api");

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    // Env missing on Vercel: hang/crash ke bajaye login pe bhejo
    if (isPublic) return supabaseResponse;
    const u = request.nextUrl.clone();
    u.pathname = "/login";
    return NextResponse.redirect(u);
  }

  // Fast path: auth cookie hi nahi hai -> network call ki zaroorat nahi
  const hasAuthCookie = request.cookies
    .getAll()
    .some((c) => c.name.startsWith("sb-") && c.name.includes("auth-token"));

  if (!hasAuthCookie) {
    if (isPublic) return supabaseResponse;
    const u = request.nextUrl.clone();
    u.pathname = "/login";
    return NextResponse.redirect(u);
  }

  const supabase = createServerClient(url, key, {
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
  });

  let user: unknown = null;
  try {
    const res = await withTimeout(supabase.auth.getUser(), AUTH_TIMEOUT_MS);
    user = res.data.user;
  } catch {
    // Supabase slow/down: request ko hang na karo, cookie wala user pass hone do
    // (data access RLS se protected hai).
    return supabaseResponse;
  }

  if (!user && !isPublic) {
    const u = request.nextUrl.clone();
    u.pathname = "/login";
    return NextResponse.redirect(u);
  }

  if (user && pathname.startsWith("/login")) {
    const u = request.nextUrl.clone();
    u.pathname = "/";
    return NextResponse.redirect(u);
  }

  return supabaseResponse;
}
'@

[System.IO.File]::WriteAllText($mwPath,  $mw,  $utf8)
[System.IO.File]::WriteAllText($libPath, $lib, $utf8)
Write-Host "OK: middleware.ts + lib\supabase\middleware.ts update ho gaye (.bak backup bana)." -ForegroundColor Green

if ($Push) {
  git add apps/frontend/middleware.ts apps/frontend/lib/supabase/middleware.ts
  git commit -m "fix: middleware auth timeout (504 MIDDLEWARE_INVOCATION_TIMEOUT)"
  git push
  Write-Host "Pushed - Vercel redeploy ka wait karo." -ForegroundColor Green
} else {
  Write-Host "Ab git push karo (ya -Push se dobara run karo) taake Vercel redeploy ho." -ForegroundColor Yellow
}