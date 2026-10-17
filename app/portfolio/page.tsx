import type { Metadata } from "next";
import { Container } from "@/components/ui/Container";
import { Reveal } from "@/components/Reveal";
import { portfolio } from "@/data/portfolio";

export const metadata: Metadata = {
  title: "Наши работы",
  description: "Примеры монтажа септиков и станций глубокой очистки в Екатеринбурге и области.",
};

export default function PortfolioPage() {
  return (
    <section className="py-12 sm:py-16">
      <Container>
        <h1 className="text-3xl sm:text-4xl">Наши работы</h1>
        <p className="mt-3 max-w-2xl text-ink-600">
          Реальные объекты: от дачных накопительных септиков до станций глубокой очистки для
          больших домов.
        </p>

        <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {portfolio.map((item, i) => (
            <Reveal key={item.slug} delay={(i % 3) * 80}>
              <div className="card p-6">
                <p className="text-sm font-medium text-ink-500">
                  {item.city} · {item.durationDays} {item.durationDays === 1 ? "день" : "дня"}
                </p>
                <h2 className="mt-2 text-lg">{item.title}</h2>
                <p className="mt-2 text-sm text-ink-600">{item.description}</p>
                <p className="mt-4 text-sm font-semibold text-brand-700">{item.productBrand}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </Container>
    </section>
  );
}
