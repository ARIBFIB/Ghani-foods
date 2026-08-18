import Link from "next/link";
import { LottieLoader } from "@/components/ui/lottie-loader";

export default function NotFound() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-[var(--background)] px-4 text-center">
      <LottieLoader src="/loading/404errorpagewithcat.json" size={280} />
      <h1 className="text-2xl font-semibold text-[var(--foreground)] mt-4">Page not found</h1>
      <p className="text-[var(--text-muted)] mt-2 max-w-sm">
        The page you're looking for doesn't exist or may have been moved.
      </p>
      <Link
        href="/"
        className="mt-6 rounded-lg bg-neutral-900 dark:bg-neutral-50 px-5 py-2.5 text-sm font-medium text-neutral-50 dark:text-neutral-950 hover:opacity-90 transition-opacity"
      >
        Back to Dashboard
      </Link>
    </div>
  );
}