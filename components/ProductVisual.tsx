import { Drop } from "@phosphor-icons/react/ssr";

export function ProductVisual({ className = "" }: { className?: string }) {
  return (
    <div className={`flex items-center justify-center bg-brand-50 ${className}`}>
      <Drop size={40} weight="light" className="text-brand-300" />
    </div>
  );
}
