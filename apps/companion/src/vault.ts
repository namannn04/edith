import { mkdir, stat, writeFile } from "node:fs/promises";
import { basename, join, relative } from "node:path";

export async function writeVaultFile(
  vaultDir: string,
  sha256: string,
  name: string,
  text: string,
): Promise<string> {
  const directory = join(vaultDir, "objects", sha256.slice(0, 2), sha256);
  const path = join(directory, basename(name));

  try {
    await stat(path);
  } catch {
    await mkdir(directory, { recursive: true });
    await writeFile(path, text, { flag: "wx" }).catch(
      async (error: unknown) => {
        if (
          !(error instanceof Error) ||
          !("code" in error) ||
          error.code !== "EEXIST"
        ) {
          throw error;
        }
      },
    );
  }

  return relative(vaultDir, path);
}
