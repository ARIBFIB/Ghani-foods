"use client";

import { useEffect } from "react";
import { useStore } from "@/lib/store";

// Fires once on dashboard mount and pulls every module's live data from
// Supabase. The store no longer persists to localStorage or ships seed
// data, so this is the single entry point that hydrates it each session.
export function StoreHydrator() {
  const loadAll = useStore((s) => s.loadAll);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  return null;
}
