#
# replace-sonner-with-custom-toast.ps1
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# What this does (the EASY way):
#   Har page mein already sirf simple calls hain: toast.success("...") aur
#   toast.error("...") - koi action/description/promise wagera use nahi ho
#   raha. Isliye hum sonner ko replace kar rahe hain ek chhota, self-contained
#   custom toast component se jo EXACT SAME API deta hai (toast.success(),
#   toast.error(), toast.warning(), toast.message()) - matlab sirf IMPORT
#   LINE badalni hai, baaki ka code (jo already 14+ pages mein likha hai)
#   bilkul waise hi chalega, ek line bhi chhedni nahi paregi.
#
#   1. apps/frontend/components/ui/toast.tsx  -> naya custom toast component
#      (apni styling, top-right, stacked, auto-dismiss, close button)
#   2. Har file mein  import { toast } from "sonner";
#      ko                import { toast } from "@/components/ui/toast";
#      se replace kar deta hai (14 pages + purchase-receipt-dialog.tsx)
#   3. layout.tsx se <ThemeToaster /> hata deta hai (ab zaroorat nahi -
#      naya toast component khud apna container mount kar leta hai)
#   4. theme-toaster.tsx ko chhoda nahi jata - wo bas ab use nahi hoga
#      (delete nahi kiya, taake kuch break na ho agar kahin aur ref ho)
#
# Safe to re-run - already-applied files/lines skip ho jayenge.
# Har modified file ki backup <file>.bak-<timestamp> ban jayegi.
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

function Backup-File($path) {
    Copy-Item -LiteralPath $path -Destination "$path.bak-$stamp"
    Write-Host "  Backed up -> $(Split-Path $path -Leaf).bak-$stamp" -ForegroundColor DarkGray
}

# -----------------------------------------------------------------
# 1. Create the custom toast component
# -----------------------------------------------------------------
$toastComponentPath = Join-Path $root "apps\frontend\components\ui\toast.tsx"
$toastDir = Split-Path $toastComponentPath -Parent

if (-not (Test-Path -LiteralPath $toastDir)) {
    Write-Host "ERROR: Could not find $toastDir" -ForegroundColor Red
    exit 1
}

if (Test-Path -LiteralPath $toastComponentPath) {
    Backup-File $toastComponentPath
}

$toastComponent = @'
"use client";

import { ReactNode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import clsx from "clsx";

type ToastType = "message" | "success" | "warning" | "error";

type ToastItem = {
  id: number;
  text: string;
  type: ToastType;
};

let root: ReturnType<typeof createRoot> | null = null;
let toastId = 0;
let toasts: ToastItem[] = [];
const listeners = new Set<() => void>();

function notify() {
  listeners.forEach((fn) => fn());
}

function addToast(text: string, type: ToastType, duration = 3500) {
  const id = toastId++;
  toasts = [...toasts, { id, text, type }];
  notify();
  if (duration > 0) {
    setTimeout(() => removeToast(id), duration);
  }
}

function removeToast(id: number) {
  toasts = toasts.filter((t) => t.id !== id);
  notify();
}

const styles: Record<ToastType, string> = {
  success:
    "bg-green-50 border-green-200 text-green-800 dark:bg-green-950 dark:border-green-900 dark:text-green-300",
  error:
    "bg-red-50 border-red-200 text-red-800 dark:bg-red-950 dark:border-red-900 dark:text-red-300",
  warning:
    "bg-amber-50 border-amber-200 text-amber-800 dark:bg-amber-950 dark:border-amber-900 dark:text-amber-300",
  message:
    "bg-white border-gray-200 text-gray-800 dark:bg-neutral-900 dark:border-neutral-700 dark:text-neutral-200",
};

const icons: Record<ToastType, ReactNode> = {
  success: (
    <svg viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5 shrink-0">
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
      />
    </svg>
  ),
  error: (
    <svg viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5 shrink-0">
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z"
      />
    </svg>
  ),
  warning: (
    <svg viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5 shrink-0">
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 6a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 6zm0 8a1 1 0 100-2 1 1 0 000 2z"
      />
    </svg>
  ),
  message: null,
};

function ToastContainer() {
  const [items, setItems] = useState<ToastItem[]>([]);
  const [shown, setShown] = useState<number[]>([]);

  useEffect(() => {
    setItems([...toasts]);
    const unsub = () => setItems([...toasts]);
    listeners.add(unsub);
    return () => {
      listeners.delete(unsub);
    };
  }, []);

  useEffect(() => {
    const unseen = items.filter((t) => !shown.includes(t.id)).map((t) => t.id);
    if (unseen.length) {
      requestAnimationFrame(() => setShown((prev) => [...prev, ...unseen]));
    }
  }, [items]);

  return (
    <div className="fixed top-4 right-4 z-[9999] flex flex-col gap-2 w-[380px] max-w-[calc(100vw-2rem)] pointer-events-none">
      {items.map((t) => (
        <div
          key={t.id}
          className={clsx(
            "pointer-events-auto flex items-start gap-2.5 rounded-xl border shadow-lg px-4 py-3 text-sm font-medium transition-all duration-300",
            styles[t.type],
            shown.includes(t.id) ? "opacity-100 translate-x-0" : "opacity-0 translate-x-4"
          )}
        >
          {icons[t.type]}
          <span className="flex-1 leading-snug">{t.text}</span>
          <button
            onClick={() => removeToast(t.id)}
            className="shrink-0 opacity-60 hover:opacity-100 transition-opacity"
            aria-label="Dismiss"
          >
            <svg viewBox="0 0 16 16" width="14" height="14" fill="currentColor">
              <path d="M12.47 13.53a.75.75 0 001.06-1.06L9.06 8l4.47-4.47a.75.75 0 10-1.06-1.06L8 6.94 3.53 2.47a.75.75 0 00-1.06 1.06L6.94 8l-4.47 4.47a.75.75 0 101.06 1.06L8 9.06l4.47 4.47z" />
            </svg>
          </button>
        </div>
      ))}
    </div>
  );
}

function mountContainer() {
  if (root || typeof window === "undefined") return;
  const el = document.createElement("div");
  document.body.appendChild(el);
  root = createRoot(el);
  root.render(<ToastContainer />);
}

export const toast = {
  success: (text: string) => {
    mountContainer();
    addToast(text, "success");
  },
  error: (text: string) => {
    mountContainer();
    addToast(text, "error");
  },
  warning: (text: string) => {
    mountContainer();
    addToast(text, "warning");
  },
  message: (text: string) => {
    mountContainer();
    addToast(text, "message");
  },
};

export default toast;
'@

Set-Content -LiteralPath $toastComponentPath -Value $toastComponent -NoNewline
Write-Host "Created/updated apps/frontend/components/ui/toast.tsx" -ForegroundColor Green

# -----------------------------------------------------------------
# 2. Swap the import line in every file that uses sonner's toast
# -----------------------------------------------------------------
$oldImport = 'import { toast } from "sonner";'
$newImport = 'import { toast } from "@/components/ui/toast";'

$targets = Get-ChildItem -Path (Join-Path $root "apps\frontend") -Recurse -Include *.tsx,*.ts |
    Where-Object { $_.FullName -ne $toastComponentPath }

$changedCount = 0
foreach ($file in $targets) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    if ($content -match [regex]::Escape($oldImport)) {
        Backup-File $file.FullName
        $updated = $content -replace [regex]::Escape($oldImport), $newImport
        Set-Content -LiteralPath $file.FullName -Value $updated -NoNewline
        Write-Host "Updated: $($file.FullName.Substring($root.Path.Length + 1))" -ForegroundColor Green
        $changedCount++
    }
}
Write-Host "Total files switched from sonner to custom toast: $changedCount" -ForegroundColor Cyan

# -----------------------------------------------------------------
# 3. Remove <ThemeToaster /> from layout.tsx (no longer needed)
# -----------------------------------------------------------------
$layoutPath = Join-Path $root "apps\frontend\app\layout.tsx"

if (-not (Test-Path -LiteralPath $layoutPath)) {
    Write-Host "WARNING: Could not find $layoutPath - skipping layout cleanup." -ForegroundColor Yellow
}
else {
    $layoutContent = Get-Content -Raw -LiteralPath $layoutPath

    if ($layoutContent -notmatch 'ThemeToaster') {
        Write-Host "layout.tsx already clean (no ThemeToaster) - skipping." -ForegroundColor Yellow
    }
    else {
        Backup-File $layoutPath
        $updated = $layoutContent `
            -replace 'import \{ ThemeToaster \} from "@/components/ui/theme-toaster";\r?\n', '' `
            -replace '\s*<ThemeToaster />\r?\n', "`r`n"
        Set-Content -LiteralPath $layoutPath -Value $updated -NoNewline
        Write-Host "layout.tsx -> ThemeToaster (sonner) removed." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Done. Naya custom toast top-right pe show hoga, poore app mein same design ke sath." -ForegroundColor Green
Write-Host "Note: 'sonner' package.json mein reh gaya hai (harmless, unused) - chahen to baad mein 'npm uninstall sonner' chala sakte hain." -ForegroundColor DarkGray