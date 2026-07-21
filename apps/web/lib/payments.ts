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
  type PolarEvent,
  planIdForProduct,
  polarEventSchema,
  polarProvider,
} from "@/lib/polar";
import { customTier, getTier, priceCentsFor } from "@/lib/pricing";

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

export function resolveOrder(envelope: PolarEvent): ResolvedOrder | null {
  const metadata = envelope.data.metadata ?? {};
  const planId =
    typeof metadata.plan_id === "string" ? metadata.plan_id : null;
  const machines = Number(metadata.machines);

  if (planId && Number.isInteger(machines) && machines > 0) {
    return { planId, machines };
  }

  const productId = envelope.data.product_id;
  const fallbackPlanId = productId ? planIdForProduct(productId) : null;

  if (!fallbackPlanId || fallbackPlanId === customTier.id) {
    return null;
  }

  const tier = getTier(fallbackPlanId);

  return tier ? { planId: tier.id, machines: tier.maxMachines } : null;
}

export function planNameFor(planId: string): string {
  return planId === customTier.id
    ? customTier.name
    : (getTier(planId)?.name ?? planId);
}

function chargedAmountMatches(
  envelope: PolarEvent,
  expectedCents: number,
): boolean {
  const currency = envelope.data.currency;

  if (currency && currency.toLowerCase() !== "usd") {
    return true;
  }

  const charged = envelope.data.subtotal_amount;

  if (typeof charged !== "number") {
    return true;
  }

  return charged === expectedCents;
}

async function handleOrderPaid(
  access: LicenseAccess,
  eventId: string,
  envelope: PolarEvent,
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

  let expectedCents: number;

  try {
    validatePlanAllowance(resolved.planId, resolved.machines, readCeilings());
    expectedCents = priceCentsFor(resolved.planId, resolved.machines);
  } catch {
    return fail("invalid_order");
  }

  if (!chargedAmountMatches(envelope, expectedCents)) {
    return fail("amount_mismatch");
  }

  const email = envelope.data.customer?.email ?? null;
  const name = envelope.data.customer?.name ?? null;
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
    detail: envelope.type,
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
  envelope: PolarEvent,
): Promise<{ result: WebhookResult; fulfilment?: Fulfilment }> {
  const now = new Date();
  const event = await access.insertPaymentEvent({
    provider: polarProvider,
    providerEventId,
    eventType: envelope.type,
    orderId: envelope.data.id,
    customerId: envelope.data.customer_id ?? null,
    priceId: envelope.data.product_id ?? null,
    processingState: "received",
  });

  if (envelope.type === "order.paid") {
    if (envelope.data.paid === false || envelope.data.status === "pending") {
      await access.updatePaymentEvent(event.id, {
        processingState: "ignored",
        processedAt: now,
      });
      return { result: { status: 200, body: { ok: true, ignored: true } } };
    }

    return handleOrderPaid(access, event.id, envelope, now);
  }

  if (envelope.type === "order.refunded") {
    const licenseId = await access.getLicenseIdByOrderId(
      polarProvider,
      envelope.data.id,
    );

    if (!licenseId) {
      await access.updatePaymentEvent(event.id, {
        processingState: "failed",
        error: "license_not_found",
        processedAt: now,
      });
      return { result: { status: 422, body: { error: "license_not_found" } } };
    }

    const license = await access.getLicenseById(licenseId);
    await access.updateLicenseStatus(licenseId, "refunded", envelope.type);
    await access.insertSecurityEvent({
      eventType: "license_status_changed",
      licenseId,
      actor: "webhook",
      previousStatus: license?.status ?? null,
      nextStatus: "refunded",
      detail: envelope.type,
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

export async function processPolarWebhook(
  store: LicenseStore,
  payload: unknown,
): Promise<WebhookResult> {
  const parsed = polarEventSchema.safeParse(payload);

  if (!parsed.success) {
    return { status: 400, body: { error: "invalid_request" } };
  }

  const providerEventId = `${parsed.data.type}:${parsed.data.data.id}`;
  const existing = await store.getPaymentEvent(polarProvider, providerEventId);

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
        polarProvider,
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
