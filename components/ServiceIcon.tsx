import { MapPin, Wrench, Truck, Gauge, ShieldCheck, ClipboardText } from "@phosphor-icons/react/ssr";
import type { Icon } from "@phosphor-icons/react";

const iconMap: Record<string, Icon> = {
  MapPin,
  Wrench,
  Truck,
  Gauge,
  ShieldCheck,
  ClipboardText,
};

export function ServiceIcon({ name, className }: { name: string; className?: string }) {
  const IconComponent = iconMap[name] ?? Wrench;
  return <IconComponent className={className} weight="regular" />;
}
