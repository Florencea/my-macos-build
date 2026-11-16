import path from "node:path";
import process from "node:process";
import { handleCliError } from "./lib/cli-framework.ts";
import { createNodeCommandContext } from "./lib/context.ts";
import { createNodeCommandRunner } from "./lib/process.ts";
import { CLI_COMMANDS, COMMAND_NAMES } from "./registry.ts";

export async function runMain(argv: readonly string[]): Promise<number> {
  const commandName = argv[0];
  if (commandName === undefined || commandName.trim() === "") {
    process.stderr.write(`Error: Missing command name. Available: ${COMMAND_NAMES.join(", ")}\n`);
    return 2;
  }

  const command = CLI_COMMANDS.get(commandName);
  if (command === undefined) {
    process.stderr.write(
      `Error: Unknown command '${commandName}'. Available: ${COMMAND_NAMES.join(", ")}\n`,
    );
    return 2;
  }

  const runner = createNodeCommandRunner();
  const cleanupHandlers = new Set<() => void>();

  const runCleanup = (): void => {
    for (const handler of cleanupHandlers) {
      handler();
    }
    runner.cleanupActiveProcesses();
  };

  const onSigInt = (): void => {
    runCleanup();
    process.exitCode = 130;
  };
  const onSigTerm = (): void => {
    runCleanup();
    process.exitCode = 143;
  };

  process.on("SIGINT", onSigInt);
  process.on("SIGTERM", onSigTerm);

  const ctx = createNodeCommandContext({
    runner,
    onSignalCleanup: (handler: () => void) => {
      cleanupHandlers.add(handler);
      return () => {
        cleanupHandlers.delete(handler);
      };
    },
  });

  try {
    return await command.execute(argv.slice(1), ctx);
  } catch (err) {
    return handleCliError(err, command.formatHelp(), ctx.stderr);
  } finally {
    process.off("SIGINT", onSigInt);
    process.off("SIGTERM", onSigTerm);
  }
}

const isEntryPoint =
  process.argv[1] !== undefined && import.meta.filename === path.resolve(process.argv[1]);
if (isEntryPoint) {
  process.exitCode = await runMain(process.argv.slice(2));
}
