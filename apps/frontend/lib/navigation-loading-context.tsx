"use client";

import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  useTransition,
  type ReactNode,
} from "react";
import { useRouter } from "next/navigation";

type NavigationLoadingContextValue = {
  isLoading: boolean;
  navigate: (href: string) => void;
};

// If the route resolves before this much time has passed, the loader never
// appears at all - navigation just feels instant. If it takes longer than
// this, the loader is shown immediately and stays up until the transition
// actually finishes (no artificial minimum visible time).
const SHOW_LOADER_AFTER_MS = 150;

const NavigationLoadingContext = createContext<NavigationLoadingContextValue | null>(null);

export function NavigationLoadingProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [showLoader, setShowLoader] = useState(false);
  const showTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const navigate = (href: string) => {
    if (showTimerRef.current) clearTimeout(showTimerRef.current);

    // Don't show anything yet - only arm a timer. If the transition below
    // finishes before this fires, the timer gets cleared and the user never
    // sees a loader at all (this is the common case for prefetched routes).
    showTimerRef.current = setTimeout(() => {
      setShowLoader(true);
    }, SHOW_LOADER_AFTER_MS);

    startTransition(() => {
      router.push(href);
    });
  };

  // As soon as the transition settles, cancel any pending "show loader"
  // timer and hide the loader immediately - no minimum visible duration.
  useEffect(() => {
    if (!isPending) {
      if (showTimerRef.current) {
        clearTimeout(showTimerRef.current);
        showTimerRef.current = null;
      }
      setShowLoader(false);
    }
  }, [isPending]);

  useEffect(() => {
    return () => {
      if (showTimerRef.current) clearTimeout(showTimerRef.current);
    };
  }, []);

  const isLoading = isPending && showLoader;

  return (
    <NavigationLoadingContext.Provider value={{ isLoading, navigate }}>
      {children}
    </NavigationLoadingContext.Provider>
  );
}

export function useNavigationLoading() {
  const ctx = useContext(NavigationLoadingContext);
  if (!ctx) throw new Error("useNavigationLoading must be used within NavigationLoadingProvider");
  return ctx;
}