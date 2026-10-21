import { List, CheckCircle } from "@phosphor-icons/react/ssr";

export { List as MenuIcon, CheckCircle as CheckCircleIcon };

export function MaxIcon({ className = "h-4 w-4" }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" aria-hidden="true">
      <rect x="1" y="1" width="22" height="22" rx="7" fill="currentColor" fillOpacity="0.12" />
      <path
        d="M6 16V8l3 4 3-4v8M15 16V8l3 4 3-4v8"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
