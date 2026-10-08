"use client";

import { useState } from "react";
import { useLeadModal } from "@/components/LeadModalProvider";
import { formatPrice } from "@/lib/format";

interface CalculatorAnswers {
  residents: string;
  usage: string;
  bath: string;
  bathrooms: string;
  soil: string;
  groundwater: string;
  turnkey: string;
  district: string;
}

const initialAnswers: CalculatorAnswers = {
  residents: "",
  usage: "",
  bath: "",
  bathrooms: "",
  soil: "",
  groundwater: "",
  turnkey: "",
  district: "",
};

interface StepConfig {
  key: keyof CalculatorAnswers;
  question: string;
  options?: { value: string; label: string }[];
  isText?: boolean;
}

const steps: StepConfig[] = [
  {
    key: "residents",
    question: "Сколько человек постоянно проживает в доме?",
    options: [
      { value: "1-2", label: "1-2 человека" },
      { value: "3-4", label: "3-4 человека" },
      { value: "5-6", label: "5-6 человек" },
      { value: "7+", label: "7 и более" },
    ],
  },
  {
    key: "usage",
    question: "Дом используется постоянно или сезонно?",
    options: [
      { value: "permanent", label: "Постоянно" },
      { value: "seasonal", label: "Сезонно (дача)" },
    ],
  },
  {
    key: "bath",
    question: "Есть ли ванна?",
    options: [
      { value: "yes", label: "Да" },
      { value: "no", label: "Нет" },
    ],
  },
  {
    key: "bathrooms",
    question: "Сколько санузлов?",
    options: [
      { value: "1", label: "1 санузел" },
      { value: "2", label: "2 санузла" },
      { value: "3+", label: "3 и более" },
    ],
  },
  {
    key: "soil",
    question: "Какой тип грунта на участке?",
    options: [
      { value: "sand", label: "Песчаный" },
      { value: "clay", label: "Глинистый" },
      { value: "rock", label: "Скалистый" },
      { value: "unknown", label: "Не знаю" },
    ],
  },
  {
    key: "groundwater",
    question: "Высокий или низкий уровень грунтовых вод?",
    options: [
      { value: "high", label: "Высокий" },
      { value: "low", label: "Низкий" },
      { value: "unknown", label: "Не знаю" },
    ],
  },
  {
    key: "turnkey",
    question: "Нужна ли установка под ключ?",
    options: [
      { value: "yes", label: "Да, нужна установка" },
      { value: "no", label: "Нет, только оборудование" },
    ],
  },
  {
    key: "district",
    question: "Где находится участок?",
    isText: true,
  },
];

function calculatePrice(answers: CalculatorAnswers): number {
  const residentsBase: Record<string, number> = {
    "1-2": 58000,
    "3-4": 79000,
    "5-6": 118000,
    "7+": 156000,
  };

  let price = residentsBase[answers.residents] ?? 79000;

  if (answers.bath === "yes") price += 12000;
  if (answers.bathrooms === "2") price += 10000;
  if (answers.bathrooms === "3+") price += 20000;
  if (answers.soil === "rock") price += 20000;
  if (answers.soil === "clay") price += 8000;
  if (answers.groundwater === "high") price += 15000;
  if (answers.turnkey === "yes") price += 35000;
  if (answers.usage === "seasonal") price -= 8000;

  return Math.max(Math.round(price / 1000) * 1000, 45000);
}

function labelFor(key: keyof CalculatorAnswers, value: string): string {
  const step = steps.find((s) => s.key === key);
  return step?.options?.find((option) => option.value === value)?.label ?? "не указано";
}

function summarizeAnswers(answers: CalculatorAnswers): string {
  return [
    `Проживает: ${labelFor("residents", answers.residents)}`,
    `Тип проживания: ${labelFor("usage", answers.usage)}`,
    `Ванна: ${answers.bath === "yes" ? "есть" : "нет"}`,
    `Санузлов: ${labelFor("bathrooms", answers.bathrooms)}`,
    `Грунт: ${labelFor("soil", answers.soil)}`,
    `Грунтовые воды: ${labelFor("groundwater", answers.groundwater)}`,
    `Установка под ключ: ${answers.turnkey === "yes" ? "нужна" : "не нужна"}`,
  ].join("; ");
}

export function Calculator() {
  const [stepIndex, setStepIndex] = useState(0);
  const [answers, setAnswers] = useState<CalculatorAnswers>(initialAnswers);
  const { openLeadModal } = useLeadModal();

  const isFinished = stepIndex >= steps.length;
  const currentStep = steps[stepIndex];

  function selectOption(value: string) {
    setAnswers((prev) => ({ ...prev, [currentStep.key]: value }));
    setStepIndex((prev) => prev + 1);
  }

  function goBack() {
    setStepIndex((prev) => Math.max(prev - 1, 0));
  }

  function restart() {
    setAnswers(initialAnswers);
    setStepIndex(0);
  }

  const price = isFinished ? calculatePrice(answers) : 0;

  return (
    <div className="mx-auto max-w-2xl rounded-card border border-ink-100 bg-white p-6 shadow-card sm:p-10">
      {!isFinished ? (
        <>
          <div className="mb-6 flex items-center gap-2">
            {steps.map((_, i) => (
              <div key={i} className={`h-1 flex-1 rounded-full ${i <= stepIndex ? "bg-brand-600" : "bg-ink-100"}`} />
            ))}
          </div>
          <p className="mb-1 text-sm font-medium text-ink-400">
            Шаг {stepIndex + 1} из {steps.length}
          </p>
          <h3 className="mb-6 text-2xl">{currentStep.question}</h3>

          {currentStep.isText ? (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                setStepIndex((prev) => prev + 1);
              }}
              className="flex flex-col gap-4"
            >
              <label htmlFor="calc-district" className="field-label">
                Город или район
              </label>
              <input
                id="calc-district"
                className="field-input"
                placeholder="Например, Кольцово"
                value={answers.district}
                onChange={(e) => setAnswers((prev) => ({ ...prev, district: e.target.value }))}
              />
              <button type="submit" className="btn-primary">
                Показать предварительную стоимость
              </button>
            </form>
          ) : (
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              {currentStep.options?.map((option) => (
                <button
                  key={option.value}
                  onClick={() => selectOption(option.value)}
                  className={`rounded-control border px-5 py-4 text-left text-base font-medium transition ${
                    answers[currentStep.key] === option.value
                      ? "border-brand-600 bg-brand-50 text-brand-800"
                      : "border-ink-200 text-ink-700 hover:border-brand-300"
                  }`}
                >
                  {option.label}
                </button>
              ))}
            </div>
          )}

          {stepIndex > 0 && (
            <button onClick={goBack} className="mt-6 text-sm font-medium text-ink-500 hover:text-ink-800">
              ← Назад
            </button>
          )}
        </>
      ) : (
        <div className="text-center">
          <p className="eyebrow justify-center">Предварительный расчёт готов</p>
          <h3 className="mt-3 text-3xl sm:text-4xl">Стоимость от {formatPrice(price)}</h3>
          <p className="mt-3 text-ink-600">
            Точная стоимость зависит от выбранной модели оборудования и особенностей участка. Наш специалист
            свяжется с вами и уточнит детали.
          </p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:justify-center">
            <button
              onClick={() =>
                openLeadModal("estimate", {
                  source: "calculator",
                  defaultDistrict: answers.district,
                  defaultComment: summarizeAnswers(answers),
                })
              }
              className="btn-primary"
            >
              Получить точный расчёт
            </button>
            <button onClick={restart} className="btn-ghost">
              Пройти заново
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
