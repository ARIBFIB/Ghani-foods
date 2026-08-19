import type { ReactNode } from "react";
import { AppSidebar } from "@/components/ui/sidebar-component";
import { Topbar } from "@/components/ui/topbar";
import { SidebarProvider } from "@/lib/sidebar-context";
import { NavigationLoadingProvider } from "@/lib/navigation-loading-context";
import { NavigationLoadingOverlay } from "@/components/ui/navigation-loading-overlay";

export default function DashboardLayout({ children }: { children: ReactNode }) {
  return (
    <NavigationLoadingProvider>
      <SidebarProvider>
        <div className="flex min-h-screen bg-[var(--background)]">
          <AppSidebar />
          <div className="flex-1 flex flex-col min-w-0">
            <Topbar />
            <main className="flex-1 p-4 sm:p-6 overflow-y-auto overflow-x-hidden text-[var(--foreground)]">
              {children}
            </main>
          </div>
        </div>
        <NavigationLoadingOverlay />
      </SidebarProvider>
    </NavigationLoadingProvider>
  );
}