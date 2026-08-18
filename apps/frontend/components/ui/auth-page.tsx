"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import { useNavigationLoading } from "@/lib/navigation-loading-context";
import { AtSignIcon, LockIcon, Grid2x2PlusIcon } from "lucide-react";
import { Button } from "./button";
import { Input } from "./input";

export function AuthPage() {
  const router = useRouter();
  const { navigate } = useNavigationLoading();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setError("Please enter both email and password.");
      return;
    }
    // Dummy auth: any non-empty credentials succeed
    setError("");
    navigate("/");
  };

  return (
    <main className="relative md:h-screen md:overflow-hidden lg:grid lg:grid-cols-2">
      <div className="bg-[var(--surface)] relative hidden h-full flex-col border-r border-[var(--surface-border)] p-10 lg:flex">
        <div className="z-10 flex items-center gap-2 text-[var(--foreground)]">
          <Grid2x2PlusIcon className="size-6" />
          <p className="text-xl font-semibold">GhaniFoods</p>
        </div>
        <div className="z-10 mt-auto">
          <blockquote className="space-y-2">
            <p className="text-xl text-[var(--foreground)]">
              Real-time visibility into raw materials, batches, and customer ledgers -
              all in one place.
            </p>
            <footer className="font-mono text-sm font-semibold text-[var(--text-muted)]">
              ~ GhaniFoods Production Team
            </footer>
          </blockquote>
        </div>
      </div>

      <div className="relative flex min-h-screen flex-col justify-center p-4 bg-[var(--background)]">
        <div className="mx-auto w-full max-w-sm space-y-4">
          <div className="flex items-center gap-2 lg:hidden text-[var(--foreground)]">
            <Grid2x2PlusIcon className="size-6" />
            <p className="text-xl font-semibold">GhaniFoods</p>
          </div>

          <div className="flex flex-col space-y-1">
            <h1 className="text-2xl font-bold tracking-wide text-[var(--foreground)]">
              Sign in to GhaniFoods
            </h1>
            <p className="text-[var(--text-muted)] text-base">
              Enter your credentials to access the dashboard.
            </p>
          </div>

          <form className="space-y-3" onSubmit={handleSubmit}>
            <div className="relative h-max">
              <Input
                placeholder="you@ghanifoods.com"
                className="peer ps-9 bg-[var(--surface)] border-[var(--surface-border)] text-[var(--foreground)] placeholder:text-[var(--text-faint)]"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
              <div className="text-[var(--text-faint)] pointer-events-none absolute inset-y-0 start-0 flex items-center justify-center ps-3">
                <AtSignIcon className="size-4" aria-hidden="true" />
              </div>
            </div>

            <div className="relative h-max">
              <Input
                placeholder="Password"
                className="peer ps-9 bg-[var(--surface)] border-[var(--surface-border)] text-[var(--foreground)] placeholder:text-[var(--text-faint)]"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <div className="text-[var(--text-faint)] pointer-events-none absolute inset-y-0 start-0 flex items-center justify-center ps-3">
                <LockIcon className="size-4" aria-hidden="true" />
              </div>
            </div>

            {error && <p className="text-red-400 text-sm">{error}</p>}

            <Button type="submit" className="w-full" size="lg">
              Sign In
            </Button>
          </form>

          <p className="text-[var(--text-faint)] mt-8 text-sm">
            Demo build - any email/password combination signs you in.
          </p>
        </div>
      </div>
    </main>
  );
}

export default AuthPage;