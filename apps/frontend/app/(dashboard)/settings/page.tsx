"use client";

import { useState } from "react";

export default function SettingsPage() {
  const [businessName, setBusinessName] = useState("GhaniFoods");
  const [address, setAddress] = useState("Mansehra, Khyber Pakhtunkhwa, Pakistan");
  const [footerText, setFooterText] = useState("Thank you for your business!");
  const [margin, setMargin] = useState("20");
  const [threshold, setThreshold] = useState("50");
  const [saved, setSaved] = useState(false);

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <div className="space-y-6 max-w-2xl">
      <h1 className="text-xl font-semibold text-neutral-50">Settings</h1>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-sm font-semibold text-neutral-200">Business Profile</h2>

        <div>
          <label className="text-sm text-neutral-400">Business Name</label>
          <input
            value={businessName}
            onChange={(e) => setBusinessName(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>

        <div>
          <label className="text-sm text-neutral-400">Address</label>
          <input
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>

        <div>
          <label className="text-sm text-neutral-400">Invoice Footer Text</label>
          <input
            value={footerText}
            onChange={(e) => setFooterText(e.target.value)}
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-sm font-semibold text-neutral-200">Defaults</h2>

        <div>
          <label className="text-sm text-neutral-400">Default Profit Margin %</label>
          <input
            value={margin}
            onChange={(e) => setMargin(e.target.value)}
            type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>

        <div>
          <label className="text-sm text-neutral-400">Low-Stock Threshold Default</label>
          <input
            value={threshold}
            onChange={(e) => setThreshold(e.target.value)}
            type="number"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600"
          />
        </div>
      </div>

      <div className="flex items-center gap-3">
        <button
          onClick={handleSave}
          className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200"
        >
          Save Settings
        </button>
        {saved && <span className="text-sm text-green-400">Saved.</span>}
      </div>
    </div>
  );
}