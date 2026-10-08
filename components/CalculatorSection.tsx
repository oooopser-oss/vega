import { Container } from "@/components/ui/Container";
import { SectionHeading } from "@/components/ui/SectionHeading";
import { Calculator } from "@/components/Calculator";
import { Reveal } from "@/components/Reveal";

export function CalculatorSection() {
  return (
    <section className="bg-ink-50/60 py-16 sm:py-20">
      <Container>
        <Reveal>
          <SectionHeading
            eyebrow="Онлайн-калькулятор"
            title="Рассчитайте стоимость за 1 минуту"
            description="Ответьте на несколько вопросов об участке и доме: покажем предварительную стоимость."
            align="center"
          />
        </Reveal>
        <div className="mt-10">
          <Calculator />
        </div>
      </Container>
    </section>
  );
}
