import type { Metadata } from "next";
import Image from "next/image";
import { Container } from "@/components/ui/Container";
import { siteConfig } from "@/config/site";

export const metadata: Metadata = {
  title: "О компании",
  description: "СептикДом: своя монтажная бригада, работаем в Екатеринбурге и области.",
};

const stats = [
  { value: "600+", label: "смонтированных станций" },
  { value: "8 лет", label: "на рынке автономной канализации" },
  { value: "6", label: "брендов оборудования в наличии" },
];

export default function AboutPage() {
  return (
    <section className="py-12 sm:py-16">
      <Container>
        <div className="grid gap-10 lg:grid-cols-[1fr_0.9fr] lg:items-center lg:gap-16">
          <div>
            <h1 className="max-w-lg text-3xl sm:text-4xl">О компании</h1>
            <p className="mt-4 max-w-md text-ink-600">
              {siteConfig.legalName} занимается продажей и монтажом автономной канализации в
              {` ${siteConfig.region.fullLabelPrepositional}`}. Работаем своей бригадой, без
              субподрядчиков.
            </p>
            <p className="mt-4 max-w-md text-ink-600">
              Подбираем оборудование под конкретный участок, а не продаём то, что есть на складе.
            </p>
          </div>
          <div className="relative aspect-[4/3] w-full overflow-hidden rounded-card">
            <Image
              src="/images/install-team.jpg"
              alt="Монтажная бригада СептикДом на объекте"
              fill
              sizes="(min-width: 1024px) 45vw, 100vw"
              className="object-cover"
            />
          </div>
        </div>

        <div className="mt-14 grid gap-8 border-t border-ink-100 pt-10 sm:grid-cols-3">
          {stats.map((stat) => (
            <div key={stat.label}>
              <p className="font-display text-3xl font-semibold text-ink-900">{stat.value}</p>
              <p className="mt-1 text-sm text-ink-500">{stat.label}</p>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
