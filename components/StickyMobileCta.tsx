"use client";

import { Phone, Calculator } from "@phosphor-icons/react/dist/ssr";
import { motion, useReducedMotion } from "motion/react";
import { useLeadModal } from "@/components/LeadModalProvider";
import { siteConfig } from "@/config/site";

export function StickyMobileCta() {
  const { openLeadModal } = useLeadModal();
  const reduce = useReducedMotion();

  return (
    <motion.div
      initial={reduce ? false : { opacity: 0, transform: "translateY(100%)" }}
      animate={{ opacity: 1, transform: "translateY(0%)" }}
      transition={{ type: "spring", duration: 0.5, bounce: 0.2, delay: 0.6 }}
      className="fixed inset-x-0 bottom-0 z-40 flex gap-2 border-t border-ink-100 bg-white p-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] shadow-lg sm:hidden"
    >
      <button
        type="button"
        onClick={() => openLeadModal("call", { source: "sticky-mobile-bar" })}
        aria-label={siteConfig.cta.orderCall}
        className="btn-outline flex flex-1 items-center justify-center gap-2 !py-3 text-sm"
      >
        <Phone size={18} weight="fill" />
        Позвонить
      </button>
      <button
        type="button"
        onClick={() => openLeadModal("estimate", { source: "sticky-mobile-bar" })}
        className="btn-primary flex flex-1 items-center justify-center gap-2 !py-3 text-sm"
      >
        <Calculator size={18} weight="fill" />
        Рассчитать
      </button>
    </motion.div>
  );
}
