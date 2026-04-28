/**
 * Set NEXT_PUBLIC_GITHUB_URL and/or NEXT_PUBLIC_DOWNLOAD_DMG in .env.local
 * for live CTAs. Defaults keep CTAs in-page (scroll) until you host releases.
 */
export const site = {
  name: "FloatingRecorder",
  tagline: "Your voice, transcribed. On your Mac. Nothing in the cloud.",
  description:
    "A floating, hotkey-driven voice-to-text recorder for macOS. Local Whisper — no account, no telemetry.",
  // e.g. https://github.com/yourname/Floatingrecorder
  githubUrl: process.env.NEXT_PUBLIC_GITHUB_URL ?? "",
  // Direct link to DMG, or your releases "latest" asset URL
  downloadDmgUrl: process.env.NEXT_PUBLIC_DOWNLOAD_DMG ?? "",
  macOSMin: "14+",
} as const;

export function getDownloadHref(): string {
  if (site.downloadDmgUrl) return site.downloadDmgUrl;
  return "#install";
}
