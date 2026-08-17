import type { ReactNode } from "react";
import { AppSidebar } from "@/components/ui/sidebar-component";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-neutral-950">
      <AppSidebar />
      <main className="flex-1 p-6 overflow-y-auto text-neutral-50">{children}</main>
    </div>
  );
}