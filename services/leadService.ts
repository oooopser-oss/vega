import { LeadFormPayload } from "@/types";
import { trackLeadSubmit } from "@/lib/analytics";

export interface SubmitResult {
  ok: boolean;
  error?: string;
}

export async function submitLead(payload: LeadFormPayload): Promise<SubmitResult> {
  if (payload.companyWebsite) {
    // honeypot triggered, silently report success to the bot
    return { ok: true };
  }

  try {
    const res = await fetch("/api/lead", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      return { ok: false, error: "Не удалось отправить заявку. Попробуйте ещё раз." };
    }

    trackLeadSubmit(payload.formType);
    return { ok: true };
  } catch {
    return { ok: false, error: "Проблема с соединением. Проверьте интернет и попробуйте снова." };
  }
}
