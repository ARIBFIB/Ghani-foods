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