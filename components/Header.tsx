"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { siteConfig } from "@/config/site";
import { Container } from "@/components/ui/Container";
import { MaxIcon, MenuIcon } from "@/components/icons";
import { X } from "@phosphor-icons/react/ssr";
import { useLeadModal } from "@/components/LeadModalProvider";

const navLinks = [
  { href: "/catalog", label: "Каталог" },
  { href: "/installation", label: "Установка" },
  { href: "/services", label: "Услуги" },
  { href: "/prices", label: "Цены" },
  { href: "/portfolio", label: "Наши работы" },
  { href: "/reviews", label: "Отзывы" },
  { href: "/contacts", label: "Контакты" },
];

function isLinkActive(pathname: string, href: string): boolean {
  return pathname === href || pathname.startsWith(`${href}/`);
}

function Logo() {
  return (
    <Link href="/" className="flex items-center gap-2">
      <span className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-700 text-white">
        <svg viewBox="0 0 24 24" width="17" height="17" fill="none" aria-hidden="true">
          <path
            d="M4 20V10L12 4L20 10V20H14V14H10V20H4Z"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinejoin="round"
          />
        </svg>
      </span>
      <span className="font-display text-lg font-semibold text-ink-900">СептикДом</span>
    </Link>
  );
}

export function Header() {
  const [menuOpen, setMenuOpen] = useState(false);
  const { openLeadModal } = useLeadModal();
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-40 h-16 border-b border-ink-100 bg-white">
      <Container className="flex h-full items-center justify-between gap-4">
        <Logo />

        <nav className="hidden items-center gap-5 lg:flex">
          {navLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              aria-current={isLinkActive(pathname, link.href) ? "page" : undefined}
              className={`whitespace-nowrap text-sm font-medium transition-colors duration-150 hover:text-brand-700 ${
                isLinkActive(pathname, link.href) ? "text-brand-700" : "text-ink-600"
              }`}
            >
              {link.label}
            </Link>
          ))}
        </nav>

        <div className="hidden items-center gap-3 lg:flex">
          <a
            href={siteConfig.contacts.phoneHref}
            className="whitespace-nowrap text-sm font-semibold text-ink-900 hover:text-brand-700"
          >
            {siteConfig.contacts.phone}
          </a>
          <a
            href={siteConfig.contacts.maxUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-outline whitespace-nowrap !px-4 !py-2 text-sm"
          >
            <MaxIcon className="h-4 w-4" />
            {siteConfig.cta.writeToMax}
          </a>
          <button
            onClick={() => openLeadModal("call", { source: "header" })}
            className="btn-primary whitespace-nowrap !px-4 !py-2 text-sm"
          >
            {siteConfig.cta.orderCall}
          </button>
        </div>

        <button
          className="flex h-9 w-9 items-center justify-center rounded-full text-ink-700 transition hover:bg-ink-100 lg:hidden"
          onClick={() => setMenuOpen((v) => !v)}
          aria-label="Открыть меню"
          aria-expanded={menuOpen}
        >
          {menuOpen ? <X size={22} /> : <MenuIcon size={22} />}
        </button>
      </Container>

      {menuOpen && (
        <div className="absolute inset-x-0 top-16 border-t border-ink-100 bg-white lg:hidden">
          <Container className="flex flex-col gap-1 py-4">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                aria-current={isLinkActive(pathname, link.href) ? "page" : undefined}
                className={`rounded-control px-3 py-2.5 text-base font-medium hover:bg-ink-50 ${
                  isLinkActive(pathname, link.href) ? "bg-brand-50 text-brand-700" : "text-ink-700"
                }`}
                onClick={() => setMenuOpen(false)}
              >
                {link.label}
              </Link>
            ))}
            <div className="mt-3 flex flex-col gap-2 border-t border-ink-100 pt-4">
              <a href={siteConfig.contacts.phoneHref} className="text-base font-semibold text-ink-900">
                {siteConfig.contacts.phone}
              </a>
              <a
                href={siteConfig.contacts.maxUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="btn-outline w-full"
              >
                <MaxIcon className="h-4 w-4" />
                {siteConfig.cta.writeToMax}
              </a>
              <button
                onClick={() => {
                  setMenuOpen(false);
                  openLeadModal("call", { source: "mobile-menu" });
                }}
                className="btn-primary w-full"
              >
                {siteConfig.cta.orderCall}
              </button>
            </div>
          </Container>
        </div>
      )}
    </header>
  );
}
