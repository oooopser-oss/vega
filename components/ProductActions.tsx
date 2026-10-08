"use client";

import { useLeadModal } from "@/components/LeadModalProvider";

export function ProductActions({ productSlug }: { productSlug: string }) {
  const { openLeadModal } = useLeadModal();

  return (
    <div className="mt-6 flex flex-col gap-3 sm:flex-row">
      <button
        onClick={() => openLeadModal("product", { source: "product-page", productSlug })}
        className="btn-primary flex-1"
      >
        Заказать с установкой
      </button>
      <button
        onClick={() => openLeadModal("estimate", { source: "product-page", productSlug })}
        className="btn-outline flex-1"
      >
        Получить точный расчёт
      </button>
    </div>
  );
}
