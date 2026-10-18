"use client";

import Link from "next/link";
import { useLeadModal } from "@/components/LeadModalProvider";
import { MagneticButton } from "@/components/MagneticButton";

export function HeroActions() {
  const { openLeadModal } = useLeadModal();

  return (
    <div className="mt-8 flex flex-col gap-3 sm:flex-row">
      <MagneticButton onClick={() => openLeadModal("estimate", { source: "hero" })} className="btn-primary">
        Рассчитать стоимость
      </MagneticButton>
      <Link href="/catalog" className="btn-outline">
        Смотреть каталог
      </Link>
    </div>
  );
}
