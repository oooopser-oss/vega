import type { Metadata } from "next";
import { Container } from "@/components/ui/Container";
import { ProductCard } from "@/components/ProductCard";
import { Reveal } from "@/components/Reveal";
import { products } from "@/data/products";

export const metadata: Metadata = {
  title: "Каталог септиков и станций глубокой очистки",
  description: "Накопительные септики и станции глубокой очистки Тритон, Топас, Евробион, Малахит, КИТ, Евролос с доставкой и монтажом.",
};

export default function CatalogPage() {
  return (
    <section className="py-12 sm:py-16">
      <Container>
        <h1 className="text-3xl sm:text-4xl">Каталог септиков</h1>
        <p className="mt-3 max-w-2xl text-ink-600">
          12 моделей от проверенных производителей. Поможем подобрать станцию под грунт, бюджет и
          количество пользователей.
        </p>

        <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {products.map((product, i) => (
            <Reveal key={product.slug} delay={(i % 3) * 80}>
              <ProductCard product={product} />
            </Reveal>
          ))}
        </div>
      </Container>
    </section>
  );
}
