import type { Metadata } from "next";
import { Container } from "@/components/ui/Container";
import { StarRating } from "@/components/ui/StarRating";
import { formatDate } from "@/lib/format";
import { reviews, getAverageRating } from "@/data/reviews";

export const metadata: Metadata = {
  title: "Отзывы клиентов",
  description: "Отзывы о монтаже септиков и станций глубокой очистки.",
};

export default function ReviewsPage() {
  const rating = getAverageRating();

  return (
    <section className="py-12 sm:py-16">
      <Container className="max-w-3xl">
        <h1 className="text-3xl sm:text-4xl">Отзывы клиентов</h1>
        <div className="mt-4 flex items-center gap-3">
          <StarRating value={rating} size={20} />
          <span className="text-ink-600">{rating} из 5 на основе {reviews.length} отзывов</span>
        </div>

        <div className="mt-10 space-y-6">
          {reviews.map((review) => (
            <div key={review.id} className="card p-6">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="font-semibold text-ink-900">{review.name}</p>
                  <p className="text-sm text-ink-500">
                    {review.city} · {formatDate(review.date)}
                  </p>
                </div>
                <StarRating value={review.rating} />
              </div>
              <p className="mt-4 text-sm leading-relaxed text-ink-700">{review.text}</p>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
