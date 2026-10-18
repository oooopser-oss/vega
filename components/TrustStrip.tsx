import { StarRating } from "@/components/ui/StarRating";
import { Container } from "@/components/ui/Container";
import { AnimatedNumber } from "@/components/AnimatedNumber";
import { reviews, getAverageRating } from "@/data/reviews";

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
          <div className="text-center sm:text-left">
            <p className="font-display text-xl font-semibold text-ink-900">
              <AnimatedNumber value={600} suffix="+" />
            </p>
            <p className="text-[13px] text-ink-500">смонтированных станций</p>
          </div>
          <div className="text-center sm:text-left">
            <p className="font-display text-xl font-semibold text-ink-900">1-3 дня</p>
            <p className="text-[13px] text-ink-500">средний срок монтажа</p>
          </div>
          <div className="text-center sm:text-left">
            <p className="font-display text-xl font-semibold text-ink-900">
              до <AnimatedNumber value={5} suffix=" лет" />
            </p>
            <p className="text-[13px] text-ink-500">гарантия на оборудование</p>
          </div>
        </div>
      </Container>
    </section>
  );
}
