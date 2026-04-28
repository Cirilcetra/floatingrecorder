export function Permissions() {
  return (
    <section
      id="permissions"
      className="mx-auto max-w-5xl scroll-mt-24 px-4 py-20 sm:px-6"
    >
      <h2 className="text-2xl font-bold tracking-tight text-white sm:text-3xl">
        Grant permissions
      </h2>
      <p className="mt-2 max-w-2xl text-slate-400">
        On first run, FloatingRecorder walks you through what it needs. If you
        miss a prompt, you can fix it in System Settings.
      </p>
      <div className="mt-10 grid gap-6 md:grid-cols-2">
        <div className="card-glass rounded-2xl p-6 sm:p-8">
          <h3 className="text-base font-semibold text-slate-100">Microphone</h3>
          <p className="mt-2 text-sm text-slate-400">
            macOS will ask — choose <strong className="text-slate-200">Allow</strong>. If
            you dismissed it, go to{" "}
            <strong>System Settings → Privacy &amp; Security → Microphone</strong> and
            enable <strong>FloatingRecorder</strong>.
          </p>
        </div>
        <div className="card-glass rounded-2xl p-6 sm:p-8 border-cyan-500/20">
          <h3 className="text-base font-semibold text-slate-100">
            Accessibility
          </h3>
          <p className="mt-1 text-xs uppercase tracking-wider text-cyan-500/80">
            Required for global hotkey + auto-paste
          </p>
          <ol className="mt-3 list-decimal space-y-2 pl-5 text-sm text-slate-400">
            <li>
              Open <strong>System Settings → Privacy &amp; Security → Accessibility</strong>.
            </li>
            <li>
              If you ever installed an older build, remove <strong>every</strong> old
              &ldquo;FloatingRecorder&rdquo; row with the <strong>minus (−)</strong> button
              first — otherwise macOS may toggle the wrong entry.
            </li>
            <li>
              Click <strong>+</strong>, pick <strong>FloatingRecorder</strong> from{" "}
              <strong>Applications</strong>, and turn the switch <strong>On</strong>.
            </li>
            <li>
              <strong>Quit and reopen</strong> FloatingRecorder. Trust updates only apply
              after a new launch, so the hotkey may not register until you
              relaunch.
            </li>
          </ol>
        </div>
      </div>
    </section>
  );
}
