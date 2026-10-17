import { StarRating } from "@/components/ui/StarRating";
import { Container } from "@/components/ui/Container";
import { reviews, getAverageRating } from "@/data/reviews";

const stats = [
  { value: "600+", label: "смонтированных станций" },
  { value: "1-3 дня", label: "средний срок монтажа" },
  { value: "до 5 лет", label: "гарантия на оборудование" },
];

export function TrustStrip() {
  const rating = getAverageRating();

  return (
    <section className="bg-ink-50/60 py-8">
      <Container className="flex flex-col items-center gap-6 sm:flex-row sm:justify-between">
        <div className="flex items-center gap-3">
          <StarRating value={rating} size={18} />
          <span className="text-sm text-ink-600">
            {rating} из 5 · {reviews.length}+ отзывов клиентов
          </span>
        </div>
        <div className="flex flex-wrap items-center justify-center gap-x-8 gap-y-2">
          {stats.map((stat) => (
            <div key={stat.label} className="text-center sm:text-left">
              <p className="font-display text-xl font-semibold text-ink-900">{stat.value}</p>
              <p className="text-[13px] text-ink-500">{stat.label}</p>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
