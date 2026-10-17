"use client";

import { createContext, useCallback, useContext, useMemo, useState, ReactNode } from "react";
import { LeadFormPayload } from "@/types";
import { Modal } from "@/components/ui/Modal";
import { ContactForm } from "@/components/ContactForm";

type ModalKind = "call" | "estimate" | "select" | "product" | "installation";

interface OpenOptions {
  productSlug?: string;
  source?: string;
  defaultDistrict?: string;
  defaultComment?: string;
}

interface LeadModalContextValue {
  openLeadModal: (kind: ModalKind, options?: OpenOptions) => void;
  closeLeadModal: () => void;
}

const LeadModalContext = createContext<LeadModalContextValue | null>(null);

const MODAL_CONFIG: Record<
  ModalKind,
  {
    title: string;
    submitLabel: string;
    formType: LeadFormPayload["formType"];
    showDistrict?: boolean;
    showComment?: boolean;
    showResidents?: boolean;
    showUsageMode?: boolean;
  }
> = {
  call: {
    title: "Заказать звонок",
    submitLabel: "Перезвоните мне",
    formType: "call",
  },
  estimate: {
    title: "Получить расчёт стоимости",
    submitLabel: "Получить точный расчёт",
    formType: "estimate",
    showDistrict: true,
    showComment: true,
  },
  select: {
    title: "Подобрать септик",
    submitLabel: "Подобрать септик",
    formType: "select",
    showResidents: true,
    showUsageMode: true,
  },
  product: {
    title: "Заказать с установкой",
    submitLabel: "Заказать с установкой",
    formType: "product",
    showComment: true,
  },
  installation: {
    title: "Получите бесплатную консультацию специалиста",
    submitLabel: "Получить консультацию",
    formType: "installation",
    showDistrict: true,
    showComment: true,
  },
};

export function LeadModalProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<{ kind: ModalKind; options?: OpenOptions } | null>(null);

  const openLeadModal = useCallback((kind: ModalKind, options?: OpenOptions) => {
    setState({ kind, options });
  }, []);

  const closeLeadModal = useCallback(() => setState(null), []);

  const value = useMemo(() => ({ openLeadModal, closeLeadModal }), [openLeadModal, closeLeadModal]);

  const config = state ? MODAL_CONFIG[state.kind] : null;

  return (
    <LeadModalContext.Provider value={value}>
      {children}
      <Modal open={!!state} onClose={closeLeadModal} title={config?.title ?? ""}>
        {config && (
          <ContactForm
            key={`${state?.kind}-${state?.options?.productSlug ?? ""}-${state?.options?.defaultDistrict ?? ""}`}
            formType={config.formType}
            submitLabel={config.submitLabel}
            showDistrict={config.showDistrict}
            showComment={config.showComment}
            showResidents={config.showResidents}
            showUsageMode={config.showUsageMode}
            productSlug={state?.options?.productSlug}
            source={state?.options?.source}
            defaultDistrict={state?.options?.defaultDistrict}
            defaultComment={state?.options?.defaultComment}
          />
        )}
      </Modal>
    </LeadModalContext.Provider>
  );
}

export function useLeadModal() {
  const ctx = useContext(LeadModalContext);
  if (!ctx) {
    throw new Error("useLeadModal must be used within LeadModalProvider");
  }
  return ctx;
}
