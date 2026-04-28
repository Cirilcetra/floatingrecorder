import { getDownloadHref, site } from "@/lib/site";

const steps = [
  {
    n: 1,
    title: "Download the DMG",
    body: (
      <>
        Get <code className="code-inline">FloatingRecorder.dmg</code> from your
        release host or the button below, then open it.
      </>
    ),
  },
  {
    n: 2,
    title: "Install to Applications",
    body: "Drag FloatingRecorder.app onto the Applications folder shortcut in the disk image.",
  },
  {
    n: 3,
    title: "First launch",
    body: "Open FloatingRecorder from Applications. If macOS blocks it, follow the Security section — one-time setup.",
  },
] as const;

export function InstallSteps() {
  const href = getDownloadHref();
  const isExternal = href.startsWith("http");

  return (
    <section
      id="install"
      className="mx-auto max-w-5xl scroll-mt-24 px-4 py-20 sm:px-6"
    >
      <div className="card-glass relative overflow-hidden rounded-3xl border border-white/10 p-8 sm:p-10">
        <div className="absolute -right-20 -top-20 h-64 w-64 rounded-full bg-fuchsia-500/10 blur-3xl" />
        <h2 className="relative text-2xl font-bold tracking-tight text-white sm:text-3xl">
          Install in minutes
        </h2>
        <p className="relative mt-2 max-w-2xl text-slate-400">
          Same flow as the docs: download, drag, launch — then allow macOS
          if prompted.
        </p>
        <ol className="relative mt-8 space-y-6">
          {steps.map((s) => (
            <li key={s.n} className="flex gap-4">
              <span
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-cyan-500/20 font-mono text-sm font-bold text-cyan-200 ring-1 ring-cyan-500/40"
                aria-hidden
              >
                {s.n}
              </span>
              <div>
                <h3 className="font-semibold text-slate-100">{s.title}</h3>
                <p className="mt-1 text-slate-400">{s.body}</p>
              </div>
            </li>
          ))}
        </ol>
        <div className="relative mt-10 flex flex-wrap gap-3">
          <a
            href={href}
            className="btn-primary"
            {...(isExternal
              ? { target: "_blank", rel: "noreferrer" }
              : { "aria-label": "Get DMG" })}
          >
            Download DMG
          </a>
          {site.githubUrl ? (
            <a
              href={`${site.githubUrl}/releases`}
              className="inline-flex min-h-11 min-w-[44px] items-center justify-center rounded-full border border-white/15 bg-white/5 px-6 text-sm font-medium text-slate-200 transition hover:border-fuchsia-500/40"
              target="_blank"
              rel="noreferrer"
            >
              All releases
            </a>
          ) : null}
        </div>
        <p className="relative mt-4 text-sm text-slate-500">
          Without a public DMG URL, set{" "}
          <code className="code-inline">NEXT_PUBLIC_DOWNLOAD_DMG</code> in{" "}
          <code className="code-inline">website/.env.local</code>.
        </p>
      </div>
    </section>
  );
}
