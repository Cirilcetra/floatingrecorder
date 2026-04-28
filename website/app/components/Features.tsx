const features = [
  {
    title: "Local Whisper",
    body: "Transcription runs on your Mac. Nothing is uploaded. Pick models on demand: Tiny through Large v3.",
    icon: "◎",
  },
  {
    title: "One hotkey, two modes",
    body: "Tap ⌥⌘ to toggle recording. Hold ⌥⌘ for push-to-talk: release to transcribe and paste.",
    icon: "⌥⌘",
  },
  {
    title: "Smart auto-paste",
    body: "Jumps back to your text field and pastes via the Accessibility API — or copies to clipboard if there’s no field.",
    icon: "↪",
  },
  {
    title: "Float & focus",
    body: "A minimal floating control next to the apps you use. Menu bar access for models, hotkeys, and history.",
    icon: "◇",
  },
] as const;

export function Features() {
  return (
    <section
      id="features"
      className="mx-auto max-w-5xl scroll-mt-24 px-4 py-20 sm:px-6"
    >
      <div className="text-center sm:text-left">
        <h2 className="text-2xl font-bold tracking-tight text-white sm:text-3xl">
          Built for flow
        </h2>
        <p className="mt-2 max-w-2xl text-slate-400">
          A native-feeling tool that stays out of the way — until you need it.
        </p>
      </div>
      <div className="mt-12 grid gap-4 sm:grid-cols-2">
        {features.map((f) => (
          <div
            key={f.title}
            className="card-glass group rounded-2xl p-6 transition duration-300 hover:border-cyan-500/30"
          >
            <div
              className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-cyan-500/20 to-fuchsia-600/20 font-mono text-cyan-200 ring-1 ring-white/10"
              aria-hidden
            >
              {f.icon}
            </div>
            <h3 className="text-lg font-semibold text-slate-100">{f.title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-slate-400">
              {f.body}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}
