import type { ReactNode } from "react";
import { AppSidebar } from "@/components/ui/sidebar-component";
import { Topbar } from "@/components/ui/topbar";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-[var(--background)]">
      <AppSidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <Topbar />
        <main className="flex-1 p-6 overflow-y-auto text-[var(--foreground)]">{children}</main>
      </div>
    </div>
  );
}