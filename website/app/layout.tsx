import type { Metadata, Viewport } from "next";
import { Space_Grotesk, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { site } from "@/lib/site";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin"],
  display: "swap",
});

const title = `${site.name} — Local voice-to-text for macOS`;
const description = site.description;

export const metadata: Metadata = {
  title: { default: title, template: `%s · ${site.name}` },
  description,
  keywords: [
    "FloatingRecorder",
    "macOS",
    "Whisper",
    "voice to text",
    "local transcription",
    "accessibility",
    "hotkey",
  ],
  metadataBase: process.env.NEXT_PUBLIC_SITE_URL
    ? new URL(process.env.NEXT_PUBLIC_SITE_URL)
    : undefined,
  openGraph: {
    title,
    description,
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
  },
  robots: { index: true, follow: true },
  alternates: process.env.NEXT_PUBLIC_SITE_URL
    ? { canonical: process.env.NEXT_PUBLIC_SITE_URL }
    : undefined,
};

export const viewport: Viewport = {
  themeColor: "#020617",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <body
        className={`${spaceGrotesk.className} ${jetbrainsMono.variable} min-h-screen bg-slate-950 antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
