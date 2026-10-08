import type { Metadata } from "next";
import { Container } from "@/components/ui/Container";
import { ContactForm } from "@/components/ContactForm";
import { MaxIcon } from "@/components/icons";
import { siteConfig } from "@/config/site";

export const metadata: Metadata = {
  title: "Контакты",
  description: "Телефон, адрес и режим работы компании СептикДом.",
};

export default function ContactsPage() {
  return (
    <section className="py-12 sm:py-16">
      <Container>
        <h1 className="text-3xl sm:text-4xl">Контакты</h1>

        <div className="mt-10 grid gap-10 lg:grid-cols-[1fr_0.9fr] lg:gap-16">
          <div>
            <dl className="space-y-5">
              <div>
                <dt className="text-sm text-ink-500">Телефон</dt>
                <dd>
                  <a href={siteConfig.contacts.phoneHref} className="text-lg font-semibold text-ink-900 hover:text-brand-700">
                    {siteConfig.contacts.phone}
                  </a>
                </dd>
              </div>
              <div>
                <dt className="text-sm text-ink-500">Email</dt>
                <dd>
                  <a href={`mailto:${siteConfig.contacts.email}`} className="text-lg font-semibold text-ink-900 hover:text-brand-700">
                    {siteConfig.contacts.email}
                  </a>
                </dd>
              </div>
              <div>
                <dt className="text-sm text-ink-500">Адрес</dt>
                <dd className="text-lg font-semibold text-ink-900">{siteConfig.contacts.address}</dd>
              </div>
              <div>
                <dt className="text-sm text-ink-500">Режим работы</dt>
                <dd className="text-lg font-semibold text-ink-900">{siteConfig.contacts.workingHours}</dd>
              </div>
            </dl>

            <a
              href={siteConfig.contacts.maxUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-outline mt-8"
            >
              <MaxIcon className="h-4 w-4" />
              {siteConfig.cta.writeToMax}
            </a>
          </div>

          <div className="card p-6 sm:p-8">
            <h2 className="text-xl">Оставить заявку</h2>
            <div className="mt-5">
              <ContactForm formType="call" submitLabel="Отправить заявку" source="contacts-page" compact />
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}
