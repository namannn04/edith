import { z } from "zod";

const defaultFrom = "Edith <licenses-edith@pulkit.page>";

export type LicenseEmailInput = {
  to: string;
  licenseKey: string;
  planName: string;
  maxMachines: number;
};

export type EmailResult =
  | { ok: true; id: string }
  | { ok: false; error: string };

const sendResponseSchema = z.object({ id: z.string().min(1) });

export function licenseEmailSubject(): string {
  return "Your Edith license key";
}

export function licenseEmailText(input: LicenseEmailInput): string {
  const seats =
    input.maxMachines === 1 ? "1 Mac" : `${input.maxMachines} Macs`;

  return [
    "Thanks for buying Edith.",
    "",
    `License key: ${input.licenseKey}`,
    `Plan: ${input.planName} (${seats})`,
    "",
    "To activate, open Edith, choose Enter License Key, and paste the key above.",
    "Your licence is a one-time purchase and does not expire.",
    "",
    "Lost this email? You can have your key sent again from https://edith.pulkit.page/license",
  ].join("\n");
}

export function licenseEmailHtml(input: LicenseEmailInput): string {
  const seats =
    input.maxMachines === 1 ? "1 Mac" : `${input.maxMachines} Macs`;

  return [
    '<div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;font-size:15px;line-height:1.6;color:#111">',
    "<p>Thanks for buying Edith.</p>",
    `<p style="font-size:20px;font-weight:600;letter-spacing:0.04em;margin:24px 0">${input.licenseKey}</p>`,
    `<p>Plan: <strong>${input.planName}</strong> (${seats})</p>`,
    "<p>To activate, open Edith, choose <strong>Enter License Key</strong>, and paste the key above.</p>",
    "<p>Your licence is a one-time purchase and does not expire.</p>",
    '<p>Lost this email? You can have your key sent again from <a href="https://edith.pulkit.page/license">your licence page</a>.</p>',
    "</div>",
  ].join("");
}

export type RecoveredLicense = {
  licenseKey: string;
  planName: string;
  maxMachines: number;
};

function describeLicence(licence: RecoveredLicense): string {
  const seats =
    licence.maxMachines === 1 ? "1 Mac" : `${licence.maxMachines} Macs`;

  return `${licence.licenseKey} — ${licence.planName} (${seats})`;
}

export async function sendLicenseRecoveryEmail(
  to: string,
  licences: RecoveredLicense[],
): Promise<EmailResult> {
  const apiKey = process.env.RESEND_API_KEY;

  if (!apiKey) {
    return { ok: false, error: "missing_api_key" };
  }

  const heading =
    licences.length === 1
      ? "Here is your Edith license key."
      : `Here are your ${licences.length} Edith license keys.`;

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: process.env.LICENSE_EMAIL_FROM ?? defaultFrom,
        to: [to],
        subject:
          licences.length === 1
            ? "Your Edith license key"
            : "Your Edith license keys",
        text: [
          heading,
          "",
          ...licences.map(describeLicence),
          "",
          "To activate, open Edith, choose Enter License Key, and paste a key above.",
          "",
          "If you did not request this, you can ignore this email.",
        ].join("\n"),
        html: [
          '<div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;font-size:15px;line-height:1.6;color:#111">',
          `<p>${heading}</p>`,
          ...licences.map(
            (licence) =>
              `<p style="margin:16px 0"><span style="font-size:18px;font-weight:600;letter-spacing:0.04em">${licence.licenseKey}</span><br>${licence.planName} (${licence.maxMachines === 1 ? "1 Mac" : `${licence.maxMachines} Macs`})</p>`,
          ),
          "<p>To activate, open Edith, choose <strong>Enter License Key</strong>, and paste a key above.</p>",
          "<p>If you did not request this, you can ignore this email.</p>",
          "</div>",
        ].join(""),
      }),
    });

    if (!response.ok) {
      return { ok: false, error: `send_failed_${response.status}` };
    }

    return { ok: true, id: sendResponseSchema.parse(await response.json()).id };
  } catch {
    return { ok: false, error: "send_error" };
  }
}

export async function sendLicenseEmail(
  input: LicenseEmailInput,
): Promise<EmailResult> {
  const apiKey = process.env.RESEND_API_KEY;

  if (!apiKey) {
    return { ok: false, error: "missing_api_key" };
  }

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: process.env.LICENSE_EMAIL_FROM ?? defaultFrom,
        to: [input.to],
        subject: licenseEmailSubject(),
        text: licenseEmailText(input),
        html: licenseEmailHtml(input),
      }),
    });

    if (!response.ok) {
      return { ok: false, error: `send_failed_${response.status}` };
    }

    return { ok: true, id: sendResponseSchema.parse(await response.json()).id };
  } catch {
    return { ok: false, error: "send_error" };
  }
}
