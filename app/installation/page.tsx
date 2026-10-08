import type { Metadata } from "next";
import Image from "next/image";
import { Container } from "@/components/ui/Container";
import { InstallationSteps } from "@/components/InstallationSteps";
import { FaqAccordion } from "@/components/FaqAccordion";
import { InstallationCta } from "@/components/InstallationCta";
import { faq } from "@/data/faq";

export const metadata: Metadata = {
  title: "Установка септика под ключ",
  description: "Монтаж септиков и станций глубокой очистки под ключ: выезд инженера, земляные работы, доставка, пусконаладка.",
};

export default function InstallationPage() {
  return (
    <>
      <section className="py-12 sm:py-16">
        <Container>
          <div className="grid gap-10 lg:grid-cols-[1fr_0.9fr] lg:items-center lg:gap-16">
            <div>
              <h1 className="max-w-lg text-3xl sm:text-4xl">Монтаж под ключ своей бригадой</h1>
              <p className="mt-4 max-w-md text-ink-600">
                От выезда инженера до пусконаладки. Один договор, фиксированная цена, гарантия на
                работы 2 года.
              </p>
              <InstallationCta />
            </div>
            <div className="relative aspect-[4/3] w-full overflow-hidden rounded-card">
              <Image
                src="/images/install-team.jpg"
                alt="Монтажники устанавливают септик на участке"
                fill
                sizes="(min-width: 1024px) 45vw, 100vw"
                className="object-cover"
              />
            </div>
          </div>
        </Container>
      </section>

      <InstallationSteps />

      <section className="py-16 sm:py-20">
        <Container className="max-w-3xl">
          <h2 className="text-3xl sm:text-4xl">Частые вопросы</h2>
          <div className="mt-8">
            <FaqAccordion items={faq} />
          </div>
        </Container>
      </section>
    </>
  );
}
