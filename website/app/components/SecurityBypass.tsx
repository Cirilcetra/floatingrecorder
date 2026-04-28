export function SecurityBypass() {
  return (
    <section
      id="security"
      className="mx-auto max-w-5xl scroll-mt-24 px-4 py-20 sm:px-6"
    >
      <div className="text-center sm:text-left">
        <h2 className="text-2xl font-bold tracking-tight text-white sm:text-3xl">
          First launch: Apple’s security message
        </h2>
        <p className="mt-2 max-w-2xl text-slate-400">
          FloatingRecorder is distributed as a signed (ad-hoc) DMG. Because it
          is not notarized by Apple, macOS may show a <strong>one-time</strong>{" "}
          warning. This is expected for many indie Mac apps. Here’s how to
          allow it safely.
        </p>
      </div>

      <div className="mt-10 grid gap-6 lg:grid-cols-2">
        <div className="card-glass rounded-2xl p-6 sm:p-8">
          <h3 className="text-lg font-semibold text-amber-200/90">
            What you might see
          </h3>
          <ul className="mt-4 space-y-3 text-sm text-slate-300">
            <li className="rounded-lg border border-white/10 bg-slate-900/50 p-3">
              <q className="text-slate-200">
                &ldquo;FloatingRecorder&rdquo; cannot be opened because Apple
                cannot check it for malicious software.
              </q>
            </li>
            <li className="rounded-lg border border-white/10 bg-slate-900/50 p-3">
              <q className="text-slate-200">
                &ldquo;FloatingRecorder&rdquo; is damaged and can&apos;t be
                opened.
              </q>{" "}
              <span className="text-slate-500">(older macOS phrasing)</span>
            </li>
          </ul>
        </div>

        <div className="card-glass rounded-2xl p-6 sm:p-8 ring-1 ring-cyan-500/20">
          <h3 className="text-lg font-semibold text-cyan-200">
            The easy way (macOS 15 Sequoia and later)
          </h3>
          <ol className="mt-4 list-decimal space-y-3 pl-5 text-sm text-slate-300">
            <li>
              Try to open <strong className="text-slate-100">FloatingRecorder</strong>{" "}
              once. Dismiss the warning.
            </li>
            <li>
              Open <strong>System Settings</strong> →{" "}
              <strong>Privacy &amp; Security</strong>.
            </li>
            <li>
              Scroll to the <strong>Security</strong> section. You should see:{" "}
              <q className="text-slate-200">
                &ldquo;FloatingRecorder&rdquo; was blocked to protect your Mac.
              </q>
            </li>
            <li>
              Click <strong className="text-cyan-200">Open Anyway</strong>.
            </li>
            <li>Confirm with Touch ID or your password.</li>
            <li>
              The app launches — look for the microphone icon in your menu bar.
            </li>
          </ol>
        </div>
      </div>

      <div className="mt-6 card-glass rounded-2xl p-6 sm:p-8">
        <h3 className="text-lg font-semibold text-slate-100">
          Alternative: right-click → Open
        </h3>
        <ol className="mt-4 list-decimal space-y-2 pl-5 text-sm text-slate-300">
          <li>Open <strong>Applications</strong>.</li>
          <li>
            <strong>Right-click</strong> (or Control-click){" "}
            <strong>FloatingRecorder.app</strong>.
          </li>
          <li>Choose <strong>Open</strong> from the menu.</li>
          <li>
            You get the same warning, but with an <strong>Open</strong> button —
            click it.
          </li>
          <li>Confirm with Touch ID or your password.</li>
        </ol>
      </div>

      <details className="mt-6 group card-glass rounded-2xl p-1 open:ring-1 open:ring-fuchsia-500/30">
        <summary className="cursor-pointer list-none rounded-xl px-5 py-4 font-medium text-slate-200 transition hover:bg-white/5 [&::-webkit-details-marker]:hidden">
          <span className="inline-flex w-full items-center justify-between gap-2">
            Advanced: if the app says &ldquo;is damaged&rdquo;
            <span
              className="text-fuchsia-300/80 transition group-open:rotate-180"
              aria-hidden
            >
              ▼
            </span>
          </span>
        </summary>
        <div className="border-t border-white/10 px-5 pb-5 pt-1 text-sm text-slate-400">
          <p className="pt-2">
            This can happen if macOS handled the quarantine attribute
            unexpectedly. You can:
          </p>
          <p className="mt-3 font-medium text-slate-200">
            Option A — helper in the DMG
          </p>
          <p className="mt-1">
            Double-click <code className="code-inline">Fix Security Warning.command</code> in
            the disk image; it will prompt for your password and unblock the
            app.
          </p>
          <p className="mt-4 font-medium text-slate-200">Option B — Terminal</p>
          <pre className="mt-2 overflow-x-auto rounded-xl border border-white/10 bg-slate-950/80 p-4 font-mono text-xs text-cyan-200/90">
            xattr -dr com.apple.quarantine /Applications/FloatingRecorder.app
          </pre>
          <p className="mt-2">Then open FloatingRecorder normally.</p>
        </div>
      </details>
    </section>
  );
}
