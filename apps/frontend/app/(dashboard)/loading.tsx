import { LottieLoader } from "@/components/ui/lottie-loader";
import { SkeletonCard, SkeletonTableRow } from "@/components/ui/skeleton";

export default function DashboardLoading() {
  return (
    <div className="space-y-6">
      <div className="flex flex-col items-center justify-center py-6">
        <LottieLoader src="/loading/loading.json" size={140} />
        <p className="text-sm text-[var(--text-muted)] mt-2">Loading...</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <SkeletonCard />
        <SkeletonCard />
        <SkeletonCard />
        <SkeletonCard />
      </div>

      <div className="rounded-xl border border-[var(--surface-border)] bg-[var(--surface)] overflow-hidden">
        <SkeletonTableRow cols={4} />
        <SkeletonTableRow cols={4} />
        <SkeletonTableRow cols={4} />
        <SkeletonTableRow cols={4} />
      </div>
    </div>
  );
}