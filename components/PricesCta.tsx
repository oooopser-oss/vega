"use client";

import { useLeadModal } from "@/components/LeadModalProvider";

export function PricesCta() {
  const { openLeadModal } = useLeadModal();

  return (
    <div className="mt-10 rounded-card border border-ink-100 bg-ink-50/60 p-6 text-center sm:p-8">
      <p className="text-ink-700">Хотите точную цифру для вашего участка?</p>
      <button
        onClick={() => openLeadModal("estimate", { source: "prices-page" })}
        className="btn-primary mt-4"
      >
        Рассчитать стоимость
      </button>
    </div>
  );
}
