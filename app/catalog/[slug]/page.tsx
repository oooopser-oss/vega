import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import { Container } from "@/components/ui/Container";
import { Badge } from "@/components/ui/Badge";
import { ProductVisual } from "@/components/ProductVisual";
import { ProductActions } from "@/components/ProductActions";
import { formatPrice } from "@/lib/format";
import { products } from "@/data/products";

export function generateStaticParams() {
  return products.map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const product = products.find((p) => p.slug === slug);
  if (!product) return {};

  return {
    title: `${product.name} - купить с установкой`,
    description: product.shortDescription,
  };
}

export default async function ProductPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const product = products.find((p) => p.slug === slug);
  if (!product) notFound();

  const specRows: { label: string; value: string }[] = [
    { label: "Тип", value: product.type },
    { label: "Пользователей", value: `до ${product.spec.users} чел.` },
    { label: "Производительность", value: `${product.spec.performance} л/сут` },
    { label: "Объём", value: `${product.spec.volume} м³` },
    { label: "Габариты", value: product.spec.dimensions },
  ];
  if (product.spec.power) specRows.push({ label: "Энергопотребление", value: product.spec.power });

  return (
    <section className="py-12 sm:py-16">
      <Container>
        <nav className="text-sm text-ink-500">
          <Link href="/catalog" className="hover:text-brand-700">
            Каталог
          </Link>{" "}
          / {product.name}
        </nav>

        <div className="mt-6 grid gap-10 lg:grid-cols-2 lg:gap-14">
          <div>
            <ProductVisual className="h-80 w-full rounded-card" />
            <div className="mt-3 flex gap-1.5">
              {product.isBestseller && <Badge tone="brand">Хит продаж</Badge>}
              {product.isNew && <Badge tone="ink">Новинка</Badge>}
            </div>
          </div>

          <div>
            <p className="text-sm font-semibold uppercase tracking-wide text-ink-400">{product.brand}</p>
            <h1 className="mt-1 text-3xl sm:text-4xl">{product.name}</h1>
            <p className="mt-3 text-ink-600">{product.description}</p>

            <div className="mt-6 flex items-baseline gap-3">
              <span className="font-display text-3xl font-semibold text-ink-900">
                {formatPrice(product.price)}
              </span>
              {product.oldPrice && (
                <span className="text-lg text-ink-500 line-through">{formatPrice(product.oldPrice)}</span>
              )}
            </div>

            <ProductActions productSlug={product.slug} />

            <dl className="mt-8 divide-y divide-ink-100 border-y border-ink-100"> {/* taste-skill-ignore: real spec table */}
              {specRows.map((row) => (
                <div key={row.label} className="flex justify-between py-3 text-sm">
                  <dt className="text-ink-500">{row.label}</dt>
                  <dd className="font-medium text-ink-900">{row.value}</dd>
                </div>
              ))}
            </dl>

            <ul className="mt-6 grid gap-2 sm:grid-cols-2">
              {product.features.map((feature) => (
                <li key={feature} className="text-sm text-ink-700">
                  · {feature}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </Container>
    </section>
  );
}
