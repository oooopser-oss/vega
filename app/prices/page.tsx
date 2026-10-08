import type { Metadata } from "next";
import { Container } from "@/components/ui/Container";
import { formatPrice } from "@/lib/format";
import { priceGroups } from "@/data/prices";
import { PricesCta } from "@/components/PricesCta";

export const metadata: Metadata = {
  title: "Цены на септики и монтаж",
  description: "Цены на оборудование, монтажные работы и сервисное обслуживание септиков и станций глубокой очистки.",
};

export default function PricesPage() {
  return (
    <section className="py-12 sm:py-16">
      <Container className="max-w-3xl">
        <h1 className="text-3xl sm:text-4xl">Цены</h1>
        <p className="mt-3 text-ink-600">
          Ориентировочные цены. Точную стоимость считаем после выезда инженера и оценки участка.
        </p>

        <div className="mt-10 space-y-10">
          {priceGroups.map((group) => (
            <div key={group.title}>
              <h2 className="text-xl">{group.title}</h2>
              <div className="mt-3 divide-y divide-ink-100 border-y border-ink-100">
                {group.rows.map((row) => (
                  <div key={row.name} className="flex items-center justify-between py-3 text-sm">
                    <span className="text-ink-700">{row.name}</span>
                    <span className="font-semibold text-ink-900">
                      от {formatPrice(row.priceFrom)} / {row.unit}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>

        <PricesCta />
      </Container>
    </section>
  );
}
