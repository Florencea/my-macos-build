import { Resolver } from "node:dns/promises";
import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { z } from "zod";

export const ErrnoCodeSchema = z.object({ code: z.string() });

interface DnsQueryInput {
  readonly domain: string;
  readonly recordType: "A" | "AAAA";
  readonly serverIp?: string;
  readonly timeoutMs?: number;
}

export interface DnsPort {
  resolve(input: DnsQueryInput): Promise<readonly string[]>;
}

function createNodeDnsPort(): DnsPort {
  return {
    async resolve(input: DnsQueryInput): Promise<readonly string[]> {
      const resolver = new Resolver({
        timeout: input.timeoutMs ?? 2000,
        tries: 1,
      });
      if (input.serverIp !== undefined && input.serverIp !== "") {
        resolver.setServers([input.serverIp]);
      }
      return input.recordType === "A"
        ? await resolver.resolve4(input.domain)
        : await resolver.resolve6(input.domain);
    },
  };
}

export interface CommandExecOptions {
  readonly cwd?: string;
  readonly env?: Readonly<Record<string, string | undefined>>;
  readonly stdin?: string | Uint8Array;
  readonly timeoutMs?: number;
  readonly signal?: AbortSignal;
}

export interface CommandExecResult {
  readonly exitCode: number;
  readonly stdout: string;
  readonly stderr: string;
}

export interface PipeCommandSpec {
  readonly command: string;
  readonly args: readonly string[];
}

export interface PipeExecResult {
  readonly leftExitCode: number;
  readonly rightExitCode: number;
  readonly stdout: string;
  readonly stderr: string;
}

export interface CommandRunner {
  commandExists(
    name: string,
    options?: {
      readonly env?: Readonly<Record<string, string | undefined>>;
      readonly platform?: NodeJS.Platform;
    },
  ): Promise<boolean>;
  exec(
    command: string,
    args: readonly string[],
    options?: CommandExecOptions,
  ): Promise<CommandExecResult>;
  pipe(
    left: PipeCommandSpec,
    right: PipeCommandSpec,
    options?: CommandExecOptions,
  ): Promise<PipeExecResult>;
  spawnInteractive(
    command: string,
    args: readonly string[],
    options?: CommandExecOptions,
  ): Promise<number>;
  cleanupActiveProcesses(): void;
}

export interface CommandContext {
  readonly runner: CommandRunner;
  readonly fs: typeof fs;
  readonly fetch: typeof globalThis.fetch;
  readonly dns: DnsPort;
  readonly env: Readonly<Record<string, string | undefined>>;
  readonly cwd: string;
  readonly platform: NodeJS.Platform;
  readonly repoRoot: string;
  readonly stdout: (text: string) => void;
  readonly stderr: (text: string) => void;
  readonly isTty: boolean;
  readonly dryRun: boolean;
  readonly now: () => Date;
  readonly signal?: AbortSignal;
  readonly onSignalCleanup: (handler: () => void | Promise<void>) => () => void;
}

export class CliError extends Error {
  readonly exitCode: number;

  constructor(message: string, exitCode = 1) {
    super(message);
    this.name = "CliError";
    this.exitCode = exitCode;
  }
}

export class UsageError extends CliError {
  readonly includeHelp: boolean;

  constructor(message: string, includeHelp = true) {
    super(message, 2);
    this.name = "UsageError";
    this.includeHelp = includeHelp;
  }
}

export class MissingDependencyError extends CliError {
  constructor(commandName: string) {
    super(`Error: ${commandName} is not installed`, 127);
    this.name = "MissingDependencyError";
  }
}

export class ExecutionError extends CliError {
  constructor(message: string, exitCode = 1) {
    super(message, exitCode);
    this.name = "ExecutionError";
  }
}

const ONE_KB = 1024;
const ONE_MB = 1024 * 1024;
const ONE_GB = 1024 * 1024 * 1024;

export function formatByteSize(byteCount: number): string {
  if (byteCount >= ONE_GB) {
    return `${(byteCount / ONE_GB).toFixed(1)}G`;
  }
  if (byteCount >= ONE_MB) {
    return `${(byteCount / ONE_MB).toFixed(1)}M`;
  }
  return `${Math.round(byteCount / ONE_KB).toString()}K`;
}

export function formatErrorMessage(err: unknown): string {
  if (err instanceof Error) {
    return err.message;
  }
  if (typeof err === "string") {
    return err;
  }
  if (typeof err === "number" || typeof err === "boolean") {
    return err.toString();
  }
  try {
    return JSON.stringify(err) ?? "Unknown error";
  } catch {
    return "Unknown error";
  }
}

export function formatNativeErrorDetail(
  outputLines: readonly (string | null | undefined)[],
  exitCode = 1,
): string {
  const cleaned = outputLines
    .map((line) => (line === null || line === undefined ? "" : line.trim()))
    .filter((line) => line !== "");

  if (cleaned.length > 0) {
    return cleaned.join(" | ");
  }
  return `exit code ${exitCode.toString()}`;
}

export function parseEnvWithSchema<TSchema extends z.ZodType>(
  env: Readonly<Record<string, string | undefined>>,
  schema: TSchema,
): z.infer<TSchema> {
  const result = schema.safeParse(env);
  if (!result.success) {
    const detail = result.error.issues.map((issue) => issue.message).join("; ");
    throw new UsageError(`Error: Invalid environment configuration (${detail})`, false);
  }
  return result.data;
}

function resolveRepoRoot(fromDir = import.meta.dirname): string {
  // cli/src/lib -> repo root
  return path.resolve(fromDir, "../../..");
}

export interface NodeContextOverrides {
  readonly runner: CommandRunner;
  readonly dns?: DnsPort;
  readonly repoRoot?: string;
  readonly dryRun?: boolean;
  readonly signal?: AbortSignal;
  readonly onSignalCleanup?: (handler: () => void | Promise<void>) => () => void;
}

function noopCleanup(): () => void {
  return () => {};
}

export function createNodeCommandContext(overrides: NodeContextOverrides): CommandContext {
  return {
    runner: overrides.runner,
    fs,
    fetch: globalThis.fetch,
    dns: overrides.dns ?? createNodeDnsPort(),
    env: process.env,
    cwd: process.cwd(),
    platform: process.platform,
    repoRoot: overrides.repoRoot ?? resolveRepoRoot(),
    stdout: (text: string) => {
      process.stdout.write(text);
    },
    stderr: (text: string) => {
      process.stderr.write(text);
    },
    isTty: process.stderr.isTTY,
    dryRun: overrides.dryRun ?? false,
    now: () => new Date(),
    signal: overrides.signal,
    onSignalCleanup: overrides.onSignalCleanup ?? noopCleanup,
  };
}
