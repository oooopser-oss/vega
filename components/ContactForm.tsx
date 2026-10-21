"use client";

import { FormEvent, useState } from "react";
import { LeadFormPayload } from "@/types";
import { submitLead } from "@/services/leadService";
import { formatPhoneInput, isValidRussianPhone } from "@/lib/phone";
import { Input } from "@/components/ui/Input";
import { Textarea } from "@/components/ui/Textarea";
import { Select } from "@/components/ui/Select";
import { CheckCircleIcon } from "@/components/icons";

export interface ContactFormProps {
  formType: LeadFormPayload["formType"];
  submitLabel: string;
  productSlug?: string;
  source?: string;
  showDistrict?: boolean;
  showComment?: boolean;
  showResidents?: boolean;
  showUsageMode?: boolean;
  compact?: boolean;
  defaultDistrict?: string;
  defaultComment?: string;
  onSuccess?: () => void;
}

export function ContactForm({
  formType,
  submitLabel,
  productSlug,
  source,
  showDistrict = false,
  showComment = false,
  showResidents = false,
  showUsageMode = false,
  compact = false,
  defaultDistrict = "",
  defaultComment = "",
  onSuccess,
}: ContactFormProps) {
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [district, setDistrict] = useState(defaultDistrict);
  const [comment, setComment] = useState(defaultComment);
  const [residents, setResidents] = useState("");
  const [usageMode, setUsageMode] = useState("");
  const [companyWebsite, setCompanyWebsite] = useState(""); // honeypot
  const [errors, setErrors] = useState<{ name?: string; phone?: string }>({});
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [errorMessage, setErrorMessage] = useState("");

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();

    const nextErrors: { name?: string; phone?: string } = {};
    if (name.trim().length < 2) nextErrors.name = "Укажите имя";
    if (!isValidRussianPhone(phone)) nextErrors.phone = "Укажите корректный номер телефона";
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setStatus("loading");

    const payload: LeadFormPayload = {
      formType,
      name,
      phone,
      district: showDistrict ? district : undefined,
      comment: showComment ? comment : undefined,
      residents: showResidents ? residents : undefined,
      usageMode: showUsageMode ? usageMode : undefined,
      productSlug,
      source,
      companyWebsite,
    };

    const result = await submitLead(payload);

    if (result.ok) {
      setStatus("success");
      onSuccess?.();
    } else {
      setStatus("error");
      setErrorMessage(result.error ?? "Не удалось отправить заявку. Попробуйте ещё раз.");
    }
  }

  if (status === "success") {
    return (
      <div className="flex flex-col items-center gap-3 rounded-control bg-brand-50 px-6 py-8 text-center">
        <CheckCircleIcon className="h-12 w-12 text-brand-700" />
        <p className="text-lg font-semibold text-ink-900">Заявка отправлена!</p>
        <p className="text-sm text-ink-600">
          Мы свяжемся с вами в ближайшее время по указанному номеру телефона.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className={`flex flex-col ${compact ? "gap-3" : "gap-4"}`} noValidate>
      <Input
        id="lead-name"
        label="Имя"
        placeholder="Как к вам обращаться"
        required
        value={name}
        onChange={(e) => setName(e.target.value)}
        error={errors.name}
        autoComplete="name"
      />
      <Input
        id="lead-phone"
        label="Телефон"
        type="tel"
        placeholder="+7 (___) ___-__-__"
        required
        value={phone}
        onChange={(e) => setPhone(formatPhoneInput(e.target.value))}
        error={errors.phone}
        autoComplete="tel"
        inputMode="tel"
      />

      {showResidents && (
        <Select
          id="lead-residents"
          label="Количество проживающих"
          value={residents}
          onChange={(e) => setResidents(e.target.value)}
        >
          <option value="">Выберите вариант</option>
          <option value="1-2">1-2 человека</option>
          <option value="3-4">3-4 человека</option>
          <option value="5-6">5-6 человек</option>
          <option value="7+">7 и более</option>
        </Select>
      )}

      {showUsageMode && (
        <Select
          id="lead-usage-mode"
          label="Тип проживания"
          value={usageMode}
          onChange={(e) => setUsageMode(e.target.value)}
        >
          <option value="">Выберите вариант</option>
          <option value="Постоянное">Постоянное проживание</option>
          <option value="Сезонное">Сезонное проживание</option>
        </Select>
      )}

      {showDistrict && (
        <Input
          id="lead-district"
          label="Район установки"
          placeholder="Например, Кольцово"
          value={district}
          onChange={(e) => setDistrict(e.target.value)}
        />
      )}

      {showComment && (
        <Textarea
          id="lead-comment"
          label="Комментарий"
          placeholder="Расскажите об участке или пожеланиях"
          value={comment}
          onChange={(e) => setComment(e.target.value)}
        />
      )}

      <div className="hidden" aria-hidden="true">
        <label htmlFor="companyWebsite">Оставьте это поле пустым</label>
        <input
          id="companyWebsite"
          name="companyWebsite"
          type="text"
          tabIndex={-1}
          autoComplete="off"
          value={companyWebsite}
          onChange={(e) => setCompanyWebsite(e.target.value)}
        />
      </div>

      {status === "error" && <p className="text-sm text-red-600">{errorMessage}</p>}

      <button type="submit" className="btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? "Отправляем..." : submitLabel}
      </button>

      <p className="text-center text-[13px] text-ink-400">
        Нажимая кнопку, вы соглашаетесь на обработку персональных данных
      </p>
    </form>
  );
}
