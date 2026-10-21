import Link from "next/link";
import { Container } from "@/components/ui/Container";
import { SectionHeading } from "@/components/ui/SectionHeading";
import { StarRating } from "@/components/ui/StarRating";
import { Reveal } from "@/components/Reveal";
import { reviews } from "@/data/reviews";

export function ReviewsPreview() {
  const featured = reviews.slice(0, 3);

  return (
    <section className="py-16 sm:py-20">
      <Container>
        <Reveal className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <SectionHeading title="Что говорят клиенты в отзывах" />
          <Link href="/reviews" className="btn-outline self-start sm:self-auto">
            Все отзывы
          </Link>
        </Reveal>

        <div className="mt-10 grid gap-6 sm:grid-cols-3">
          {featured.map((review, i) => (
            <Reveal key={review.id} delay={i * 80}>
              <div className="card flex h-full flex-col p-6">
                <StarRating value={review.rating} />
                <p className="mt-3 line-clamp-3 flex-1 text-sm leading-relaxed text-ink-700">
                  {review.text}
                </p>
                <p className="mt-4 text-sm font-semibold text-ink-900">{review.name}</p>
                <p className="text-[13px] text-ink-500">{review.city}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </Container>
    </section>
  );
}
