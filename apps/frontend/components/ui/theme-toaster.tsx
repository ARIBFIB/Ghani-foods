"use client";

import { useEffect, useState } from "react";
import { Toaster } from "sonner";

export function ThemeToaster() {
  const [theme, setTheme] = useState<"light" | "dark">("dark");

  useEffect(() => {
    const sync = () =>
      setTheme(document.documentElement.classList.contains("dark") ? "dark" : "light");
    sync();
    const observer = new MutationObserver(sync);
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] });
    return () => observer.disconnect();
  }, []);

  return <Toaster theme={theme} position="top-right" richColors />;
}

export default ThemeToaster;