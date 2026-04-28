import { getDownloadHref, site } from "@/lib/site";

export function Hero() {
  const href = getDownloadHref();
  const isExternal = href.startsWith("http");

  return (
    <section
      id="top"
      className="mx-auto max-w-5xl px-4 pb-20 pt-16 sm:px-6 sm:pt-24"
    >
      <p className="mb-4 inline-flex items-center gap-2 rounded-full border border-cyan-500/30 bg-cyan-500/10 px-3 py-1 text-xs font-medium tracking-wide text-cyan-200">
        macOS {site.macOSMin} · On-device · Open source
      </p>
      <h1 className="text-balance text-4xl font-bold leading-tight tracking-tight text-white sm:text-5xl sm:leading-tight">
        {site.tagline}
      </h1>
      <p className="mt-4 max-w-2xl text-pretty text-lg text-slate-400 sm:text-xl">
        Tap or hold a global hotkey, speak, and get Whisper transcriptions
        where you type — with no cloud, no account, and no telemetry.
      </p>
      <div className="mt-8 flex flex-wrap items-center gap-3">
        <a
          href={href}
          className="btn-primary"
          {...(isExternal
            ? { target: "_blank", rel: "noreferrer" }
            : { "aria-label": "Get the app" })}
        >
          Get FloatingRecorder
        </a>
        <a
          href="#install"
          className="inline-flex min-h-11 min-w-[44px] items-center justify-center rounded-full border border-white/15 bg-white/5 px-6 text-sm font-medium text-slate-200 backdrop-blur transition hover:border-cyan-500/40 hover:bg-white/10"
        >
          How to install
        </a>
      </div>
      <p className="mt-4 text-sm text-slate-500">
        Not notarized? macOS will ask once.{" "}
        <a
          className="text-cyan-400/90 underline decoration-cyan-500/40 underline-offset-4 hover:text-cyan-300"
          href="#security"
        >
          Allow in System Settings
        </a>{" "}
        — it takes about 20 seconds.
      </p>
    </section>
  );
}
