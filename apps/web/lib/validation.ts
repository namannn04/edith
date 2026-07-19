import { z } from "zod";

export const licenseKeySchema = z
  .string()
  .regex(/^EDITH-[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}$/);

export const hardwareUuidSchema = z.string().trim().min(1).max(255);

export const activationBodySchema = z
  .object({
    key: licenseKeySchema,
    hardwareUuid: hardwareUuidSchema,
    hostname: z.string().trim().min(1).max(255).optional(),
  })
  .strict();

export const verificationBodySchema = z
  .object({
    key: licenseKeySchema,
    hardwareUuid: hardwareUuidSchema,
  })
  .strict();

const licenseHeadersSchema = z.object({
  key: licenseKeySchema,
  hardwareUuid: hardwareUuidSchema,
});

export function parseLicenseHeaders(
  headers: Headers,
): z.SafeParseReturnType<
  z.input<typeof licenseHeadersSchema>,
  z.output<typeof licenseHeadersSchema>
> {
  return licenseHeadersSchema.safeParse({
    key: headers.get("x-edith-license"),
    hardwareUuid: headers.get("x-edith-machine"),
  });
}
