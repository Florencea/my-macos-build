import { spawn, type ChildProcess } from "node:child_process";
import { constants as fsConstants } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { z } from "zod";
import type {
  CommandExecOptions,
  CommandExecResult,
  CommandRunner,
  PipeCommandSpec,
  PipeExecResult,
} from "./context.ts";

const ErrnoCodeSchema = z.object({ code: z.string() });

export function buildSpawnEnv(
  baseEnv: Readonly<Record<string, string | undefined>>,
  overrideEnv?: Readonly<Record<string, string | undefined>>,
  platform: NodeJS.Platform = process.platform,
): NodeJS.ProcessEnv {
  if (overrideEnv === undefined) {
    return { ...baseEnv };
  }

  const merged: NodeJS.ProcessEnv = { ...baseEnv };
  if (platform !== "win32") {
    for (const [key, value] of Object.entries(overrideEnv)) {
      if (value === undefined) {
        delete merged[key];
      } else {
        merged[key] = value;
      }
    }
    return merged;
  }

  // On Windows, plain JS objects are case-sensitive unlike process.env; collapse existing case variants.
  const keyIndex = new Map<string, string>();
  for (const existingKey of Object.keys(merged)) {
    keyIndex.set(existingKey.toLowerCase(), existingKey);
  }

  for (const [key, value] of Object.entries(overrideEnv)) {
    const lowerKey = key.toLowerCase();
    const prevKey = keyIndex.get(lowerKey);
    if (prevKey !== undefined && prevKey !== key) {
      delete merged[prevKey];
    }
    if (value === undefined) {
      delete merged[key];
      keyIndex.delete(lowerKey);
    } else {
      merged[key] = value;
      keyIndex.set(lowerKey, key);
    }
  }
  return merged;
}

function getPathEnvValue(env: Readonly<Record<string, string | undefined>>): string {
  const direct = env["PATH"];
  if (direct !== undefined && direct !== "") {
    return direct;
  }
  for (const [key, value] of Object.entries(env)) {
    if (key.toUpperCase() === "PATH" && value !== undefined && value !== "") {
      return value;
    }
  }
  return "";
}

export async function isExecutableFile(
  filePath: string,
  platform: NodeJS.Platform,
): Promise<boolean> {
  try {
    const stats = await fs.stat(filePath);
    if (!stats.isFile()) {
      return false;
    }
    if (platform === "win32") {
      return true;
    }
    await fs.access(filePath, fsConstants.X_OK);
    return true;
  } catch {
    return false;
  }
}

export async function resolveExecutableInPath(
  name: string,
  env: Readonly<Record<string, string | undefined>>,
  platform: NodeJS.Platform,
): Promise<string | null> {
  if (name.trim() === "") {
    return null;
  }

  const hasSeparator = name.includes("/") || name.includes("\\");
  if (hasSeparator) {
    return (await isExecutableFile(name, platform)) ? path.resolve(name) : null;
  }

  const pathVar = getPathEnvValue(env);
  if (pathVar === "") {
    return null;
  }

  const delimiter = platform === "win32" ? ";" : ":";
  const pathDirs = pathVar.split(delimiter).filter((entry) => entry.trim() !== "");

  const extensions =
    platform === "win32"
      ? (env["PATHEXT"] ?? ".COM;.EXE;.BAT;.CMD;.PS1")
          .split(";")
          .map((ext) => ext.trim())
          .filter((ext) => ext !== "")
      : [""];

  const hasExplicitExtension = path.extname(name) !== "";
  const candidates: string[] = [];

  for (const dir of pathDirs) {
    if (platform === "win32") {
      const exactCandidate = path.join(dir, name);
      if (hasExplicitExtension) {
        candidates.push(exactCandidate);
      }
      for (const ext of extensions) {
        const withExt = name.toLowerCase().endsWith(ext.toLowerCase())
          ? exactCandidate
          : `${exactCandidate}${ext}`;
        if (!candidates.includes(withExt)) {
          candidates.push(withExt);
        }
      }
    } else {
      candidates.push(path.join(dir, name));
    }
  }

  const checks = await Promise.all(
    candidates.map((candidate) => isExecutableFile(candidate, platform)),
  );
  const matchIdx = checks.indexOf(true);
  return matchIdx >= 0 ? (candidates[matchIdx] ?? null) : null;
}

function applyAbortAndTimeout(child: ChildProcess, options?: CommandExecOptions): () => void {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  const onAbort = (): void => {
    child.kill("SIGTERM");
  };

  if (options?.signal !== undefined) {
    if (options.signal.aborted) {
      child.kill("SIGTERM");
    } else {
      options.signal.addEventListener("abort", onAbort, { once: true });
    }
  }

  if (options?.timeoutMs !== undefined && options.timeoutMs > 0) {
    timeoutId = setTimeout(() => {
      child.kill("SIGTERM");
    }, options.timeoutMs);
  }

  return () => {
    if (timeoutId !== undefined) {
      clearTimeout(timeoutId);
    }
    if (options?.signal !== undefined) {
      options.signal.removeEventListener("abort", onAbort);
    }
  };
}

function isEpipeError(err: Error): boolean {
  const parsed = ErrnoCodeSchema.safeParse(err);
  return parsed.success && parsed.data.code === "EPIPE";
}

export function createNodeCommandRunner(): CommandRunner {
  const activeProcesses = new Set<ChildProcess>();

  function trackProcess(child: ChildProcess): () => void {
    activeProcesses.add(child);
    return () => {
      activeProcesses.delete(child);
    };
  }

  return {
    async commandExists(
      name: string,
      options?: {
        readonly env?: Readonly<Record<string, string | undefined>>;
        readonly platform?: NodeJS.Platform;
      },
    ): Promise<boolean> {
      const found = await resolveExecutableInPath(
        name,
        options?.env ?? process.env,
        options?.platform ?? process.platform,
      );
      return found !== null;
    },

    exec(
      command: string,
      args: readonly string[],
      options?: CommandExecOptions,
    ): Promise<CommandExecResult> {
      return new Promise((resolve, reject) => {
        const child = spawn(command, [...args], {
          shell: false,
          cwd: options?.cwd,
          env: buildSpawnEnv(process.env, options?.env),
          stdio: ["pipe", "pipe", "pipe"],
        });

        const untrack = trackProcess(child);
        const clearWatchers = applyAbortAndTimeout(child, options);

        const stdoutChunks: Buffer[] = [];
        const stderrChunks: Buffer[] = [];

        child.stdout.on("data", (chunk: Buffer) => {
          stdoutChunks.push(chunk);
        });
        child.stderr.on("data", (chunk: Buffer) => {
          stderrChunks.push(chunk);
        });

        child.once("error", (err: Error) => {
          clearWatchers();
          untrack();
          reject(err);
        });

        child.once("close", (code: number | null) => {
          clearWatchers();
          untrack();
          resolve({
            exitCode: code ?? 1,
            stdout: Buffer.concat(stdoutChunks).toString("utf8"),
            stderr: Buffer.concat(stderrChunks).toString("utf8"),
          });
        });

        if (options?.stdin !== undefined) {
          child.stdin.write(options.stdin);
        }
        child.stdin.end();
      });
    },

    pipe(
      left: PipeCommandSpec,
      right: PipeCommandSpec,
      options?: CommandExecOptions,
    ): Promise<PipeExecResult> {
      return new Promise((resolve, reject) => {
        const env = buildSpawnEnv(process.env, options?.env);
        const leftProc = spawn(left.command, [...left.args], {
          shell: false,
          cwd: options?.cwd,
          env,
          stdio: ["ignore", "pipe", "pipe"],
        });
        const rightProc = spawn(right.command, [...right.args], {
          shell: false,
          cwd: options?.cwd,
          env,
          stdio: ["pipe", "pipe", "pipe"],
        });

        const untrackLeft = trackProcess(leftProc);
        const untrackRight = trackProcess(rightProc);
        const clearLeft = applyAbortAndTimeout(leftProc, options);
        const clearRight = applyAbortAndTimeout(rightProc, options);

        const stdoutChunks: Buffer[] = [];
        const stderrChunks: Buffer[] = [];
        let leftCode: number | null = null;
        let rightCode: number | null = null;
        let settled = false;

        const finishIfReady = (): void => {
          if (settled || leftCode === null || rightCode === null) {
            return;
          }
          settled = true;
          resolve({
            leftExitCode: leftCode,
            rightExitCode: rightCode,
            stdout: Buffer.concat(stdoutChunks).toString("utf8"),
            stderr: Buffer.concat(stderrChunks).toString("utf8"),
          });
        };

        const fail = (err: Error): void => {
          if (settled) {
            return;
          }
          settled = true;
          leftProc.kill("SIGTERM");
          rightProc.kill("SIGTERM");
          clearLeft();
          clearRight();
          untrackLeft();
          untrackRight();
          reject(err);
        };

        leftProc.stderr.on("data", (chunk: Buffer) => {
          stderrChunks.push(chunk);
        });
        rightProc.stdout.on("data", (chunk: Buffer) => {
          stdoutChunks.push(chunk);
        });
        rightProc.stderr.on("data", (chunk: Buffer) => {
          stderrChunks.push(chunk);
        });

        // Ignore EPIPE when downstream consumer finishes before upstream closes
        rightProc.stdin.on("error", (err: Error) => {
          if (!isEpipeError(err)) {
            fail(err);
          }
        });
        leftProc.stdout.on("error", (err: Error) => {
          if (!isEpipeError(err)) {
            fail(err);
          }
        });
        rightProc.stdout.on("error", (err: Error) => {
          if (!isEpipeError(err)) {
            fail(err);
          }
        });

        leftProc.stdout.pipe(rightProc.stdin);

        leftProc.once("error", fail);
        rightProc.once("error", fail);

        leftProc.once("close", (code: number | null) => {
          clearLeft();
          untrackLeft();
          leftCode = code ?? 1;
          finishIfReady();
        });

        rightProc.once("close", (code: number | null) => {
          clearRight();
          untrackRight();
          rightCode = code ?? 1;
          leftProc.stdout.unpipe(rightProc.stdin);
          if (leftCode === null) {
            leftProc.stdout.destroy();
          }
          finishIfReady();
        });
      });
    },

    spawnInteractive(
      command: string,
      args: readonly string[],
      options?: CommandExecOptions,
    ): Promise<number> {
      return new Promise((resolve, reject) => {
        const child = spawn(command, [...args], {
          shell: false,
          cwd: options?.cwd,
          env: buildSpawnEnv(process.env, options?.env),
          stdio: "inherit",
        });

        const untrack = trackProcess(child);
        const clearWatchers = applyAbortAndTimeout(child, options);

        child.once("error", (err: Error) => {
          clearWatchers();
          untrack();
          reject(err);
        });

        child.once("close", (code: number | null) => {
          clearWatchers();
          untrack();
          resolve(code ?? 1);
        });
      });
    },

    cleanupActiveProcesses(): void {
      for (const child of activeProcesses) {
        if (!child.killed) {
          child.kill("SIGTERM");
        }
      }
      activeProcesses.clear();
    },
  };
}

/**
 * Executes an async mapper over `items` with a bounded worker pool while preserving input order
 * and retaining `undefined` results.
 */
export async function mapWithConcurrency<T, R>(
  items: readonly T[],
  concurrencyLimit: number,
  mapper: (item: T, index: number) => Promise<R>,
): Promise<readonly R[]> {
  if (items.length === 0) {
    return [];
  }

  const entries = items.map((item, index) => ({ item, index }));
  const results: R[] = [];
  let nextIndex = 0;

  const runWorker = (): Promise<void> => {
    const entry = entries[nextIndex];
    if (entry === undefined) {
      return Promise.resolve();
    }
    nextIndex += 1;
    return mapper(entry.item, entry.index).then((value) => {
      results[entry.index] = value;
      return runWorker();
    });
  };

  const workerCount = Math.max(1, Math.min(concurrencyLimit, entries.length));
  await Promise.all(Array.from({ length: workerCount }, () => runWorker()));
  return results;
}

/**
 * Executes an async action sequentially over `items` without loop-await recursion boilerplate.
 */
export async function runSequentially<T>(
  items: readonly T[],
  action: (item: T, index: number) => Promise<void>,
): Promise<void> {
  await items.reduce<Promise<void>>(
    (chain, item, index) => chain.then(() => action(item, index)),
    Promise.resolve(),
  );
}
