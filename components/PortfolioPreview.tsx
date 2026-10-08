import Link from "next/link";
import { Container } from "@/components/ui/Container";
import { Reveal } from "@/components/Reveal";
import { portfolio } from "@/data/portfolio";

export function PortfolioPreview() {
  return (
    <section className="bg-ink-50/60 py-16 sm:py-20">
      <Container>
        <Reveal className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <h2 className="max-w-lg text-3xl sm:text-4xl">Последние проекты</h2>
          <Link href="/portfolio" className="btn-outline self-start sm:self-auto">
            Все работы
          </Link>
        </Reveal>

        <div className="mt-10 flex snap-x gap-5 overflow-x-auto pb-2 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {portfolio.map((item) => (
            <Link
              key={item.slug}
              href="/portfolio"
              className="card w-[280px] shrink-0 snap-start p-6"
            >
              <p className="text-xs font-semibold uppercase tracking-wide text-ink-400">
                {item.city} · {item.durationDays} {item.durationDays === 1 ? "день" : "дня"}
              </p>
              <h3 className="mt-2 text-base">{item.title}</h3>
              <p className="mt-2 text-sm text-ink-600">{item.description}</p>
            </Link>
          ))}
        </div>
      </Container>
    </section>
  );
}
