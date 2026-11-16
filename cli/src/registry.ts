import { mmbCommand } from "./commands/mmb.ts";
import type { RegisteredCommand } from "./lib/cli-framework.ts";

const REGISTERED_LIST: readonly RegisteredCommand[] = [mmbCommand];

export const CLI_COMMANDS: ReadonlyMap<string, RegisteredCommand> = new Map(
  REGISTERED_LIST.map((cmd) => [cmd.name, cmd]),
);

export const COMMAND_NAMES: readonly string[] = REGISTERED_LIST.map((cmd) => cmd.name);
