"use client";

import Link from "next/link";
import { Product } from "@/types";
import { ProductVisual } from "@/components/ProductVisual";
import { formatPrice } from "@/lib/format";
import { Badge } from "@/components/ui/Badge";
import { useLeadModal } from "@/components/LeadModalProvider";

export function ProductCard({ product }: { product: Product }) {
  const { openLeadModal } = useLeadModal();

  return (
    <div className="card flex flex-col overflow-hidden">
      <Link href={`/catalog/${product.slug}`} className="relative block">
        <ProductVisual className="h-44 w-full" />
        <div className="absolute left-3 top-3 flex flex-wrap gap-1.5">
          {product.isBestseller && <Badge tone="brand">Хит продаж</Badge>}
          {product.isNew && <Badge tone="ink">Новинка</Badge>}
          {product.oldPrice && <Badge tone="sand">Скидка</Badge>}
        </div>
      </Link>

      <div className="flex flex-1 flex-col p-5">
        <p className="text-sm font-medium text-ink-500">{product.type}</p>
        <Link href={`/catalog/${product.slug}`}>
          <h3 className="mt-1 text-lg font-semibold text-ink-900 hover:text-brand-700">{product.name}</h3>
        </Link>
        <p className="mt-1.5 text-sm text-ink-500">{product.shortDescription}</p>

        <dl className="mt-4 grid grid-cols-2 gap-2 text-sm">
          <div>
            <dt className="text-ink-500">Пользователей</dt>
            <dd className="font-semibold text-ink-800">до {product.spec.users} чел.</dd>
          </div>
          <div>
            <dt className="text-ink-500">Производительность</dt>
            <dd className="font-semibold text-ink-800">{product.spec.performance} л/сут</dd>
          </div>
        </dl>

        <div className="mt-4 flex items-baseline gap-2">
          <span className="font-display text-2xl font-semibold text-ink-900">{formatPrice(product.price)}</span>
          {product.oldPrice && (
            <span className="text-sm text-ink-500 line-through">{formatPrice(product.oldPrice)}</span>
          )}
        </div>

        <div className="mt-5 flex flex-col gap-2 sm:flex-row">
          <Link href={`/catalog/${product.slug}`} className="btn-outline flex-1 !py-2.5 text-sm">
            Подробнее
          </Link>
          <button
            onClick={() => openLeadModal("estimate", { source: "catalog-card", productSlug: product.slug })}
            className="btn-primary flex-1 !py-2.5 text-sm"
          >
            Рассчитать
          </button>
        </div>
      </div>
    </div>
  );
}
