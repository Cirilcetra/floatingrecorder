import { site } from "@/lib/site";

const year = new Date().getFullYear();

export function SiteFooter() {
  return (
    <footer className="border-t border-white/10 bg-slate-950/80">
      <div className="mx-auto flex max-w-5xl flex-col items-center justify-between gap-4 px-4 py-10 text-sm text-slate-500 sm:flex-row sm:px-6">
        <p>
          © {year} {site.name}. macOS app — local speech, your machine.
        </p>
        <div className="flex flex-wrap items-center justify-center gap-4">
          <a
            className="hover:text-cyan-400/90"
            href="#install"
          >
            Install
          </a>
          <a
            className="hover:text-cyan-400/90"
            href="#security"
          >
            Security
          </a>
          {site.githubUrl ? (
            <a
              className="hover:text-cyan-400/90"
              href={site.githubUrl}
              target="_blank"
              rel="noreferrer"
            >
              GitHub
            </a>
          ) : null}
        </div>
      </div>
    </footer>
  );
}
