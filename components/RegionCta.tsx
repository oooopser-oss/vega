"use client";

import { useLeadModal } from "@/components/LeadModalProvider";

export function RegionCta({ districtName }: { districtName: string }) {
  const { openLeadModal } = useLeadModal();

  return (
    <div className="mt-6">
      <button
        onClick={() => openLeadModal("estimate", { source: "region-page", defaultDistrict: districtName })}
        className="btn-primary"
      >
        Рассчитать стоимость
      </button>
    </div>
  );
}
