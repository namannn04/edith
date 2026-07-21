import { sendLicenseEmail } from "@/lib/email";
import type {
  LicenseAccess,
  LicenseStore,
  PaymentEventRecord,
} from "@/lib/license";
import {
  displaySuffix,
  generateLicenseKey,
  keyLookupDigest,
} from "@/lib/license-key";
import { readCeilings, validatePlanAllowance } from "@/lib/plans";
import {
  type RazorpayEvent,
  razorpayEventSchema,
  razorpayProvider,
} from "@/lib/razorpay";
import { customTier, getTier, pricePaiseFor } from "@/lib/pricing";

export type WebhookResult = {
  status: number;
  body: Record<string, unknown>;
};

type Fulfilment = {
  licenseId: string;
  licenseKey: string;
  planId: string;
  planName: string;
  maxMachines: number;
  email: string | null;
};

function replayResult(event: PaymentEventRecord): WebhookResult {
  if (event.processingState === "failed") {
    return {
      status: 422,
      body: { error: event.error ?? "failed", replayed: true },
    };
  }

  return {
    status: 200,
    body: { ok: true, licenseId: event.licenseId, replayed: true },
  };
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code: unknown }).code === "23505"
  );
}

export type ResolvedOrder = {
  planId: string;
  machines: number;
};

export function resolveOrder(envelope: RazorpayEvent): ResolvedOrder | null {
  const notes = envelope.payload.payment_link?.entity.notes;
  const planId = notes?.plan_id;
  const machineNote = notes?.machines;

  if (!planId || !machineNote || !/^\d+$/.test(machineNote)) {
    return null;
  }

  const machines = Number(machineNote);

  return Number.isInteger(machines) && machines > 0
    ? { planId, machines }
    : null;
}

export function planNameFor(planId: string | null): string {
  if (!planId) {
    return "Edith";
  }

  return planId === customTier.id
    ? customTier.name
    : (getTier(planId)?.name ?? planId);
}

function chargedAmountMatches(
  envelope: RazorpayEvent,
  expectedPaise: number,
): boolean {
  const link = envelope.payload.payment_link?.entity;

  return (
    link?.currency.toLowerCase() === "inr" && link.amount === expectedPaise
  );
}

export function isFullRefund(envelope: RazorpayEvent): boolean {
  const refund = envelope.payload.refund?.entity;
  const payment = envelope.payload.payment?.entity;

  if (!refund || !payment || payment.amount <= 0) {
    return false;
  }

  const refundedTotal = payment.amount_refunded ?? refund.amount;

  return refundedTotal >= payment.amount;
}

async function handlePaymentLinkPaid(
  access: LicenseAccess,
  eventId: string,
  envelope: RazorpayEvent,
  now: Date,
): Promise<{ result: WebhookResult; fulfilment?: Fulfilment }> {
  async function fail(error: string, status = 422) {
    await access.updatePaymentEvent(eventId, {
      processingState: "failed",
      error,
      processedAt: now,
    });
    return { result: { status, body: { error } } };
  }

  const resolved = resolveOrder(envelope);

  if (!resolved) {
    return fail("unknown_plan");
  }

  let expectedPaise: number;

  try {
    validatePlanAllowance(resolved.planId, resolved.machines, readCeilings());
    expectedPaise = pricePaiseFor(resolved.planId, resolved.machines);
  } catch {
    return fail("invalid_order");
  }

  if (!chargedAmountMatches(envelope, expectedPaise)) {
    return fail("amount_mismatch");
  }

  const link = envelope.payload.payment_link?.entity;
  const payment = envelope.payload.payment?.entity;
  const email = link?.customer?.email ?? payment?.email ?? null;
  const name = link?.customer?.name ?? null;
  const userId = email ? await access.upsertUserByEmail(email, name) : null;
  const key = generateLicenseKey();
  const { id: licenseId } = await access.insertLicense({
    key,
    keyDigest: keyLookupDigest(key),
    keyLast4: displaySuffix(key),
    label: null,
    planId: resolved.planId,
    maxMachines: resolved.machines,
    userId,
  });

  await access.updatePaymentEvent(eventId, {
    processingState: "processed",
    licenseId,
    processedAt: now,
  });
  await access.insertSecurityEvent({
    eventType: "license_created",
    licenseId,
    actor: "webhook",
    nextStatus: "active",
    detail: envelope.event,
  });

  return {
    result: {
      status: 200,
      body: {
        ok: true,
        licenseId,
        planId: resolved.planId,
        maxMachines: resolved.machines,
      },
    },
    fulfilment: {
      licenseId,
      licenseKey: key,
      planId: resolved.planId,
      planName: planNameFor(resolved.planId),
      maxMachines: resolved.machines,
      email,
    },
  };
}

async function handleEvent(
  access: LicenseAccess,
  providerEventId: string,
  envelope: RazorpayEvent,
): Promise<{ result: WebhookResult; fulfilment?: Fulfilment }> {
  const now = new Date();
  const link = envelope.payload.payment_link?.entity;
  const payment = envelope.payload.payment?.entity;
  const refund = envelope.payload.refund?.entity;
  const event = await access.insertPaymentEvent({
    provider: razorpayProvider,
    providerEventId,
    eventType: envelope.event,
    orderId: payment?.id ?? refund?.payment_id ?? link?.id ?? null,
    customerId:
      payment?.customer_id ??
      envelope.payload.order?.entity.customer_id ??
      null,
    priceId: link?.id ?? null,
    processingState: "received",
  });

  if (envelope.event === "payment_link.paid") {
    if (
      link?.status !== "paid" ||
      payment?.status !== "captured" ||
      payment.captured === false ||
      envelope.payload.order?.entity.status !== "paid"
    ) {
      await access.updatePaymentEvent(event.id, {
        processingState: "ignored",
        processedAt: now,
      });
      return { result: { status: 200, body: { ok: true, ignored: true } } };
    }

    return handlePaymentLinkPaid(access, event.id, envelope, now);
  }

  if (envelope.event === "refund.created") {
    const paymentId = refund?.payment_id ?? payment?.id;
    const licenseId = await access.getLicenseIdByOrderId(
      razorpayProvider,
      paymentId ?? "",
    );

    if (!licenseId) {
      await access.updatePaymentEvent(event.id, {
        processingState: "failed",
        error: "license_not_found",
        processedAt: now,
      });
      return { result: { status: 422, body: { error: "license_not_found" } } };
    }

    if (!isFullRefund(envelope)) {
      await access.insertSecurityEvent({
        eventType: "partial_refund_recorded",
        licenseId,
        actor: "webhook",
        detail: envelope.event,
      });
      await access.updatePaymentEvent(event.id, {
        processingState: "processed",
        licenseId,
        processedAt: now,
      });
      return {
        result: { status: 200, body: { ok: true, licenseId, partial: true } },
      };
    }

    const license = await access.getLicenseById(licenseId);
    await access.updateLicenseStatus(licenseId, "refunded", envelope.event);
    await access.insertSecurityEvent({
      eventType: "license_status_changed",
      licenseId,
      actor: "webhook",
      previousStatus: license?.status ?? null,
      nextStatus: "refunded",
      detail: envelope.event,
    });
    await access.updatePaymentEvent(event.id, {
      processingState: "processed",
      licenseId,
      processedAt: now,
    });
    return { result: { status: 200, body: { ok: true, licenseId } } };
  }

  await access.updatePaymentEvent(event.id, {
    processingState: "ignored",
    processedAt: now,
  });
  return { result: { status: 200, body: { ok: true, ignored: true } } };
}

async function deliver(
  store: LicenseStore,
  fulfilment: Fulfilment,
): Promise<void> {
  if (!fulfilment.email) {
    await store.insertSecurityEvent({
      eventType: "license_delivery_skipped",
      licenseId: fulfilment.licenseId,
      actor: "webhook",
      detail: "missing_email",
    });
    return;
  }

  const sent = await sendLicenseEmail({
    to: fulfilment.email,
    licenseKey: fulfilment.licenseKey,
    planName: fulfilment.planName,
    maxMachines: fulfilment.maxMachines,
  });

  await store.insertSecurityEvent({
    eventType: sent.ok ? "license_delivered" : "license_delivery_failed",
    licenseId: fulfilment.licenseId,
    actor: "webhook",
    detail: sent.ok ? sent.id : sent.error,
  });
}

function fallbackProviderEventId(envelope: RazorpayEvent): string | null {
  const entityId =
    envelope.payload.payment_link?.entity.id ??
    envelope.payload.refund?.entity.id ??
    envelope.payload.payment?.entity.id;

  return entityId ? `${envelope.event}:${entityId}` : null;
}

export async function processRazorpayWebhook(
  store: LicenseStore,
  payload: unknown,
  eventId?: string | null,
): Promise<WebhookResult> {
  const parsed = razorpayEventSchema.safeParse(payload);

  if (!parsed.success) {
    return { status: 400, body: { error: "invalid_request" } };
  }

  const providerEventId = eventId?.trim() || fallbackProviderEventId(parsed.data);

  if (!providerEventId) {
    return { status: 400, body: { error: "invalid_request" } };
  }

  const existing = await store.getPaymentEvent(
    razorpayProvider,
    providerEventId,
  );

  if (existing) {
    return replayResult(existing);
  }

  let outcome: { result: WebhookResult; fulfilment?: Fulfilment };

  try {
    outcome = await store.runExclusive(providerEventId, (access) =>
      handleEvent(access, providerEventId, parsed.data),
    );
  } catch (error) {
    if (isUniqueViolation(error)) {
      const replay = await store.getPaymentEvent(
        razorpayProvider,
        providerEventId,
      );

      if (replay) {
        return replayResult(replay);
      }
    }

    throw error;
  }

  if (outcome.fulfilment) {
    await deliver(store, outcome.fulfilment);
  }

  return outcome.result;
}
