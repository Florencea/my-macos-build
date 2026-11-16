import { parseArgs } from "node:util";

import { z } from "zod";

import {
  CliError,
  MissingDependencyError,
  UsageError,
  formatErrorMessage,
  type CommandContext,
} from "./context.ts";

export const EmptyOptionsSchema = z.object({});

const BaseIntTextSchema = z
  .string()
  .trim()
  .regex(/^-?\d+$/)
  .transform((text) => Number(text))
  .pipe(z.int());

interface FlagDefinition {
  readonly type: "boolean" | "string";
  readonly short?: string;
  readonly valueName?: string;
  readonly description: string;
}

interface PositionalSpec {
  readonly min: number;
  readonly max: number;
  readonly label: string;
}

export interface CommandDefinition<TSchema extends z.ZodType> {
  readonly name: string;
  readonly summary: string;
  readonly usage: string;
  readonly examples?: readonly string[];
  readonly flags: Readonly<Record<string, FlagDefinition>>;
  readonly optionsSchema: TSchema;
  readonly positionals?: PositionalSpec;
  readonly requiredCommands?: readonly string[];
  readonly supportsDryRun?: boolean;
  run(input: {
    readonly options: z.infer<TSchema>;
    readonly positionals: readonly string[];
    readonly ctx: CommandContext;
  }): Promise<number>;
}

export interface RegisteredCommand {
  readonly name: string;
  readonly summary: string;
  readonly usage: string;
  readonly examples?: readonly string[];
  readonly flags: Readonly<Record<string, FlagDefinition>>;
  readonly positionals?: PositionalSpec;
  readonly requiredCommands?: readonly string[];
  readonly supportsDryRun?: boolean;
  execute(argv: readonly string[], ctx: CommandContext): Promise<number>;
  formatHelp(): string;
}

export function defineCommand<TSchema extends z.ZodType>(
  def: CommandDefinition<TSchema>,
): RegisteredCommand;
export function defineCommand(
  def: Omit<CommandDefinition<typeof EmptyOptionsSchema>, "optionsSchema">,
): RegisteredCommand;
export function defineCommand<TSchema extends z.ZodType>(
  def:
    | CommandDefinition<TSchema>
    | Omit<CommandDefinition<typeof EmptyOptionsSchema>, "optionsSchema">,
): RegisteredCommand {
  if ("optionsSchema" in def) {
    return {
      name: def.name,
      summary: def.summary,
      usage: def.usage,
      examples: def.examples,
      flags: def.flags,
      positionals: def.positionals,
      requiredCommands: def.requiredCommands,
      supportsDryRun: def.supportsDryRun,
      formatHelp: () => formatCommandHelp(def),
      execute: (argv, ctx) => runCliCommand(def, argv, ctx),
    };
  }
  const resolvedDef: CommandDefinition<typeof EmptyOptionsSchema> = {
    ...def,
    optionsSchema: EmptyOptionsSchema,
  };
  return {
    name: resolvedDef.name,
    summary: resolvedDef.summary,
    usage: resolvedDef.usage,
    examples: resolvedDef.examples,
    flags: resolvedDef.flags,
    positionals: resolvedDef.positionals,
    requiredCommands: resolvedDef.requiredCommands,
    supportsDryRun: resolvedDef.supportsDryRun,
    formatHelp: () => formatCommandHelp(resolvedDef),
    execute: (argv, ctx) => runCliCommand(resolvedDef, argv, ctx),
  };
}

export function parseValidatedInt(
  rawValue: string,
  optionName: string,
  minValue = Number.MIN_SAFE_INTEGER,
  maxValue = Number.MAX_SAFE_INTEGER,
): number {
  const parsed = BaseIntTextSchema.safeParse(rawValue);
  if (!parsed.success) {
    throw new UsageError(`Invalid integer for ${optionName}: '${rawValue}'`, false);
  }
  if (parsed.data < minValue || parsed.data > maxValue) {
    throw new UsageError(
      `Value for ${optionName} must be between ${minValue.toString()} and ${maxValue.toString()} (got ${rawValue.trim()}).`,
      false,
    );
  }
  return parsed.data;
}

function formatCommandHelp<TSchema extends z.ZodType>(def: CommandDefinition<TSchema>): string {
  const lines: string[] = [`${def.name}: ${def.summary}`, `Usage: ${def.usage}`];

  const optionLines: string[] = [];
  for (const [longName, spec] of Object.entries(def.flags)) {
    const shortPart = spec.short !== undefined ? `-${spec.short}, ` : "    ";
    const valuePart = spec.valueName !== undefined ? ` <${spec.valueName}>` : "";
    const left = `  ${shortPart}--${longName}${valuePart}`;
    optionLines.push(`${left.padEnd(24)}${spec.description}`);
  }

  if (def.supportsDryRun === true) {
    optionLines.push(
      `  ${"    --dry-run".padEnd(24)}Preview planned actions without applying changes`,
    );
  }
  optionLines.push(`  ${"-h, --help".padEnd(24)}Show this help message`);

  lines.push("Options:", ...optionLines);

  if (def.examples !== undefined && def.examples.length > 0) {
    lines.push("Examples:", ...def.examples.map((ex) => `  ${ex}`));
  }

  return `${lines.join("\n")}\n`;
}

export async function assertRequiredCommands(
  ctx: Pick<CommandContext, "runner">,
  commands: readonly string[],
): Promise<void> {
  if (commands.length === 0) {
    return;
  }
  const availability = await Promise.all(
    commands.map(async (cmdName) => ({
      cmdName,
      available: await ctx.runner.commandExists(cmdName),
    })),
  );
  const missing = availability.find((entry) => !entry.available);
  if (missing !== undefined) {
    throw new MissingDependencyError(missing.cmdName);
  }
}

async function runCliCommand<TSchema extends z.ZodType>(
  def: CommandDefinition<TSchema>,
  argv: readonly string[],
  ctx: CommandContext,
): Promise<number> {
  const parseOptions: Record<string, { type: "boolean" | "string"; short?: string }> = {
    help: { type: "boolean", short: "h" },
  };

  if (def.supportsDryRun === true) {
    parseOptions["dry-run"] = { type: "boolean" };
  }

  for (const [name, spec] of Object.entries(def.flags)) {
    parseOptions[name] =
      spec.short !== undefined ? { type: spec.type, short: spec.short } : { type: spec.type };
  }

  let parsed: {
    values: Record<string, string | boolean | undefined>;
    positionals: string[];
  };

  try {
    parsed = parseArgs({
      args: [...argv],
      options: parseOptions,
      strict: true,
      allowPositionals: true,
    });
  } catch (err) {
    const msg = formatErrorMessage(err);
    throw new UsageError(`Error: ${msg}`, true);
  }

  if (parsed.values["help"] === true) {
    ctx.stdout(formatCommandHelp(def));
    return 0;
  }

  const posSpec = def.positionals ?? { min: 0, max: 0, label: "" };
  if (parsed.positionals.length < posSpec.min) {
    const labelSuffix = posSpec.label !== "" ? ` (${posSpec.label})` : "";
    throw new UsageError(`Error: Missing required argument${labelSuffix}`, true);
  }
  if (parsed.positionals.length > posSpec.max) {
    const extra = parsed.positionals[posSpec.max] ?? "";
    throw new UsageError(`Error: Unexpected argument ${extra}`, true);
  }

  const rawOptions: Record<string, unknown> = {};
  for (const key of Object.keys(def.flags)) {
    const val = parsed.values[key];
    if (val !== undefined) {
      rawOptions[key] = val;
    }
  }

  const validation = def.optionsSchema.safeParse(rawOptions);
  if (!validation.success) {
    const firstIssue = validation.error.issues[0];
    const detail = firstIssue !== undefined ? firstIssue.message : "Invalid options";
    throw new UsageError(`Error: ${detail}`, false);
  }

  const dryRun = def.supportsDryRun === true && parsed.values["dry-run"] === true;
  const effectiveCtx: CommandContext = dryRun ? { ...ctx, dryRun: true } : ctx;

  if (def.requiredCommands !== undefined && def.requiredCommands.length > 0) {
    await assertRequiredCommands(effectiveCtx, def.requiredCommands);
  }

  return await def.run({
    options: validation.data,
    positionals: parsed.positionals,
    ctx: effectiveCtx,
  });
}

export function handleCliError(
  err: unknown,
  helpText: string | undefined,
  stderr: (text: string) => void,
): number {
  if (err instanceof UsageError) {
    stderr(`${err.message}\n`);
    if (err.includeHelp && helpText !== undefined) {
      stderr(helpText);
    }
    return err.exitCode;
  }
  if (err instanceof CliError) {
    stderr(`${err.message}\n`);
    return err.exitCode;
  }
  const msg = formatErrorMessage(err);
  stderr(`Error: ${msg}\n`);
  return 1;
}
