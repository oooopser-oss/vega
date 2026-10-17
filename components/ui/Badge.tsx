import { ReactNode } from "react";

type Tone = "brand" | "ink" | "sand";

const toneClass: Record<Tone, string> = {
  brand: "bg-brand-50 text-brand-700",
  ink: "bg-ink-100 text-ink-700",
  sand: "bg-sand-400/15 text-sand-500",
};

export function Badge({ children, tone = "brand" }: { children: ReactNode; tone?: Tone }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-3 py-1 text-sm font-semibold ${toneClass[tone]}`}
    >
      {children}
    </span>
  );
}
