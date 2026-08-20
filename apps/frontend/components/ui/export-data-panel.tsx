"use client";

import { useState } from "react";
import { toast } from "@/components/ui/toast";
import { createClient } from "@/lib/supabase/client";

const MODULE_OPTIONS: { key: string; label: string }[] = [
  { key: "rawMaterials", label: "Raw Materials" },
  { key: "suppliers", label: "Suppliers" },
  { key: "receipts", label: "Receipts" },
  { key: "batches", label: "Batches" },
  { key: "customers", label: "Customers" },
  { key: "invoices", label: "Invoices" },
  { key: "payments", label: "Payments" },
  { key: "wrappers", label: "Wrappers" },
  { key: "boxes", label: "Boxes" },
  { key: "cartonConfigurations", label: "Carton Configurations" },
  { key: "finishedCartons", label: "Finished Cartons" },
];

const FORMAT_OPTIONS: { key: "csv" | "xlsx" | "pdf" | "docx"; label: string }[] = [
  { key: "csv", label: "CSV" },
  { key: "xlsx", label: "Excel (.xlsx)" },
  { key: "pdf", label: "PDF" },
  { key: "docx", label: "Word (.docx)" },
];

export function ExportDataPanel() {
  const [scope, setScope] = useState<"all" | "custom">("all");
  const [selected, setSelected] = useState<string[]>([]);
  const [format, setFormat] = useState<"csv" | "xlsx" | "pdf" | "docx">("xlsx");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [isExporting, setIsExporting] = useState(false);

  const toggleModule = (key: string) => {
    setSelected((prev) => (prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key]));
  };

  const handleExport = async () => {
    if (scope === "custom" && selected.length === 0) {
      toast.error("Select at least one module to export");
      return;
    }
    setIsExporting(true);
    try {
      const supabase = createClient();
      const { data: sessionData } = await supabase.auth.getSession();
      const accessToken = sessionData.session?.access_token;

      const res = await fetch(
        `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/data-export`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            modules: scope === "all" ? ["all"] : selected,
            format,
            dateRange: fromDate || toDate ? { from: fromDate || undefined, to: toDate || undefined } : undefined,
          }),
        },
      );

      const json = await res.json();
      if (!res.ok) throw new Error(json.error ?? "Export failed");

      // Trigger download
      const a = document.createElement("a");
      a.href = json.downloadUrl;
      a.download = json.fileName;
      document.body.appendChild(a);
      a.click();
      a.remove();

      toast.success("Export ready — download started");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to export data");
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] p-5 space-y-4">
      <div>
        <h2 className="text-lg font-semibold text-[var(--foreground)]">Export Data</h2>
        <p className="text-xs text-[var(--text-faint)] mt-1">
          Download your data as a report. Choose everything or specific modules, an optional date
          range, and a file format.
        </p>
      </div>

      <div className="flex items-center gap-4 text-sm">
        <label className="flex items-center gap-1.5">
          <input type="radio" checked={scope === "all"} onChange={() => setScope("all")} />
          Export all data
        </label>
        <label className="flex items-center gap-1.5">
          <input type="radio" checked={scope === "custom"} onChange={() => setScope("custom")} />
          Select specific data
        </label>
      </div>

      {scope === "custom" && (
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
          {MODULE_OPTIONS.map((m) => (
            <label key={m.key} className="flex items-center gap-1.5 text-xs text-[var(--text-secondary)]">
              <input type="checkbox" checked={selected.includes(m.key)} onChange={() => toggleModule(m.key)} />
              {m.label}
            </label>
          ))}
        </div>
      )}

      <div className="flex flex-wrap items-end gap-3">
        <div>
          <label className="text-xs text-[var(--text-muted)]">From (optional)</label>
          <input
            type="date"
            value={fromDate}
            onChange={(e) => setFromDate(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">To (optional)</label>
          <input
            type="date"
            value={toDate}
            onChange={(e) => setToDate(e.target.value)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          />
        </div>
        <div>
          <label className="text-xs text-[var(--text-muted)]">Format</label>
          <select
            value={format}
            onChange={(e) => setFormat(e.target.value as typeof format)}
            className="mt-1 block rounded-lg border border-[var(--surface-border)] bg-[var(--background)] px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[var(--surface-border-strong)]"
          >
            {FORMAT_OPTIONS.map((f) => (
              <option key={f.key} value={f.key}>
                {f.label}
              </option>
            ))}
          </select>
        </div>
        <button
          type="button"
          onClick={handleExport}
          disabled={isExporting}
          className="rounded-lg bg-neutral-900 dark:bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity disabled:opacity-50"
        >
          {isExporting ? "Exporting..." : "Export"}
        </button>
      </div>
    </div>
  );
}

export default ExportDataPanel;
