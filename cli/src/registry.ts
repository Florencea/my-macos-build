import { clallCommand } from "./commands/clall.ts";
import { ebkCommand } from "./commands/ebk.ts";
import { mdigCommand } from "./commands/mdig.ts";
import { mkclpCommand } from "./commands/mkclp.ts";
import { mkgifCommand } from "./commands/mkgif.ts";
import { mmbCommand } from "./commands/mmb.ts";
import { reaCommand } from "./commands/rea.ts";
import { webreadCommand } from "./commands/webread.ts";
import type { RegisteredCommand } from "./lib/cli-framework.ts";

const REGISTERED_LIST: readonly RegisteredCommand[] = [
  clallCommand,
  ebkCommand,
  mdigCommand,
  mkclpCommand,
  mkgifCommand,
  mmbCommand,
  reaCommand,
  webreadCommand,
];

export const CLI_COMMANDS: ReadonlyMap<string, RegisteredCommand> = new Map(
  REGISTERED_LIST.map((cmd) => [cmd.name, cmd]),
);

export const COMMAND_NAMES: readonly string[] = REGISTERED_LIST.map((cmd) => cmd.name);
