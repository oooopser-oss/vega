"use client";

import { useState } from "react";
import { CaretDown } from "@phosphor-icons/react/ssr";
import { FaqItem } from "@/types";

export function FaqAccordion({ items }: { items: FaqItem[] }) {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <div className="flex flex-col gap-2">
      {items.map((item, i) => {
        const open = openIndex === i;
        return (
          <div
            key={item.question}
            className={`rounded-card transition-colors duration-200 ${open ? "bg-brand-700 text-white" : "bg-ink-50 text-ink-900"}`}
          >
            <button
              onClick={() => setOpenIndex(open ? null : i)}
              aria-expanded={open}
              className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left"
            >
              <span className="font-medium">{item.question}</span>
              <CaretDown
                size={18}
                className={`shrink-0 transition-transform ${open ? "rotate-180 text-white" : "text-ink-400"}`}
              />
            </button>
            {open && (
              <p className="px-5 pb-5 text-sm leading-relaxed text-white/90">{item.answer}</p>
            )}
          </div>
        );
      })}
    </div>
  );
}
