"use client";

import { useLeadModal } from "@/components/LeadModalProvider";

export function OfferCta() {
  const { openLeadModal } = useLeadModal();

  return (
    <div className="mt-10">
      <button onClick={() => openLeadModal("call", { source: "offers-page" })} className="btn-primary">
        Узнать подробности
      </button>
    </div>
  );
}
