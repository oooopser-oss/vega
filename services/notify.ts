import { LeadFormPayload } from "@/types";

function formatLeadMessage(payload: LeadFormPayload): string {
  const lines = [
    `Новая заявка (${payload.formType})`,
    `Имя: ${payload.name}`,
    `Телефон: ${payload.phone}`,
    payload.district && `Район: ${payload.district}`,
    payload.residents && `Проживающих: ${payload.residents}`,
    payload.usageMode && `Тип проживания: ${payload.usageMode}`,
    payload.productSlug && `Товар: ${payload.productSlug}`,
    payload.comment && `Комментарий: ${payload.comment}`,
    payload.source && `Источник: ${payload.source}`,
  ].filter(Boolean);
  return lines.join("\n");
}

export async function notifyTelegram(payload: LeadFormPayload): Promise<void> {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) return;

  await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text: formatLeadMessage(payload) }),
  }).catch(() => undefined);
}

export async function notifyMax(payload: LeadFormPayload): Promise<void> {
  const webhookUrl = process.env.MAX_WEBHOOK_URL;
  if (!webhookUrl) return;

  await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text: formatLeadMessage(payload) }),
  }).catch(() => undefined);
}

export async function notifyCrm(payload: LeadFormPayload): Promise<void> {
  const crmWebhookUrl = process.env.CRM_WEBHOOK_URL;
  if (!crmWebhookUrl) return;

  await fetch(crmWebhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  }).catch(() => undefined);
}

export async function dispatchLead(payload: LeadFormPayload): Promise<void> {
  await Promise.all([notifyTelegram(payload), notifyMax(payload), notifyCrm(payload)]);
}
