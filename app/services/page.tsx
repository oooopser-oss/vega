import type { Metadata } from "next";
import { Container } from "@/components/ui/Container";
import { ServiceCard } from "@/components/ServiceCard";
import { services } from "@/data/services";

export const metadata: Metadata = {
  title: "Услуги",
  description: "Выезд инженера, монтаж, доставка, сервисное обслуживание и рассрочка на септики и станции глубокой очистки.",
};

export default function ServicesPage() {
  return (
    <section className="py-12 sm:py-16">
      <Container>
        <h1 className="text-3xl sm:text-4xl">Услуги</h1>
        <p className="mt-3 max-w-2xl text-ink-600">
          Весь цикл работ своей бригадой: от выезда инженера до сервисного обслуживания после
          монтажа.
        </p>

        <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {services.map((service) => (
            <div key={service.slug} id={service.slug}>
              <ServiceCard service={service} />
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
