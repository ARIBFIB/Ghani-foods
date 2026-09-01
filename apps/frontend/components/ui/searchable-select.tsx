"use client";

import { useEffect, useMemo, useRef, useState } from "react";

export type SearchableSelectOption = { value: string; label: string };

type Props = {
  value: string;
  onChange: (value: string) => void;
  options: SearchableSelectOption[];
  placeholder?: string;
  searchPlaceholder?: string;
  disabled?: boolean;
  className?: string;
  emptyMessage?: string;
  name?: string;
};

/**
 * Drop-in replacement for a plain <select> when the option list can grow
 * long (raw materials, packaging materials, suppliers, customers, invoice
 * items, etc). Same value/onChange contract as a controlled <select>, so it
 * can also be used inside react-hook-form's <Controller field={...}> by
 * passing value={field.value} onChange={field.onChange}.
 */
export function SearchableSelect({
  value,
  onChange,
  options,
  placeholder = "Select...",
  searchPlaceholder = "Search...",
  disabled = false,
  className = "",
  emptyMessage = "No matches",
  name,
}: Props) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const containerRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);

  const selected = useMemo(() => options.find((o) => o.value === value), [options, value]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return options;
    return options.filter((o) => o.label.toLowerCase().includes(q));
  }, [options, query]);

  useEffect(() => {
    if (!open) return;
    function handleClickOutside(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
        setQuery("");
      }
    }
    function handleEscape(e: KeyboardEvent) {
      if (e.key === "Escape") {
        setOpen(false);
        setQuery("");
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("keydown", handleEscape);
    const t = setTimeout(() => searchInputRef.current?.focus(), 0);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("keydown", handleEscape);
      clearTimeout(t);
    };
  }, [open]);

  return (
    <div ref={containerRef} className={`relative ${className}`}>
      <input type="hidden" name={name} value={value} readOnly />
      <button
        type="button"
        disabled={disabled}
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center justify-between rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)] disabled:opacity-50"
      >
        <span className={selected ? "" : "text-[var(--text-faint)]"}>
          {selected ? selected.label : placeholder}
        </span>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" className="shrink-0 opacity-60">
          <path d="M6 9l6 6 6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>

      {open && (
        <div className="absolute z-50 mt-1 w-full overflow-hidden rounded-lg border border-[var(--surface-border)] bg-[var(--surface)] shadow-lg">
          <div className="border-b border-[var(--surface-border)] p-2">
            <input
              ref={searchInputRef}
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={searchPlaceholder}
              className="w-full rounded-md border border-[var(--surface-border)] bg-[var(--background)] px-2.5 py-1.5 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
            />
          </div>
          <div className="max-h-56 overflow-y-auto py-1">
            {filtered.length === 0 && (
              <div className="px-3 py-2 text-sm text-[var(--text-faint)]">{emptyMessage}</div>
            )}
            {filtered.map((o) => (
              <button
                key={o.value}
                type="button"
                onClick={() => {
                  onChange(o.value);
                  setOpen(false);
                  setQuery("");
                }}
                className={`block w-full px-3 py-1.5 text-left text-sm hover:bg-[var(--surface-hover)] ${
                  o.value === value ? "bg-[var(--surface-hover)] font-medium text-[var(--foreground)]" : "text-[var(--foreground)]"
                }`}
              >
                {o.label}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
