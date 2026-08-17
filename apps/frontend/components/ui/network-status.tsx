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