"use client";

import { useLeadModal } from "@/components/LeadModalProvider";

export function InstallationCta() {
  const { openLeadModal } = useLeadModal();

  return (
    <div className="mt-6">
      <button
        onClick={() => openLeadModal("installation", { source: "installation-page" })}
        className="btn-primary"
      >
        Получить консультацию
      </button>
    </div>
  );
}
