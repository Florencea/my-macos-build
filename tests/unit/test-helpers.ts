import fs from "node:fs/promises";
import type { CommandContext, CommandRunner } from "../../cli/src/lib/context.ts";

export function createTestContext(overrides?: {
  readonly runner?: Partial<CommandRunner>;
  readonly env?: Readonly<Record<string, string | undefined>>;
  readonly isTty?: boolean;
  readonly dryRun?: boolean;
  readonly repoRoot?: string;
}): {
  readonly ctx: CommandContext;
  readonly getStdout: () => string;
  readonly getStderr: () => string;
} {
  let out = "";
  let err = "";
  const defaultRunner: CommandRunner = {
    commandExists: async () => true,
    exec: async () => ({ exitCode: 0, stdout: "", stderr: "" }),
    pipe: async () => ({ leftExitCode: 0, rightExitCode: 0, stdout: "", stderr: "" }),
    spawnInteractive: async () => 0,
    cleanupActiveProcesses: () => {},
    ...overrides?.runner,
  };

  const ctx: CommandContext = {
    runner: defaultRunner,
    fs,
    fetch: globalThis.fetch,
    env: overrides?.env ?? {},
    cwd: "/workspace",
    platform: "darwin",
    repoRoot: overrides?.repoRoot ?? "/workspace/my-machine-build",
    stdout: (text: string) => {
      out += text;
    },
    stderr: (text: string) => {
      err += text;
    },
    isTty: overrides?.isTty ?? false,
    dryRun: overrides?.dryRun ?? false,
    now: () => new Date("2026-01-01T00:00:00Z"),
    onSignalCleanup: () => () => {},
  };

  return {
    ctx,
    getStdout: () => out,
    getStderr: () => err,
  };
}
