import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Container } from "@/components/ui/Container";
import { RegionCta } from "@/components/RegionCta";
import { regions } from "@/data/regions";
import { products } from "@/data/products";
import { ProductCard } from "@/components/ProductCard";

export function generateStaticParams() {
  return regions.map((r) => ({ region: r.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ region: string }>;
}): Promise<Metadata> {
  const { region: slug } = await params;
  const region = regions.find((r) => r.slug === slug);
  if (!region) return {};

  return {
    title: `Септики и станции глубокой очистки в ${region.fullLabelPrepositional}`,
    description: `Продажа и монтаж септиков в ${region.fullLabelPrepositional}. ${region.districtNote}`,
  };
}

export default async function RegionPage({ params }: { params: Promise<{ region: string }> }) {
  const { region: slug } = await params;
  const region = regions.find((r) => r.slug === slug);
  if (!region) notFound();

  const featured = products.slice(0, 3);

  return (
    <>
      <section className="py-12 sm:py-16">
        <Container>
          <h1 className="max-w-xl text-3xl sm:text-4xl">
            Септики и станции глубокой очистки в {region.fullLabelPrepositional}
          </h1>
          <p className="mt-4 max-w-xl text-ink-600">{region.districtNote}</p>
          <RegionCta districtName={region.city} />
        </Container>
      </section>

      <section className="bg-ink-50/60 py-16 sm:py-20">
        <Container>
          <h2 className="text-3xl">Популярные модели</h2>
          <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {featured.map((product) => (
              <ProductCard key={product.slug} product={product} />
            ))}
          </div>
        </Container>
      </section>
    </>
  );
}
