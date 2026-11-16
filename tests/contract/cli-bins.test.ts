import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";

import { describe, expect, it } from "vite-plus/test";

import { COMMAND_NAMES } from "../../cli/src/registry.ts";
import { renderPosixShim, renderWindowsShim } from "../../scripts/sync-cli-bins.ts";
import { ExecErrorSchema } from "../unit/test-helpers.ts";

const execFileAsync = promisify(execFile);
const REPO_ROOT = path.resolve(import.meta.dirname, "../..");
const BIN_DIR = path.join(REPO_ROOT, "cli", "bin");

describe("cli/bin generated wrappers contract", () => {
  it("matches registry COMMAND_NAMES with zero drift", async () => {
    const entries = await fs.readdir(BIN_DIR);
    const expected = new Set<string>();
    for (const name of COMMAND_NAMES) {
      expected.add(name);
      expected.add(`${name}.cmd`);
    }
    expect(new Set(entries)).toEqual(expected);

    const fileChecks = await Promise.all(
      COMMAND_NAMES.map(async (name) => {
        const posixPath = path.join(BIN_DIR, name);
        const cmdPath = path.join(BIN_DIR, `${name}.cmd`);
        const [posixRaw, cmdRaw, stat] = await Promise.all([
          fs.readFile(posixPath, "utf8"),
          fs.readFile(cmdPath, "utf8"),
          fs.stat(posixPath),
        ]);
        return { name, posixRaw, cmdRaw, mode: stat.mode };
      }),
    );

    for (const entry of fileChecks) {
      expect(entry.posixRaw).toBe(renderPosixShim(entry.name));
      expect(entry.cmdRaw).toBe(renderWindowsShim(entry.name));
      expect(process.platform === "win32" || (entry.mode & 0o111) !== 0).toBe(true);
    }
  });

  it.skipIf(process.platform === "win32")(
    "executes registered POSIX shims via extensionless symlink from outside repo",
    async () => {
      const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-shim-test-"));
      try {
        const results = await Promise.all(
          COMMAND_NAMES.map(async (name) => {
            const symlinkPath = path.join(tempDir, `${name}-link`);
            await fs.symlink(path.join(BIN_DIR, name), symlinkPath);

            const helpRes = await execFileAsync(symlinkPath, ["--help"], { cwd: tempDir });
            let exitCode = 0;
            let stderr = "";
            try {
              await execFileAsync(symlinkPath, ["--unknown-flag-test"], { cwd: tempDir });
            } catch (err) {
              const parsedErr = ExecErrorSchema.safeParse(err);
              if (parsedErr.success) {
                exitCode = Number(parsedErr.data.code);
                stderr = parsedErr.data.stderr;
              }
            }
            return { name, helpStdout: helpRes.stdout, exitCode, stderr };
          }),
        );

        for (const res of results) {
          expect(res.helpStdout).toContain(`${res.name}:`);
          expect(res.exitCode).toBe(2);
          expect(res.stderr).toContain("Unknown option");
        }
      } finally {
        await fs.rm(tempDir, { recursive: true, force: true });
      }
    },
  );
});
