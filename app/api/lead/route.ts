import { NextRequest, NextResponse } from "next/server";
import { LeadFormPayload } from "@/types";
import { dispatchLead } from "@/services/notify";

export async function POST(req: NextRequest) {
  let payload: LeadFormPayload;

  try {
    payload = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "invalid body" }, { status: 400 });
  }

  if (!payload.name || !payload.phone) {
    return NextResponse.json({ ok: false, error: "missing fields" }, { status: 400 });
  }

  if (payload.companyWebsite) {
    return NextResponse.json({ ok: true });
  }

  await dispatchLead(payload);

  return NextResponse.json({ ok: true });
}
