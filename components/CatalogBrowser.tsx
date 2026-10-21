"use client";

import { useMemo, useState } from "react";
import { Product } from "@/types";
import { ProductCard } from "@/components/ProductCard";
import { Reveal } from "@/components/Reveal";
import { Select } from "@/components/ui/Select";

type SortMode = "popular" | "price-asc" | "price-desc";

export function CatalogBrowser({ products }: { products: Product[] }) {
  const [type, setType] = useState<string>("all");
  const [brand, setBrand] = useState<string>("all");
  const [sort, setSort] = useState<SortMode>("popular");

  const brands = useMemo(() => Array.from(new Set(products.map((p) => p.brand))), [products]);

  const filtered = useMemo(() => {
    let list = products.filter(
      (p) => (type === "all" || p.type === type) && (brand === "all" || p.brand === brand)
    );

    if (sort === "price-asc") list = [...list].sort((a, b) => a.price - b.price);
    else if (sort === "price-desc") list = [...list].sort((a, b) => b.price - a.price);
    else list = [...list].sort((a, b) => Number(b.isBestseller) - Number(a.isBestseller));

    return list;
  }, [products, type, brand, sort]);

  return (
    <div>
      <div className="flex flex-wrap items-end gap-3 rounded-card bg-ink-50 p-4">
        <Select
          id="filter-type"
          label="Тип оборудования"
          value={type}
          onChange={(e) => setType(e.target.value)}
          className="max-w-xs"
        >
          <option value="all">Все типы</option>
          <option value="Накопительный септик">Накопительный септик</option>
          <option value="Станция глубокой очистки">Станция глубокой очистки</option>
        </Select>

        <Select
          id="filter-sort"
          label="Сортировка"
          value={sort}
          onChange={(e) => setSort(e.target.value as SortMode)}
          className="max-w-xs"
        >
          <option value="popular">Популярные</option>
          <option value="price-asc">Сначала дешевле</option>
          <option value="price-desc">Сначала дороже</option>
        </Select>

        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setBrand("all")}
            className={`rounded-full px-3 py-1.5 text-sm font-medium transition-colors ${
              brand === "all" ? "bg-brand-700 text-white" : "bg-white text-ink-600 hover:bg-ink-100"
            }`}
          >
            Все бренды
          </button>
          {brands.map((b) => (
            <button
              key={b}
              onClick={() => setBrand(b)}
              className={`rounded-full px-3 py-1.5 text-sm font-medium transition-colors ${
                brand === b ? "bg-brand-700 text-white" : "bg-white text-ink-600 hover:bg-ink-100"
              }`}
            >
              {b}
            </button>
          ))}
        </div>
      </div>

      <p className="mt-4 text-sm text-ink-500">Найдено моделей: {filtered.length}</p>

      {filtered.length > 0 ? (
        <div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((product, i) => (
            <Reveal key={product.slug} delay={(i % 3) * 80}>
              <ProductCard product={product} />
            </Reveal>
          ))}
        </div>
      ) : (
        <p className="mt-10 text-ink-500">
          По этим условиям моделей нет. Попробуйте изменить фильтр или{" "}
          <button onClick={() => { setType("all"); setBrand("all"); }} className="font-semibold text-brand-700 underline">
            сбросить фильтры
          </button>
          .
        </p>
      )}
    </div>
  );
}
