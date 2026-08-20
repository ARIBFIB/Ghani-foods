#
# fix-toast-position-and-color.ps1
# --------------------------------
# Run this from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
#
# Pre-requisite: update-toast-design.ps1 already chal chuki honi chahiye
# (taake apps/frontend/components/ui/toast.tsx aur globals.css setup ho
# chuki hon).
#
# What this does:
#   apps/frontend/components/ui/toast.tsx ko update karti hai:
#     1. Position: bottom-right -> TOP-right (stacking ab neeche ki taraf
#        badhegi, jaisa top-right toasts mein hota hai)
#     2. Success color: blue-700 hata kar message jaisa dark/theme-based
#        color (bg-geist-background / text-gray-1000) laga diya - light
#        mode mein white/dark-text, dark mode mein black/light-text.
#        Error (red-800) aur Warning (amber-800) waise hi rahenge.
#
#   Koi page ka code nahi chhedti - toast.success()/error() calls waise
#   hi chalenge.
#
# Safe to re-run. Modified file ki backup <file>.bak-<timestamp> banegi.
#

$ErrorActionPreference = "Stop"
$root = Get-Location
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "Running in: $root" -ForegroundColor Cyan

$toastPath = Join-Path $root "apps\frontend\components\ui\toast.tsx"

if (-not (Test-Path -LiteralPath $toastPath)) {
    Write-Host "ERROR: Could not find $toastPath" -ForegroundColor Red
    exit 1
}

Copy-Item -LiteralPath $toastPath -Destination "$toastPath.bak-$stamp"
Write-Host "Backed up -> toast.tsx.bak-$stamp" -ForegroundColor DarkGray

$toastComponent = @'
"use client";

import { ReactNode, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import clsx from "clsx";

const CloseIcon = ({ className }: { className: string }) => (
  <svg height="16" strokeLinejoin="round" viewBox="0 0 16 16" width="16" className={className}>
    <path
      fillRule="evenodd"
      clipRule="evenodd"
      d="M12.4697 13.5303L13 14.0607L14.0607 13L13.5303 12.4697L9.06065 7.99999L13.5303 3.53032L14.0607 2.99999L13 1.93933L12.4697 2.46966L7.99999 6.93933L3.53032 2.46966L2.99999 1.93933L1.93933 2.99999L2.46966 3.53032L6.93933 7.99999L2.46966 12.4697L1.93933 13L2.99999 14.0607L3.53032 13.5303L7.99999 9.06065L12.4697 13.5303Z"
    />
  </svg>
);

type ToastType = "message" | "success" | "warning" | "error";

type Toast = {
  id: number;
  text: string | ReactNode;
  measuredHeight?: number;
  timeout?: ReturnType<typeof setTimeout>;
  remaining?: number;
  start?: number;
  pause?: () => void;
  resume?: () => void;
  type: ToastType;
};

let root: ReturnType<typeof createRoot> | null = null;
let toastId = 0;

const toastStore = {
  toasts: [] as Toast[],
  listeners: new Set<() => void>(),

  add(text: string | ReactNode, type: ToastType) {
    const id = toastId++;
    const toast: Toast = { id, text, type };

    toast.remaining = 3000;
    toast.start = Date.now();

    const close = () => {
      this.toasts = this.toasts.filter((t) => t.id !== id);
      this.notify();
    };

    toast.timeout = setTimeout(close, toast.remaining);

    toast.pause = () => {
      if (!toast.timeout) return;
      clearTimeout(toast.timeout);
      toast.timeout = undefined;
      toast.remaining! -= Date.now() - toast.start!;
    };

    toast.resume = () => {
      if (toast.timeout) return;
      toast.start = Date.now();
      toast.timeout = setTimeout(close, toast.remaining);
    };

    this.toasts.push(toast);
    this.notify();
  },

  remove(id: number) {
    toastStore.toasts = toastStore.toasts.filter((t) => t.id !== id);
    toastStore.notify();
  },

  subscribe(listener: () => void) {
    toastStore.listeners.add(listener);
    return () => {
      toastStore.listeners.delete(listener);
    };
  },

  notify() {
    toastStore.listeners.forEach((fn) => fn());
  }
};

const ToastContainer = () => {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [shownIds, setShownIds] = useState<number[]>([]);
  const [isHovered, setIsHovered] = useState<boolean>(false);

  const measureRef = (toast: Toast) => (node: HTMLDivElement | null) => {
    if (node && toast.measuredHeight == null) {
      toast.measuredHeight = node.getBoundingClientRect().height;
      toastStore.notify();
    }
  };

  useEffect(() => {
    setToasts([...toastStore.toasts]);
    return toastStore.subscribe(() => {
      setToasts([...toastStore.toasts]);
    });
  }, []);

  useEffect(() => {
    const unseen = toasts.filter((t) => !shownIds.includes(t.id)).map((t) => t.id);
    if (unseen.length > 0) {
      requestAnimationFrame(() => {
        setShownIds((prev) => [...prev, ...unseen]);
      });
    }
  }, [toasts]);

  const lastVisibleCount = 3;
  const lastVisibleStart = Math.max(0, toasts.length - lastVisibleCount);

  // Top-right stacking: newest toast sits at the top (offset 0), older
  // toasts get pushed DOWN by the accumulated height of the ones above them.
  const getFinalTransform = (index: number, length: number) => {
    if (index === length - 1) return "none";
    const offset = length - 1 - index;
    let translateY = 0;
    for (let i = length - 1; i > index; i--) {
      translateY += isHovered ? (toasts[i]?.measuredHeight || 63) + 10 : 20;
    }
    const z = -offset;
    const scale = isHovered ? 1 : 1 - 0.05 * offset;
    return `translate3d(0, ${translateY}px, ${z}px) scale(${scale})`;
  };

  const handleMouseEnter = () => {
    setIsHovered(true);
    toastStore.toasts.forEach((t) => t.pause?.());
  };

  const handleMouseLeave = () => {
    setIsHovered(false);
    toastStore.toasts.forEach((t) => t.resume?.());
  };

  const visibleToasts = toasts.slice(lastVisibleStart);
  const containerHeight = visibleToasts.reduce((acc, toast) => acc + (toast.measuredHeight ?? 63), 0);

  return (
    <div
      className="fixed top-4 right-4 z-[9999] pointer-events-none w-[420px] max-w-[calc(100vw-2rem)]"
      style={{ height: containerHeight }}
    >
      <div
        className="relative pointer-events-auto w-full"
        style={{ height: containerHeight }}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
      >
        {toasts.map((toast, index) => {
          const isVisible = index >= lastVisibleStart;
          return (
            <div
              key={toast.id}
              ref={measureRef(toast)}
              className={clsx(
                "absolute right-0 top-0 shadow-menu rounded-xl leading-[21px] p-4 h-fit",
                {
                  message: "bg-geist-background text-gray-1000",
                  success: "bg-geist-background text-gray-1000",
                  warning: "bg-amber-800 text-gray-1000 dark:text-gray-100",
                  error: "bg-red-800 text-contrast-fg"
                }[toast.type],
                isVisible ? "opacity-100" : "opacity-0",
                index < lastVisibleStart && "pointer-events-none"
              )}
              style={{
                width: 420,
                transition: "all .35s cubic-bezier(.25,.75,.6,.98)",
                transform: shownIds.includes(toast.id)
                  ? getFinalTransform(index, toasts.length)
                  : "translate3d(0, -100%, 150px) scale(1)"
              }}
            >
              <div className="flex items-start justify-between gap-4 text-[.875rem]">
                <span className="flex-1">{toast.text}</span>
                <button
                  type="button"
                  onClick={() => toastStore.remove(toast.id)}
                  className="shrink-0 rounded-md p-1 -m-1 hover:bg-black/10 transition-colors"
                  aria-label="Dismiss"
                >
                  <CloseIcon
                    className={
                      {
                        message: "fill-gray-1000",
                        success: "fill-gray-1000",
                        warning: "fill-gray-1000 dark:fill-gray-100",
                        error: "fill-contrast-fg"
                      }[toast.type]
                    }
                  />
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

const mountContainer = () => {
  if (root || typeof window === "undefined") return;
  const el = document.createElement("div");
  document.body.appendChild(el);
  root = createRoot(el);
  root.render(<ToastContainer />);
};

export const toast = {
  message: (text: string | ReactNode) => {
    mountContainer();
    toastStore.add(text, "message");
  },
  success: (text: string | ReactNode) => {
    mountContainer();
    toastStore.add(text, "success");
  },
  warning: (text: string | ReactNode) => {
    mountContainer();
    toastStore.add(text, "warning");
  },
  error: (text: string | ReactNode) => {
    mountContainer();
    toastStore.add(text, "error");
  }
};

export default toast;
'@

Set-Content -LiteralPath $toastPath -Value $toastComponent -NoNewline
Write-Host "toast.tsx -> position moved to top-right, success color now dark/theme-based (like message)." -ForegroundColor Green

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "success = bg-geist-background/text-gray-1000 (theme-adaptive dark), error = red-800, warning = amber-800" -ForegroundColor DarkGray