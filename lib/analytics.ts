declare global {
  interface Window {
    ym?: (counterId: number, action: string, target: string, params?: Record<string, unknown>) => void;
    gtag?: (...args: unknown[]) => void;
  }
}

export function trackLeadSubmit(formType: string) {
  if (typeof window === "undefined") return;

  const yandexMetrikaId = process.env.NEXT_PUBLIC_YANDEX_METRIKA_ID;
  if (yandexMetrikaId && window.ym) {
    window.ym(Number(yandexMetrikaId), "reachGoal", "lead_submit", { formType });
  }

  if (window.gtag) {
    window.gtag("event", "generate_lead", { form_type: formType });
  }
}
