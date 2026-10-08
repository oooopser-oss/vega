import Image from "next/image";
import { ShieldCheck, ClipboardText, Truck, MapPin, Wrench } from "@phosphor-icons/react/ssr";
import { Container } from "@/components/ui/Container";
import { Reveal } from "@/components/Reveal";

const items = [
  { icon: MapPin, title: "Бесплатный выезд инженера", text: "Оцениваем грунт и участок до того, как вы платите." },
  { icon: ShieldCheck, title: "Гарантия до 5 лет", text: "На оборудование и 2 года на монтажные работы." },
  { icon: ClipboardText, title: "Рассрочка без банка", text: "До 6 месяцев без процентов при взносе от 50%." },
  { icon: Truck, title: "Доставка включена", text: "Собственный транспорт с манипулятором по области." },
];

export function Advantages() {
  return (
    <section className="py-16 sm:py-20">
      <Container>
        <Reveal>
          <h2 className="max-w-lg text-3xl sm:text-4xl">Почему выбирают нашу бригаду</h2>
        </Reveal>

        <div className="mt-10 grid gap-4 lg:grid-cols-[1.2fr_1fr_1fr] lg:grid-rows-2">
          <Reveal className="lg:row-span-2">
            <div className="relative flex h-full min-h-[320px] flex-col justify-end overflow-hidden rounded-card p-7 text-white">
              <Image
                src="/images/install-team.jpg"
                alt="Монтажная бригада устанавливает станцию очистки"
                fill
                sizes="(min-width: 1024px) 35vw, 100vw"
                className="object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-ink-950/80 via-ink-950/10 to-transparent" />
              <div className="relative">
                <span className="flex h-11 w-11 items-center justify-center rounded-full bg-white/15">
                  <Wrench size={22} weight="regular" />
                </span>
                <h3 className="mt-4 text-xl text-white">Своя монтажная бригада</h3>
                <p className="mt-2 text-sm text-white/80">
                  Без подрядчиков: от земляных работ до пусконаладки в одном договоре с одной командой.
                </p>
              </div>
            </div>
          </Reveal>

          {items.map((item, i) => (
            <Reveal key={item.title} delay={i * 80}>
              <div className="card flex h-full flex-col p-6">
                <span className="flex h-11 w-11 items-center justify-center rounded-full bg-brand-50 text-brand-700">
                  <item.icon size={22} weight="regular" />
                </span>
                <h3 className="mt-4 text-lg">{item.title}</h3>
                <p className="mt-2 text-sm text-ink-600">{item.text}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </Container>
    </section>
  );
}
