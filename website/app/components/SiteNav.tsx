"use client";

import { useState } from "react";
import Link from "next/link";
import { getDownloadHref, site } from "@/lib/site";

const links = [
  { href: "#features", label: "Features" },
  { href: "#install", label: "Install" },
  { href: "#security", label: "Security warning" },
  { href: "#permissions", label: "Permissions" },
  { href: "#faq", label: "FAQ" },
] as const;

export function SiteNav() {
  const [open, setOpen] = useState(false);
  const downloadHref = getDownloadHref();
  const isExternal = downloadHref.startsWith("http");

  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-slate-950/70 backdrop-blur-xl">
      <div className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
        <Link
          href="#top"
          className="group flex items-center gap-2 font-semibold tracking-tight text-slate-100"
        >
          <span className="inline-flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-cyan-400/30 to-fuchsia-500/30 ring-1 ring-cyan-400/40">
            <span className="text-sm font-bold text-cyan-200">F</span>
          </span>
          <span className="group-hover:text-cyan-200 transition-colors">
            {site.name}
          </span>
        </Link>
        <nav
          className="hidden items-center gap-1 md:flex"
          aria-label="Primary"
        >
          {links.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="rounded-lg px-3 py-1.5 text-sm text-slate-400 transition hover:bg-white/5 hover:text-cyan-200"
            >
              {l.label}
            </a>
          ))}
        </nav>
        <div className="flex items-center gap-2">
          {site.githubUrl ? (
            <a
              href={site.githubUrl}
              className="hidden rounded-lg border border-white/10 px-3 py-1.5 text-sm text-slate-300 transition hover:border-cyan-500/50 hover:text-white sm:inline-block"
              target="_blank"
              rel="noreferrer"
            >
              Source
            </a>
          ) : null}
          <a
            href={downloadHref}
            className="btn-primary text-sm"
            {...(isExternal
              ? { target: "_blank", rel: "noreferrer" }
              : { "aria-label": "Scroll to download" })}
            onClick={() => setOpen(false)}
          >
            Download
          </a>
          <button
            type="button"
            className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-white/10 text-slate-200 md:hidden"
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
            aria-controls="mobile-nav"
            aria-label="Toggle menu"
          >
            <span className="sr-only">Menu</span>
            {open ? "✕" : "≡"}
          </button>
        </div>
      </div>
      {open ? (
        <div
          id="mobile-nav"
          className="border-t border-white/10 bg-slate-950/95 px-4 py-3 md:hidden"
        >
          <div className="flex flex-col gap-1">
            {links.map((l) => (
              <a
                key={l.href}
                href={l.href}
                className="rounded-lg px-2 py-2 text-slate-200 hover:bg-white/5"
                onClick={() => setOpen(false)}
              >
                {l.label}
              </a>
            ))}
            {site.githubUrl ? (
              <a
                href={site.githubUrl}
                className="rounded-lg px-2 py-2 text-slate-400 hover:bg-white/5"
                target="_blank"
                rel="noreferrer"
                onClick={() => setOpen(false)}
              >
                Source
              </a>
            ) : null}
          </div>
        </div>
      ) : null}
    </header>
  );
}
