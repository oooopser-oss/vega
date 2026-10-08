"use client";

import { useState } from "react";
import { CaretDown } from "@phosphor-icons/react/ssr";
import { FaqItem } from "@/types";

export function FaqAccordion({ items }: { items: FaqItem[] }) {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <div className="divide-y divide-ink-100 border-y border-ink-100">
      {items.map((item, i) => {
        const open = openIndex === i;
        return (
          <div key={item.question}>
            <button
              onClick={() => setOpenIndex(open ? null : i)}
              aria-expanded={open}
              className="flex w-full items-center justify-between gap-4 py-5 text-left"
            >
              <span className="font-medium text-ink-900">{item.question}</span>
              <CaretDown
                size={18}
                className={`shrink-0 text-ink-400 transition-transform ${open ? "rotate-180" : ""}`}
              />
            </button>
            {open && <p className="pb-5 text-sm leading-relaxed text-ink-600">{item.answer}</p>}
          </div>
        );
      })}
    </div>
  );
}
