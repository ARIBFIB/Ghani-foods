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

const MIN_VISIBLE_MS = 300;

const NavigationLoadingContext = createContext<NavigationLoadingContextValue | null>(null);

export function NavigationLoadingProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [minTimeElapsed, setMinTimeElapsed] = useState(true);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const navigate = (href: string) => {
    setMinTimeElapsed(false);
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => setMinTimeElapsed(true), MIN_VISIBLE_MS);
    startTransition(() => {
      router.push(href);
    });
  };

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, []);

  const isLoading = isPending || !minTimeElapsed;

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