import { SiteNav } from "./components/SiteNav";
import { Hero } from "./components/Hero";
import { Features } from "./components/Features";
import { InstallSteps } from "./components/InstallSteps";
import { SecurityBypass } from "./components/SecurityBypass";
import { Permissions } from "./components/Permissions";
import { FAQ } from "./components/FAQ";
import { FinalCta } from "./components/FinalCta";
import { SiteFooter } from "./components/SiteFooter";
import { GradientMesh } from "./components/GradientMesh";

export default function Home() {
  return (
    <div className="relative min-h-screen">
      <GradientMesh />
      <SiteNav />
      <main>
        <Hero />
        <Features />
        <InstallSteps />
        <SecurityBypass />
        <Permissions />
        <FAQ />
        <FinalCta />
      </main>
      <SiteFooter />
    </div>
  );
}
