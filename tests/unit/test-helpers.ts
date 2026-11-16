import fs from "node:fs/promises";

import { z } from "zod";

import type { CommandContext, CommandRunner, DnsPort } from "../../cli/src/lib/context.ts";

export const ExecErrorSchema = z.object({
  code: z.union([z.number(), z.string()]),
  stderr: z.string(),
});

export function createTestContext(overrides?: {
  readonly runner?: Partial<CommandRunner>;
  readonly fetch?: typeof globalThis.fetch;
  readonly dns?: DnsPort;
  readonly env?: Readonly<Record<string, string | undefined>>;
  readonly cwd?: string;
  readonly platform?: NodeJS.Platform;
  readonly isTty?: boolean;
  readonly dryRun?: boolean;
  readonly repoRoot?: string;
  readonly now?: () => Date;
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
  const defaultDns: DnsPort = overrides?.dns ?? {
    resolve: async () => [],
  };

  const ctx: CommandContext = {
    runner: defaultRunner,
    fs,
    fetch: overrides?.fetch ?? globalThis.fetch,
    dns: defaultDns,
    env: overrides?.env ?? {},
    cwd: overrides?.cwd ?? "/workspace",
    platform: overrides?.platform ?? "darwin",
    repoRoot: overrides?.repoRoot ?? "/workspace/my-machine-build",
    stdout: (text: string) => {
      out += text;
    },
    stderr: (text: string) => {
      err += text;
    },
    isTty: overrides?.isTty ?? false,
    dryRun: overrides?.dryRun ?? false,
    now: overrides?.now ?? (() => new Date("2026-01-01T00:00:00Z")),
    onSignalCleanup: () => () => {},
  };

  return {
    ctx,
    getStdout: () => out,
    getStderr: () => err,
  };
}
