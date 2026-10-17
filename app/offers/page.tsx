import type { Metadata } from "next";
import { Container } from "@/components/ui/Container";
import { OfferCta } from "@/components/OfferCta";

export const metadata: Metadata = {
  title: "Акции",
  description: "Текущие акции на септики, станции глубокой очистки и монтаж.",
};

const offers = [
  {
    title: "Скидка на Евролос Про 8",
    text: "При заказе до конца месяца, станция Евролос Про 8 со скидкой 16 000 ₽ от обычной цены.",
  },
  {
    title: "Бесплатный выезд инженера",
    text: "При заявке через сайт выезд инженера для расчёта и оценки участка ничего не стоит.",
  },
  {
    title: "Рассрочка 0%",
    text: "Рассрочка на 6 месяцев без банка и без переплат при первом взносе от 50%.",
  },
];

export default function OffersPage() {
  return (
    <section className="py-12 sm:py-16">
      <Container>
        <h1 className="text-3xl sm:text-4xl">Акции</h1>

        <div className="mt-10 grid gap-6 sm:grid-cols-3">
          {offers.map((offer) => (
            <div key={offer.title} className="card p-6">
              <h2 className="text-lg">{offer.title}</h2>
              <p className="mt-2 text-sm text-ink-600">{offer.text}</p>
            </div>
          ))}
        </div>

        <OfferCta />
      </Container>
    </section>
  );
}
