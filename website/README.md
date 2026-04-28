# FloatingRecorder marketing site

Next.js 15 (App Router) + Tailwind CSS v4. One-page product site with install steps and Apple security bypass instructions.

## Develop

```bash
cd website
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Build

```bash
npm run build
npm start
```

## Environment

Copy `.env.example` to `.env.local` and set any of:

- `NEXT_PUBLIC_SITE_URL` — production base URL (metadata / canonical)
- `NEXT_PUBLIC_DOWNLOAD_DMG` — direct DMG link for Download CTAs
- `NEXT_PUBLIC_GITHUB_URL` — enables Source + Releases links

## Deploy

Host like any static-friendly Node host, or use `output: "export"` in `next.config.ts` if you need a fully static export (optional follow-up).
