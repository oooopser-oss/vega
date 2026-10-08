import Link from "next/link";
import { ServiceItem } from "@/types";
import { ServiceIcon } from "@/components/ServiceIcon";
import { formatPrice } from "@/lib/format";

export function ServiceCard({ service }: { service: ServiceItem }) {
  return (
    <div className="card flex flex-col p-6">
      <span className="flex h-11 w-11 items-center justify-center rounded-full bg-brand-50 text-brand-700">
        <ServiceIcon name={service.icon} className="h-5 w-5" />
      </span>
      <h3 className="mt-4 text-lg font-semibold text-ink-900">{service.title}</h3>
      <p className="mt-2 flex-1 text-sm text-ink-600">{service.shortDescription}</p>
      {!!service.priceFrom && (
        <p className="mt-3 text-sm font-semibold text-brand-700">от {formatPrice(service.priceFrom)}</p>
      )}
      <Link href={`/services#${service.slug}`} className="mt-4 text-sm font-semibold text-ink-700 hover:text-brand-700">
        Подробнее →
      </Link>
    </div>
  );
}
