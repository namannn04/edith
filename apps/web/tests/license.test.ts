import { describe, expect, test } from "bun:test";
import {
  activateLicense,
  type LicenseAccess,
  type LicenseRecord,
  type LicenseStore,
  type MachineInput,
} from "@/lib/license";

class FakeLicenseStore implements LicenseStore {
  private readonly machines = new Map<string, MachineInput>();

  constructor(private readonly license: LicenseRecord | null) {}

  async runExclusive<T>(
    _key: string,
    operation: (access: LicenseAccess) => Promise<T>,
  ): Promise<T> {
    return operation(this);
  }

  async getLicenseByKey(_key: string): Promise<LicenseRecord | null> {
    return this.license;
  }

  async getMachine(licenseId: string, hardwareUuid: string) {
    const machine = this.machines.get(`${licenseId}:${hardwareUuid}`);
    return machine ? { licenseId, hardwareUuid } : null;
  }

  async countMachines(licenseId: string): Promise<number> {
    return [...this.machines.values()].filter(
      (machine) => machine.licenseId === licenseId,
    ).length;
  }

  async upsertMachine(input: MachineInput): Promise<void> {
    this.machines.set(`${input.licenseId}:${input.hardwareUuid}`, input);
  }
}

const activeLicense: LicenseRecord = {
  id: "license-1",
  label: "Personal",
  maxMachines: 1,
  active: true,
};

describe("license activation", () => {
  test("reactivating the same machine is idempotent", async () => {
    const store = new FakeLicenseStore(activeLicense);
    const input = {
      key: "EDITH-1111-2222-3333-4444",
      hardwareUuid: "mac-1",
      hostname: "Studio Mac",
    };

    const first = await activateLicense(store, input);
    const second = await activateLicense(store, input);

    expect(first).toEqual({
      ok: true,
      label: "Personal",
      machinesUsed: 1,
      maxMachines: 1,
    });
    expect(second).toEqual(first);
    expect(await store.countMachines(activeLicense.id)).toBe(1);
  });

  test("rejects a new machine at the seat limit", async () => {
    const store = new FakeLicenseStore(activeLicense);
    const key = "EDITH-1111-2222-3333-4444";

    await activateLicense(store, { key, hardwareUuid: "mac-1" });
    const result = await activateLicense(store, {
      key,
      hardwareUuid: "mac-2",
    });

    expect(result).toEqual({
      ok: false,
      error: "license_limit_reached",
    });
    expect(await store.countMachines(activeLicense.id)).toBe(1);
  });

  test("rejects an inactive license", async () => {
    const store = new FakeLicenseStore({
      ...activeLicense,
      active: false,
    });

    const result = await activateLicense(store, {
      key: "EDITH-1111-2222-3333-4444",
      hardwareUuid: "mac-1",
    });

    expect(result).toEqual({ ok: false, error: "invalid_license" });
    expect(await store.countMachines(activeLicense.id)).toBe(0);
  });
});
