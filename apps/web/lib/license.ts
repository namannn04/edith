export type LicenseRecord = {
  id: string;
  label: string | null;
  maxMachines: number;
  active: boolean;
};

export type MachineRecord = {
  licenseId: string;
  hardwareUuid: string;
};

export type MachineInput = {
  licenseId: string;
  hardwareUuid: string;
  hostname: string | null;
};

export interface LicenseAccess {
  getLicenseByKey(key: string): Promise<LicenseRecord | null>;
  getMachine(
    licenseId: string,
    hardwareUuid: string,
  ): Promise<MachineRecord | null>;
  countMachines(licenseId: string): Promise<number>;
  upsertMachine(input: MachineInput): Promise<void>;
}

export interface LicenseStore extends LicenseAccess {
  runExclusive<T>(
    key: string,
    operation: (access: LicenseAccess) => Promise<T>,
  ): Promise<T>;
}

export type ActivationInput = {
  key: string;
  hardwareUuid: string;
  hostname?: string;
};

export type ActivationResult =
  | {
      ok: true;
      label: string | null;
      machinesUsed: number;
      maxMachines: number;
    }
  | {
      ok: false;
      error: "invalid_license" | "license_limit_reached";
    };

export async function activateLicense(
  store: LicenseStore,
  input: ActivationInput,
): Promise<ActivationResult> {
  return store.runExclusive(input.key, async (access) => {
    const license = await access.getLicenseByKey(input.key);

    if (!license?.active) {
      return { ok: false, error: "invalid_license" };
    }

    const existingMachine = await access.getMachine(
      license.id,
      input.hardwareUuid,
    );

    if (!existingMachine) {
      const machinesUsed = await access.countMachines(license.id);

      if (machinesUsed >= license.maxMachines) {
        return { ok: false, error: "license_limit_reached" };
      }
    }

    await access.upsertMachine({
      licenseId: license.id,
      hardwareUuid: input.hardwareUuid,
      hostname: input.hostname ?? null,
    });

    const machinesUsed = await access.countMachines(license.id);

    return {
      ok: true,
      label: license.label,
      machinesUsed,
      maxMachines: license.maxMachines,
    };
  });
}

export async function verifyLicense(
  store: LicenseAccess,
  key: string,
  hardwareUuid: string,
): Promise<boolean> {
  const license = await store.getLicenseByKey(key);

  if (!license?.active) {
    return false;
  }

  const machine = await store.getMachine(license.id, hardwareUuid);
  return machine !== null;
}
