"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { AtSignIcon, LockIcon, Grid2x2PlusIcon } from "lucide-react";

const LOGIN_IMAGE_URL = "https://res.cloudinary.com/dr9dwesyo/image/upload/v1787001758/ghanifoods/ghani-nimko-bag.png";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password.trim()) {
      setError("Please enter both email and password.");
      return;
    }
    setLoading(true);
    setError("");
    document.cookie = "ghanifoods-auth=1; path=/; max-age=86400";
    router.push("/");
  };

  return (
    <main className="relative md:h-screen md:overflow-hidden lg:grid lg:grid-cols-2">
      <div className="bg-neutral-900 relative hidden h-full flex-col border-r border-neutral-800 lg:flex overflow-hidden">
        <Image
          src={LOGIN_IMAGE_URL}
          alt="Ghani Food - Nimko"
          fill
          priority
          sizes="50vw"
          className="object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-black/40" />

        <div className="relative z-10 flex items-center gap-2 text-neutral-50 p-10">
          <Grid2x2PlusIcon className="size-6" />
          <p className="text-xl font-semibold">GhaniFoods</p>
        </div>

        <div className="relative z-10 mt-auto p-10">
          <blockquote className="space-y-2">
            <p className="text-xl text-neutral-100">
              Real-time visibility into raw materials, batches, and customer
              ledgers - all in one place.
            </p>
            <footer className="font-mono text-sm font-semibold text-neutral-300">
              ~ GhaniFoods Production Team
            </footer>
          </blockquote>
        </div>
      </div>

      <div className="relative flex min-h-screen flex-col justify-center p-4 bg-black">
        <div className="mx-auto w-full max-w-sm space-y-4">
          <div className="flex items-center gap-2 lg:hidden text-neutral-50">
            <Grid2x2PlusIcon className="size-6" />
            <p className="text-xl font-semibold">GhaniFoods</p>
          </div>

          <div className="flex flex-col space-y-1">
            <h1 className="text-2xl font-bold tracking-wide text-neutral-50">Sign in to GhaniFoods</h1>
            <p className="text-neutral-400 text-base">Enter your credentials to access the dashboard.</p>
          </div>

          <form className="space-y-3" onSubmit={handleSubmit}>
            <div className="relative">
              <input
                type="email"
                placeholder="you@ghanifoods.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full h-10 rounded-md border border-neutral-800 bg-neutral-900 ps-9 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
              />
              <AtSignIcon className="absolute left-3 top-3 size-4 text-neutral-500 pointer-events-none" />
            </div>

            <div className="relative">
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full h-10 rounded-md border border-neutral-800 bg-neutral-900 ps-9 px-3 py-2 text-sm text-neutral-50 placeholder:text-neutral-500 outline-none focus:border-neutral-600"
              />
              <LockIcon className="absolute left-3 top-3 size-4 text-neutral-500 pointer-events-none" />
            </div>

            {error && <p className="text-red-400 text-sm">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="w-full h-11 rounded-md bg-neutral-50 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50"
            >
              {loading ? "Signing in..." : "Sign In"}
            </button>
          </form>

          <p className="text-neutral-500 mt-8 text-sm">
            Demo build - any email / password combination signs you in.
          </p>
        </div>
      </div>
    </main>
  );
}