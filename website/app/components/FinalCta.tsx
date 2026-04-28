import { getDownloadHref, site } from "@/lib/site";

export function FinalCta() {
  const href = getDownloadHref();
  const isExternal = href.startsWith("http");

  return (
    <section className="mx-auto max-w-5xl px-4 pb-24 pt-4 sm:px-6">
      <div className="relative overflow-hidden rounded-3xl border border-cyan-500/30 bg-gradient-to-br from-cyan-500/15 via-slate-900/80 to-fuchsia-600/20 p-8 text-center sm:p-12">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_90%_60%_at_50%_-30%,rgba(34,211,238,0.2),transparent_55%)]"
        />
        <h2 className="relative text-2xl font-bold tracking-tight text-white sm:text-3xl">
          Ready to dictate locally?
        </h2>
        <p className="relative mt-2 text-slate-300">
          {site.description}
        </p>
        <div className="relative mt-8 flex flex-wrap items-center justify-center gap-3">
          <a
            href={href}
            className="btn-primary shadow-lg shadow-cyan-500/20"
            {...(isExternal
              ? { target: "_blank", rel: "noreferrer" }
              : { "aria-label": "Get FloatingRecorder" })}
          >
            Get {site.name}
          </a>
          <a
            href="#security"
            className="inline-flex min-h-11 min-w-[44px] items-center justify-center rounded-full border border-white/20 bg-black/20 px-6 text-sm font-medium text-white backdrop-blur transition hover:bg-black/30"
          >
            Security help
          </a>
        </div>
      </div>
    </section>
  );
}
