export function GradientMesh() {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 -z-10 overflow-hidden"
    >
      <div className="absolute -left-1/4 top-0 h-[min(80vh,900px)] w-[min(80vw,900px)] rounded-full bg-[radial-gradient(closest-side,rgba(56,189,248,0.22),transparent)] blur-3xl motion-safe:animate-pulse-slow" />
      <div className="absolute -right-1/4 top-1/3 h-[min(70vh,800px)] w-[min(70vw,800px)] rounded-full bg-[radial-gradient(closest-side,rgba(168,85,247,0.2),transparent)] blur-3xl motion-safe:animate-pulse-slow" />
      <div className="absolute bottom-0 left-1/3 h-[50vh] w-[100vw] rounded-full bg-[radial-gradient(closest-side,rgba(34,211,238,0.12),transparent)] blur-3xl" />
      <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(2,6,12,0)_0%,#020617_88%)]" />
    </div>
  );
}
