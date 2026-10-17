import Image from "next/image";
import { Container } from "@/components/ui/Container";
import { HeroActions } from "@/components/HeroActions";

export function Hero() {
  return (
    <section className="bg-white pt-10 sm:pt-16">
      <Container>
        <div className="grid gap-10 pb-12 lg:grid-cols-[1.05fr_0.95fr] lg:items-center lg:gap-16 lg:pb-16">
          <div>
            <h1 className="max-w-xl text-4xl sm:text-5xl lg:text-6xl">
              Септик под ключ за 1-3 дня
            </h1>
            <p className="mt-5 max-w-md text-base leading-relaxed text-ink-600 sm:text-lg">
              Подбираем станцию под грунт и бюджет, монтируем своей бригадой и даём гарантию
              до 5 лет.
            </p>
            <HeroActions />
          </div>

          <div className="relative aspect-[4/3] w-full overflow-hidden rounded-card lg:aspect-[5/4]">
            <Image
              src="/images/hero-house.jpg"
              alt="Частный дом с установленной станцией очистки на участке"
              fill
              priority
              sizes="(min-width: 1024px) 45vw, 100vw"
              className="object-cover"
            />
          </div>
        </div>
      </Container>
    </section>
  );
}
