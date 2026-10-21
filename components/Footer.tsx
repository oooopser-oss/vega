import Link from "next/link";
import { siteConfig } from "@/config/site";
import { Container } from "@/components/ui/Container";
import { MaxIcon } from "@/components/icons";
import { regions } from "@/data/regions";

const columns = [
  {
    title: "Компания",
    links: [
      { href: "/about", label: "О компании" },
      { href: "/portfolio", label: "Наши работы" },
      { href: "/reviews", label: "Отзывы" },
      { href: "/offers", label: "Акции" },
      { href: "/contacts", label: "Контакты" },
    ],
  },
  {
    title: "Каталог и услуги",
    links: [
      { href: "/catalog", label: "Каталог септиков" },
      { href: "/installation", label: "Установка под ключ" },
      { href: "/services", label: "Все услуги" },
      { href: "/prices", label: "Цены" },
    ],
  },
];

export function Footer() {
  return (
    <footer className="bg-ink-950 text-ink-300">
      <Container className="py-14 sm:py-16">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <Link href="/" className="flex items-center gap-2">
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-600 text-white">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true">
                  <path
                    d="M4 20V10L12 4L20 10V20H14V14H10V20H4Z"
                    stroke="currentColor"
                    strokeWidth="1.8"
                    strokeLinejoin="round"
                  />
                </svg>
              </span>
              <span className="font-display text-lg font-semibold text-white">СептикДом</span>
            </Link>
            <p className="mt-4 text-sm leading-relaxed text-ink-400">
              {siteConfig.slogan}. Работаем в {siteConfig.region.fullLabelPrepositional}.
            </p>
            <div className="mt-5 flex gap-3">
              <a
                href={siteConfig.social.vk}
                target="_blank"
                rel="noopener noreferrer"
                aria-label="ВКонтакте"
                className="flex h-9 w-9 items-center justify-center rounded-full bg-ink-900 text-ink-300 transition hover:bg-brand-700 hover:text-white"
              >
                VK
              </a>
              <a
                href={siteConfig.social.telegram}
                target="_blank"
                rel="noopener noreferrer"
                aria-label="Telegram"
                className="flex h-9 w-9 items-center justify-center rounded-full bg-ink-900 text-ink-300 transition hover:bg-brand-700 hover:text-white"
              >
                TG
              </a>
              <a
                href={siteConfig.contacts.maxUrl}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={siteConfig.cta.writeToMax}
                className="flex h-9 w-9 items-center justify-center rounded-full bg-ink-900 text-ink-300 transition hover:bg-brand-700 hover:text-white"
              >
                <MaxIcon className="h-4 w-4" />
              </a>
            </div>
          </div>

          {columns.map((col) => (
            <div key={col.title}>
              <h3 className="text-base font-semibold text-white">{col.title}</h3>
              <ul className="mt-4 space-y-2.5">
                {col.links.map((link) => (
                  <li key={link.href}>
                    <Link href={link.href} className="text-sm text-ink-400 hover:text-brand-400">
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}

          <div>
            <h3 className="text-base font-semibold text-white">Контакты</h3>
            <ul className="mt-4 space-y-2.5 text-sm text-ink-400">
              <li>
                <a href={siteConfig.contacts.phoneHref} className="hover:text-brand-400">
                  {siteConfig.contacts.phone}
                </a>
              </li>
              <li>
                <a href={`mailto:${siteConfig.contacts.email}`} className="hover:text-brand-400">
                  {siteConfig.contacts.email}
                </a>
              </li>
              <li>{siteConfig.contacts.address}</li>
              <li>{siteConfig.contacts.workingHours}</li>
            </ul>
          </div>
        </div>

        <div className="mt-14">
          <p className="mb-3 text-sm font-medium text-ink-400">Работаем в городах</p>
          <div className="flex flex-wrap gap-x-5 gap-y-2 text-sm text-ink-400">
            {regions.map((region) => (
              <Link key={region.slug} href={`/${region.slug}`} className="hover:text-brand-400">
                {region.city}
              </Link>
            ))}
          </div>
        </div>

        <div className="mt-10 flex flex-col gap-2 text-[13px] text-ink-400 sm:flex-row sm:items-center sm:justify-between">
          <p>
            © {new Date().getFullYear()} {siteConfig.legalName}. Все права защищены.
          </p>
          <p>Сайт не является публичной офертой.</p>
        </div>
      </Container>
    </footer>
  );
}
