"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

type LottieLoaderProps = {
  src: string;
  size?: number;
  className?: string;
  loop?: boolean;
};

// Shows a pulsing skeleton circle while the Lottie JSON file itself is
// still being fetched, then swaps to the real animation once it's ready.
export function LottieLoader({ src, size = 160, className = "", loop = true }: LottieLoaderProps) {
  const [animationData, setAnimationData] = useState<object | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    fetch(src)
      .then((res) => {
        if (!res.ok) throw new Error(`Failed to load ${src}`);
        return res.json();
      })
      .then((data) => {
        if (!cancelled) setAnimationData(data);
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });
    return () => {
      cancelled = true;
    };
  }, [src]);

  if (failed) {
    // Fallback if the animation file itself can't be fetched (e.g. offline
    // before the app shell even cached it) - a simple pulsing dot.
    return (
      <div
        className={`rounded-full bg-[var(--surface-hover)] animate-pulse ${className}`}
        style={{ width: size, height: size }}
      />
    );
  }

  if (!animationData) {
    return (
      <div
        className={`rounded-full bg-[var(--surface-hover)] animate-pulse ${className}`}
        style={{ width: size, height: size }}
      />
    );
  }

  return (
    <div className={className} style={{ width: size, height: size }}>
      <Lottie animationData={animationData} loop={loop} />
    </div>
  );
}

export default LottieLoader;