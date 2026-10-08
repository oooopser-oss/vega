"use client";

import { siteConfig } from "@/config/site";
import { Container } from "@/components/ui/Container";
import { Reveal } from "@/components/Reveal";
import { useLeadModal } from "@/components/LeadModalProvider";

export function CTASection() {
  const { openLeadModal } = useLeadModal();

  return (
    <section className="bg-ink-950 py-16 sm:py-20">
      <Container>
        <Reveal className="mx-auto max-w-2xl text-center">
          <h2 className="text-3xl text-white sm:text-4xl">Готовы обсудить ваш участок?</h2>
          <p className="mt-4 text-base text-ink-300">
            Оставьте заявку, и мы перезвоним в течение 15 минут и назначим бесплатный выезд инженера.
          </p>
          <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <button onClick={() => openLeadModal("call", { source: "cta-section" })} className="btn-primary">
              {siteConfig.cta.orderCall}
            </button>
            <a href={siteConfig.contacts.phoneHref} className="text-base font-semibold text-white hover:text-brand-400">
              {siteConfig.contacts.phone}
            </a>
          </div>
        </Reveal>
      </Container>
    </section>
  );
}
