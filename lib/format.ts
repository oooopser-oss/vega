export function formatPrice(value: number): string {
  if (value <= 0) return "по запросу";
  return `${new Intl.NumberFormat("ru-RU").format(value)} ₽`;
}

export function formatDate(iso: string): string {
  return new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "long", year: "numeric" }).format(
    new Date(iso)
  );
}
