import path from "node:path";
import process from "node:process";

import { handleCliError } from "./lib/cli-framework.ts";
import { createNodeCommandContext, type CommandRunner } from "./lib/context.ts";
import { createNodeCommandRunner } from "./lib/process.ts";
import { COMMAND_NAMES, loadCommand } from "./registry.ts";

const SIGNAL_CLEANUP_TIMEOUT_MS = 5000;

export interface RunMainOptions {
  readonly runner?: CommandRunner;
  readonly stdout?: (text: string) => void;
  readonly stderr?: (text: string) => void;
  readonly onSignalTerminate?: (signal: NodeJS.Signals, exitCode: number) => void;
}

export async function runMain(argv: readonly string[], options?: RunMainOptions): Promise<number> {
  const writeStdout =
    options?.stdout ??
    ((text: string): void => {
      process.stdout.write(text);
    });
  const writeStderr =
    options?.stderr ??
    ((text: string): void => {
      process.stderr.write(text);
    });

  const commandName = argv[0];
  if (commandName === undefined || commandName.trim() === "") {
    writeStderr(`Error: Missing command name. Available: ${COMMAND_NAMES.join(", ")}\n`);
    return 2;
  }

  const runner = options?.runner ?? createNodeCommandRunner();
  const cleanupHandlers = new Set<() => void | Promise<void>>();
  const abortController = new AbortController();
  let interruptedExitCode: number | null = null;
  let interruptedSignal: NodeJS.Signals | null = null;
  let resolveSignalAbort: ((code: number) => void) | null = null;

  const signalAbortPromise = new Promise<number>((resolve) => {
    resolveSignalAbort = resolve;
  });

  const runCleanup = async (): Promise<void> => {
    runner.cleanupActiveProcesses();
    const pending: Promise<void>[] = [];
    for (const handler of cleanupHandlers) {
      try {
        const maybePromise = handler();
        if (maybePromise !== undefined) {
          pending.push(Promise.resolve(maybePromise).catch(() => {}));
        }
      } catch {
        // Continue running remaining signal cleanup handlers
      }
    }
    if (pending.length === 0) {
      return;
    }
    let timeoutId: ReturnType<typeof setTimeout> | undefined;
    try {
      await Promise.race([
        Promise.allSettled(pending),
        new Promise<void>((resolve) => {
          timeoutId = setTimeout(resolve, SIGNAL_CLEANUP_TIMEOUT_MS);
        }),
      ]);
    } finally {
      if (timeoutId !== undefined) {
        clearTimeout(timeoutId);
      }
    }
  };

  const handleSignal = (sig: NodeJS.Signals, exitCode: number): void => {
    if (interruptedExitCode !== null) {
      return;
    }
    interruptedExitCode = exitCode;
    interruptedSignal = sig;
    abortController.abort(new Error(`Interrupted by ${sig}`));
    void runCleanup().finally(() => {
      resolveSignalAbort?.(exitCode);
      options?.onSignalTerminate?.(sig, exitCode);
    });
  };

  const onSigInt = (): void => {
    handleSignal("SIGINT", 130);
  };
  const onSigTerm = (): void => {
    handleSignal("SIGTERM", 143);
  };

  process.on("SIGINT", onSigInt);
  process.on("SIGTERM", onSigTerm);

  let commandHelp = "";
  try {
    const command = await loadCommand(commandName);
    if (interruptedExitCode !== null) {
      return interruptedExitCode;
    }
    if (command === undefined) {
      writeStderr(
        `Error: Unknown command '${commandName}'. Available: ${COMMAND_NAMES.join(", ")}\n`,
      );
      return 2;
    }
    commandHelp = command.formatHelp();

    const baseCtx = createNodeCommandContext({
      runner,
      signal: abortController.signal,
      onSignalCleanup: (handler: () => void | Promise<void>) => {
        cleanupHandlers.add(handler);
        return () => {
          cleanupHandlers.delete(handler);
        };
      },
    });

    const ctx =
      options?.stdout !== undefined || options?.stderr !== undefined
        ? { ...baseCtx, stdout: writeStdout, stderr: writeStderr }
        : baseCtx;

    const code = await Promise.race([command.execute(argv.slice(1), ctx), signalAbortPromise]);
    return interruptedExitCode ?? code;
  } catch (err) {
    if (interruptedExitCode !== null) {
      return interruptedExitCode;
    }
    return handleCliError(err, commandHelp !== "" ? commandHelp : undefined, writeStderr);
  } finally {
    process.off("SIGINT", onSigInt);
    process.off("SIGTERM", onSigTerm);
    if (interruptedSignal !== null && options?.onSignalTerminate === undefined && isEntryPoint) {
      process.kill(process.pid, interruptedSignal);
    }
  }
}

const isEntryPoint =
  process.argv[1] !== undefined && import.meta.filename === path.resolve(process.argv[1]);
if (isEntryPoint) {
  process.exitCode = await runMain(process.argv.slice(2));
}
