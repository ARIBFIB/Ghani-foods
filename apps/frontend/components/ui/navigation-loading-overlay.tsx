"use client";

import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { LottieLoader } from "@/components/ui/lottie-loader";

export function NavigationLoadingOverlay() {
  const { isLoading } = useNavigationLoading();

  if (!isLoading) return null;

  return (
    <div className="fixed inset-0 z-[90] flex flex-col items-center justify-center bg-[var(--background)]/70 backdrop-blur-sm">
      <LottieLoader src="/loading/loading.json" size={120} />
    </div>
  );
}

export default NavigationLoadingOverlay;