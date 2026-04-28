import type { ReactNode } from "react";

const items: { q: string; a: ReactNode }[] = [
  {
    q: "Why does macOS say the app can’t be checked?",
    a: "The Mac App Store and Apple notarization are optional; many open-source and indie tools ship ad-hoc signed, like FloatingRecorder. macOS is cautious on first run — you transparently allow it once in Privacy & Security.",
  },
  {
    q: "Does my audio leave this Mac?",
    a: "No. Transcription uses Whisper on-device. There’s no account and no cloud pipeline for your speech in the app’s design.",
  },
  {
    q: "What hotkey does it use by default?",
    a: "Option + Command (⌥⌘). Tap to toggle recording; hold for push-to-talk, release to transcribe and auto-paste into the focused text field (or copy if there’s no field).",
  },
  {
    q: "How do I verify the download?",
    a: (
      <>
        <p>
          Next to the DMG you should have <code className="code-inline">FloatingRecorder.dmg.sha256</code>.
          Compare it to a local hash:
        </p>
        <pre className="mt-3 overflow-x-auto rounded-xl border border-white/10 bg-slate-950/80 p-3 font-mono text-xs text-cyan-200/90">
          shasum -a 256 ~/Downloads/FloatingRecorder.dmg
        </pre>
        <p className="mt-2">
          The hashes must match. If not, do not open the DMG and report the issue.
        </p>
      </>
    ),
  },
];

export function FAQ() {
  return (
    <section
      id="faq"
      className="mx-auto max-w-5xl scroll-mt-24 px-4 py-20 sm:px-6"
    >
      <h2 className="text-2xl font-bold tracking-tight text-white sm:text-3xl">
        FAQ
      </h2>
      <p className="mt-2 text-slate-400">Quick answers before you install.</p>
      <div className="mt-8 space-y-3">
        {items.map((item) => (
          <details
            key={item.q}
            className="group card-glass rounded-2xl open:ring-1 open:ring-cyan-500/25"
          >
            <summary className="flex cursor-pointer list-none items-center justify-between gap-4 rounded-2xl px-5 py-4 text-left font-medium text-slate-100 transition hover:bg-white/5 [&::-webkit-details-marker]:hidden">
              {item.q}
              <span
                className="shrink-0 text-slate-500 transition group-open:rotate-180"
                aria-hidden
              >
                ▼
              </span>
            </summary>
            <div className="border-t border-white/10 px-5 pb-4 pt-0 text-sm text-slate-400">
              {typeof item.a === "string" ? (
                <p className="pt-3 leading-relaxed">{item.a}</p>
              ) : (
                <div className="space-y-2 pt-3 leading-relaxed [&_p]:text-slate-400">
                  {item.a}
                </div>
              )}
            </div>
          </details>
        ))}
      </div>
    </section>
  );
}
