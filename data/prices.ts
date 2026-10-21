import { PriceRow } from "@/types";

export const priceGroups: { title: string; rows: PriceRow[] }[] = [
  {
    title: "Оборудование",
    rows: [
      { name: "Накопительный септик, до 3 чел.", priceFrom: 47000, unit: "шт." },
      { name: "Накопительный септик, до 5 чел.", priceFrom: 68000, unit: "шт." },
      { name: "Станция глубокой очистки, до 5 чел.", priceFrom: 96000, unit: "шт." },
      { name: "Станция глубокой очистки, до 8 чел.", priceFrom: 128000, unit: "шт." },
    ],
  },
  {
    title: "Монтажные работы",
    rows: [
      { name: "Земляные работы (стандартный грунт)", priceFrom: 15000, unit: "комплект" },
      { name: "Земляные работы (глина, скала)", priceFrom: 25000, unit: "комплект" },
      { name: "Установка и подключение станции", priceFrom: 20000, unit: "комплект" },
      { name: "Система анти-всплытия", priceFrom: 12000, unit: "комплект" },
      { name: "Прокладка канализационных труб, 1 п.м.", priceFrom: 900, unit: "п.м." },
    ],
  },
  {
    title: "Обслуживание",
    rows: [
      { name: "Плановое обслуживание станции", priceFrom: 3500, unit: "выезд" },
      { name: "Замена компрессора", priceFrom: 6500, unit: "шт." },
      { name: "Откачка ила ассенизатором", priceFrom: 4500, unit: "выезд" },
    ],
  },
];
