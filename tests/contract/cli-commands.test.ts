import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import { describe, expect, it } from "vite-plus/test";
import { z } from "zod";
import { handleCliError } from "../../cli/src/lib/cli-framework.ts";
import { UsageError } from "../../cli/src/lib/context.ts";
import { CLI_COMMANDS, COMMAND_NAMES } from "../../cli/src/registry.ts";
import { createTestContext } from "../unit/test-helpers.ts";

const execFileAsync = promisify(execFile);
const REPO_ROOT = path.resolve(import.meta.dirname, "../..");
const BIN_DIR = path.join(REPO_ROOT, "cli", "bin");
const COMPLETIONS_DIR = path.join(REPO_ROOT, "configs", "zsh", "completions");

const EXPECTED_COMMANDS = [
  "clall",
  "ebk",
  "mdig",
  "mkclp",
  "mkgif",
  "mmb",
  "rea",
  "ua",
  "unodev",
  "up",
  "upnpmv",
  "webread",
] as const;

const ExecErrorSchema = z.object({
  code: z.union([z.number(), z.string()]),
  stderr: z.string(),
});

async function captureUsageError(
  run: () => Promise<number>,
  helpText: string,
): Promise<{ readonly isUsageError: boolean; readonly exitCode: number; readonly stderr: string }> {
  try {
    const code = await run();
    return { isUsageError: false, exitCode: code, stderr: "" };
  } catch (err) {
    let stderrText = "";
    const exitCode = handleCliError(err, helpText, (chunk) => {
      stderrText += chunk;
    });
    return {
      isUsageError: err instanceof UsageError,
      exitCode,
      stderr: stderrText,
    };
  }
}

describe("all 12 CLI commands parity, completions, and symlink contract", () => {
  it("registers all 12 expected commands in registry.ts", () => {
    expect([...COMMAND_NAMES].toSorted((a, b) => a.localeCompare(b))).toEqual([
      ...EXPECTED_COMMANDS,
    ]);
    expect(CLI_COMMANDS.size).toBe(12);
  });

  it("supports --help / -h, rejects unknown flags, and enforces positional bounds across all 12 commands", async () => {
    const results = await Promise.all(
      COMMAND_NAMES.map(async (cmdName) => {
        const cmd = CLI_COMMANDS.get(cmdName);
        if (cmd === undefined) {
          throw new Error(`Missing registered command: ${cmdName}`);
        }

        const helpRun = createTestContext();
        const helpExit = await cmd.execute(["--help"], helpRun.ctx);

        const shortHelpRun = createTestContext();
        const shortHelpExit = await cmd.execute(["-h"], shortHelpRun.ctx);

        const badFlagResult = await captureUsageError(
          () => cmd.execute(["--unknown-flag-test"], createTestContext().ctx),
          cmd.formatHelp(),
        );

        const posSpec = cmd.positionals ?? { min: 0, max: 0, label: "" };
        const extraPosResult = Number.isFinite(posSpec.max)
          ? await captureUsageError(
              () =>
                cmd.execute(
                  Array.from({ length: posSpec.max + 1 }, (_, idx) => `arg-${idx.toString()}`),
                  createTestContext().ctx,
                ),
              cmd.formatHelp(),
            )
          : { isUsageError: true, exitCode: 2, stderr: "Unexpected argument" };

        const missingPosResult =
          posSpec.min > 0
            ? await captureUsageError(
                () => cmd.execute([], createTestContext().ctx),
                cmd.formatHelp(),
              )
            : { isUsageError: true, exitCode: 2, stderr: "Missing required argument" };

        return {
          cmdName,
          helpExit,
          helpStdout: helpRun.getStdout(),
          shortHelpExit,
          shortHelpStdout: shortHelpRun.getStdout(),
          badFlagResult,
          extraPosResult,
          missingPosResult,
        };
      }),
    );

    for (const res of results) {
      expect(res.helpExit).toBe(0);
      expect(res.helpStdout).toContain(`${res.cmdName}:`);
      expect(res.shortHelpExit).toBe(0);
      expect(res.shortHelpStdout).toBe(res.helpStdout);

      expect(res.badFlagResult.isUsageError).toBe(true);
      expect(res.badFlagResult.exitCode).toBe(2);
      expect(res.badFlagResult.stderr).toContain("Unknown option");

      expect(res.extraPosResult.isUsageError).toBe(true);
      expect(res.extraPosResult.exitCode).toBe(2);
      expect(res.extraPosResult.stderr).toContain("Unexpected argument");

      expect(res.missingPosResult.isUsageError).toBe(true);
      expect(res.missingPosResult.exitCode).toBe(2);
      expect(res.missingPosResult.stderr).toContain("Missing required argument");
    }

    const mkclpHelp = results.find((entry) => entry.cmdName === "mkclp")?.helpStdout ?? "";
    const mkgifHelp = results.find((entry) => entry.cmdName === "mkgif")?.helpStdout ?? "";
    expect(mkclpHelp).toMatch(/default:\s*chrome/);
    expect(mkgifHelp).toMatch(/default:\s*chrome/);
  });

  it("maintains flag parity between command definitions and configs/zsh/completions", async () => {
    const completionEntries = await Promise.all(
      COMMAND_NAMES.map(async (cmdName) => {
        const cmd = CLI_COMMANDS.get(cmdName);
        if (cmd === undefined) {
          throw new Error(`Missing registered command: ${cmdName}`);
        }
        const completionPath = path.join(COMPLETIONS_DIR, `_${cmdName}`);
        const content = await fs.readFile(completionPath, "utf8");
        return { cmdName, cmd, content };
      }),
    );

    const missingTokens: string[] = [];
    const extraCompletionFlags: string[] = [];

    for (const { cmdName, cmd, content } of completionEntries) {
      expect(content.startsWith(`#compdef ${cmdName}`)).toBe(true);

      for (const [flagName, flagSpec] of Object.entries(cmd.flags)) {
        if (!content.includes(`--${flagName}`)) {
          missingTokens.push(`${cmdName}:--${flagName}`);
        }
        if (flagSpec.short !== undefined && !content.includes(`-${flagSpec.short}`)) {
          missingTokens.push(`${cmdName}:-${flagSpec.short}`);
        }
      }

      for (const match of content.matchAll(/--([a-z0-9-]+)/g)) {
        const captured = match[1];
        if (captured !== undefined && captured !== "help" && !Object.hasOwn(cmd.flags, captured)) {
          extraCompletionFlags.push(`${cmdName}:--${captured}`);
        }
      }
    }

    expect(missingTokens).toEqual([]);
    expect(extraCompletionFlags).toEqual([]);
  });

  it.skipIf(process.platform === "win32")(
    "enforces positional rejection via extensionless symlinks outside repo for Stage 4 commands",
    async () => {
      const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-cmd-contract-"));
      try {
        const stage4Commands = ["unodev", "upnpmv", "ua", "up"] as const;
        const checks = await Promise.all(
          stage4Commands.map(async (name) => {
            const symlinkPath = path.join(tempDir, `${name}-exec`);
            await fs.symlink(path.join(BIN_DIR, name), symlinkPath);

            const helpRes = await execFileAsync(symlinkPath, ["--help"], { cwd: tempDir });
            let posExitCode = 0;
            let posStderr = "";
            try {
              await execFileAsync(symlinkPath, ["unexpected-arg"], { cwd: tempDir });
            } catch (err) {
              const parsed = ExecErrorSchema.safeParse(err);
              if (parsed.success) {
                posExitCode = Number(parsed.data.code);
                posStderr = parsed.data.stderr;
              }
            }
            return { name, helpStdout: helpRes.stdout, posExitCode, posStderr };
          }),
        );

        for (const item of checks) {
          expect(item.helpStdout).toContain(`${item.name}:`);
          expect(item.posExitCode).toBe(2);
          expect(item.posStderr).toContain("Unexpected argument");
        }
      } finally {
        await fs.rm(tempDir, { recursive: true, force: true });
      }
    },
  );
});
