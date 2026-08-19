"use client";

import { useState } from "react";
import { Info } from "lucide-react";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

// Shared "i" info-tooltip used next to any field or calculated value whose
// meaning or derivation is not immediately obvious (BRS v1.2 note; Frontend
// spec v2.2 section 5.13: "shadcn Tooltip, lucide Info 14px, hover on
// desktop, tap-to-toggle on touch"). `open` is controlled so the trigger's
// onClick can explicitly flip it â€” touchscreens don't fire hover, so
// relying on Radix's default hover-only behavior would leave touch users
// with no way to see the tooltip at all.
export function InfoTip({ text }: { text: string }) {
  const [open, setOpen] = useState(false);

  return (
    <TooltipProvider delayDuration={150}>
      <Tooltip open={open} onOpenChange={setOpen}>
        <TooltipTrigger asChild>
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              setOpen((v) => !v);
            }}
            aria-label="More info"
            className="ml-1 inline-flex h-3.5 w-3.5 shrink-0 cursor-help select-none items-center justify-center align-middle text-[var(--text-faint)] outline-none hover:text-[var(--text-secondary)]"
          >
            <Info size={14} strokeWidth={2} />
          </button>
        </TooltipTrigger>
        <TooltipContent className="max-w-[220px] text-xs leading-snug">
          {text}
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}

export default InfoTip;