import { Container } from "@/components/ui/Container";
import { HeroActions } from "@/components/HeroActions";
import { HeroParallaxImage } from "@/components/HeroParallaxImage";
import { formatPrice } from "@/lib/format";
import { products } from "@/data/products";

export function Hero() {
  const minPrice = Math.min(...products.map((p) => p.price));

  return (
    <section className="bg-white pt-10 sm:pt-16">
      <Container>
        <div className="grid gap-10 pb-12 lg:grid-cols-[1.05fr_0.95fr] lg:items-center lg:gap-16 lg:pb-16">
          <div>
            <h1 className="max-w-xl text-5xl sm:text-6xl lg:text-7xl">
              Септик под ключ за 1-3 дня
            </h1>
            <p className="mt-5 max-w-md text-base leading-relaxed text-ink-600 sm:text-lg">
              Подбираем станцию под грунт и бюджет, монтируем своей бригадой и даём гарантию
              до 5 лет.
            </p>
            <p className="mt-3 text-sm text-ink-500">
              Септики и станции от <span className="font-semibold text-ink-900">{formatPrice(minPrice)}</span> с доставкой
            </p>
            <HeroActions />
          </div>

          <HeroParallaxImage />
        </div>
      </Container>
    </section>
  );
}
