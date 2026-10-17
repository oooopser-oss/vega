"use client";

import Link from "next/link";
import { useLeadModal } from "@/components/LeadModalProvider";

export function HeroActions() {
  const { openLeadModal } = useLeadModal();

  return (
    <div className="mt-8 flex flex-col gap-3 sm:flex-row">
      <button onClick={() => openLeadModal("estimate", { source: "hero" })} className="btn-primary">
        Рассчитать стоимость
      </button>
      <Link href="/catalog" className="btn-outline">
        Смотреть каталог
      </Link>
    </div>
  );
}
