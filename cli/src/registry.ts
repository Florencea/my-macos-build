import type { RegisteredCommand } from "./lib/cli-framework.ts";

export type CommandLoader = () => Promise<RegisteredCommand>;

const COMMAND_LOADERS: ReadonlyMap<string, CommandLoader> = new Map([
  ["clall", async () => (await import("./commands/clall.ts")).clallCommand],
  ["ebk", async () => (await import("./commands/ebk.ts")).ebkCommand],
  ["mdig", async () => (await import("./commands/mdig.ts")).mdigCommand],
  ["mkclp", async () => (await import("./commands/mkclp.ts")).mkclpCommand],
  ["mkgif", async () => (await import("./commands/mkgif.ts")).mkgifCommand],
  ["mmb", async () => (await import("./commands/mmb.ts")).mmbCommand],
  ["rea", async () => (await import("./commands/rea.ts")).reaCommand],
  ["ua", async () => (await import("./commands/ua.ts")).uaCommand],
  ["unodev", async () => (await import("./commands/unodev.ts")).unodevCommand],
  ["up", async () => (await import("./commands/up.ts")).upCommand],
  ["upnpmv", async () => (await import("./commands/upnpmv.ts")).upnpmvCommand],
  ["webread", async () => (await import("./commands/webread.ts")).webreadCommand],
]);

export const COMMAND_NAMES: readonly string[] = [...COMMAND_LOADERS.keys()];

export async function loadCommand(name: string): Promise<RegisteredCommand | undefined> {
  const loader = COMMAND_LOADERS.get(name);
  return loader !== undefined ? await loader() : undefined;
}

export async function loadAllCommands(): Promise<ReadonlyMap<string, RegisteredCommand>> {
  const entries = await Promise.all(
    [...COMMAND_LOADERS.entries()].map(async ([name, loader]) => [name, await loader()] as const),
  );
  return new Map(entries);
}
