import { Hero } from "@/components/Hero";
import { TrustStrip } from "@/components/TrustStrip";
import { Advantages } from "@/components/Advantages";
import { CatalogPreview } from "@/components/CatalogPreview";
import { InstallationSteps } from "@/components/InstallationSteps";
import { CalculatorSection } from "@/components/CalculatorSection";
import { PortfolioPreview } from "@/components/PortfolioPreview";
import { ReviewsPreview } from "@/components/ReviewsPreview";
import { CTASection } from "@/components/CTASection";

export default function HomePage() {
  return (
    <>
      <Hero />
      <TrustStrip />
      <CatalogPreview />
      <Advantages />
      <InstallationSteps />
      <CalculatorSection />
      <PortfolioPreview />
      <ReviewsPreview />
      <CTASection />
    </>
  );
}
