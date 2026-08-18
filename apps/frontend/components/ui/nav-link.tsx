"use client";

import NextLink, { type LinkProps } from "next/link";
import { forwardRef, type AnchorHTMLAttributes } from "react";
import { useNavigationLoading } from "@/lib/navigation-loading-context";

type NavLinkProps = LinkProps &
  Omit<AnchorHTMLAttributes<HTMLAnchorElement>, keyof LinkProps | "href"> & {
    children?: React.ReactNode;
  };

// Drop-in replacement for next/link. Keeps Next's built-in prefetching
// (hover/viewport) so most routes are already warm by the time they're
// clicked, but routes the actual click through the shared navigate()
// context so every link in the app gets the same instant-nav /
// only-show-loader-if-actually-slow behavior as the sidebar.
export const NavLink = forwardRef<HTMLAnchorElement, NavLinkProps>(
  ({ href, onClick, children, ...rest }, ref) => {
    const { navigate } = useNavigationLoading();

    const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
      onClick?.(e);
      if (e.defaultPrevented) return;
      // Let modified clicks (new tab, etc.) behave natively.
      if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;
      e.preventDefault();
      navigate(typeof href === "string" ? href : href.toString());
    };

    return (
      <NextLink ref={ref} href={href} onClick={handleClick} {...rest}>
        {children}
      </NextLink>
    );
  }
);
NavLink.displayName = "NavLink";

export default NavLink;