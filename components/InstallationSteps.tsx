import { Container } from "@/components/ui/Container";
import { Reveal } from "@/components/Reveal";

const steps = [
  { title: "Выезд инженера", text: "Оцениваем грунт, уровень грунтовых вод и расположение участка." },
  { title: "Расчёт и договор", text: "Фиксируем модель, сроки и полную стоимость без скрытых доплат." },
  { title: "Доставка и монтаж", text: "Привозим оборудование и устанавливаем своей бригадой за 1-3 дня." },
  { title: "Пусконаладка", text: "Запускаем станцию и показываем, как ей пользоваться и обслуживать." },
];

export function InstallationSteps() {
  return (
    <section className="py-16 sm:py-20">
      <Container>
        <Reveal>
          <h2 className="max-w-lg text-3xl sm:text-4xl">Как проходит установка</h2>
        </Reveal>

        <div className="mt-10 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((step, i) => (
            <Reveal key={step.title} delay={i * 80}>
              <div className="border-t-2 border-brand-600 pt-5">
                <p className="font-display text-2xl text-ink-300">{String(i + 1).padStart(2, "0")}</p>
                <h3 className="mt-2 text-lg">{step.title}</h3>
                <p className="mt-2 text-sm text-ink-600">{step.text}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </Container>
    </section>
  );
}
