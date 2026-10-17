import { Star } from "@phosphor-icons/react/ssr";

export function StarRating({ value, size = 16 }: { value: number; size?: number }) {
  const rounded = Math.round(value);
  return (
    <div className="flex items-center gap-0.5" aria-label={`Рейтинг ${value} из 5`}>
      {Array.from({ length: 5 }).map((_, i) => (
        <Star
          key={i}
          size={size}
          weight={i < rounded ? "fill" : "regular"}
          className={i < rounded ? "text-sand-500" : "text-ink-300"}
        />
      ))}
    </div>
  );
}
