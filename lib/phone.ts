export function formatPhoneInput(raw: string): string {
  const digits = raw.replace(/\D/g, "").replace(/^8/, "7").slice(0, 11);
  if (!digits) return "";

  let normalized = digits;
  if (normalized[0] !== "7") normalized = `7${normalized}`;
  normalized = normalized.slice(0, 11);

  const rest = normalized.slice(1);
  let out = "+7";
  if (rest.length > 0) out += ` (${rest.slice(0, 3)}`;
  if (rest.length >= 3) out += ")";
  if (rest.length > 3) out += ` ${rest.slice(3, 6)}`;
  if (rest.length > 6) out += `-${rest.slice(6, 8)}`;
  if (rest.length > 8) out += `-${rest.slice(8, 10)}`;
  return out;
}

export function isValidRussianPhone(value: string): boolean {
  const digits = value.replace(/\D/g, "");
  return digits.length === 11 && (digits.startsWith("7") || digits.startsWith("8"));
}
