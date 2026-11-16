import path from "node:path";
import process from "node:process";
import { z } from "zod";
import { defineCommand } from "../lib/cli-framework.ts";
import { ExecutionError, formatByteSize, formatNativeErrorDetail } from "../lib/context.ts";

const EmptyOptionsSchema = z.object({});

/**
 * Combine a single .ass subtitle track into the single .mkv in a directory,
 * move the output to the parent directory, and delete the source directory.
 */
export const reaCommand = defineCommand({
  name: "rea",
  summary: "ASS-Combiner: combine .cht.ass into original mkv as default subtitle track",
  usage: "rea [options] <input_dir>",
  examples: ["rea 'input'", "rea --dry-run 'input'"],
  flags: {},
  optionsSchema: EmptyOptionsSchema,
  positionals: { min: 1, max: 1, label: "input_dir" },
  requiredCommands: ["ffmpeg"],
  supportsDryRun: true,
  async run({ positionals, ctx }) {
    const rawInputDir = positionals[0] ?? "";
    const absInputDir = path.resolve(ctx.cwd, rawInputDir);

    let dirStats;
    try {
      dirStats = await ctx.fs.stat(absInputDir);
    } catch {
      throw new ExecutionError(`Error: Directory ${rawInputDir} does not exist`, 1);
    }
    if (!dirStats.isDirectory()) {
      throw new ExecutionError(`Error: Directory ${rawInputDir} does not exist`, 1);
    }

    const parsedPath = path.parse(absInputDir);
    const parentDir = path.dirname(absInputDir);
    const inputBase = path.basename(absInputDir);
    if (
      absInputDir === "" ||
      absInputDir === parsedPath.root ||
      parentDir === absInputDir ||
      inputBase === ""
    ) {
      throw new ExecutionError("Error: Input directory cannot be root or empty", 1);
    }

    const entries = await ctx.fs.readdir(absInputDir, { withFileTypes: true });
    const fileEntries = entries
      .filter((entry) => entry.isFile())
      .toSorted((a, b) => a.name.localeCompare(b.name));

    const mkvFiles = fileEntries.filter((entry) => entry.name.toLowerCase().endsWith(".mkv"));
    if (mkvFiles.length === 0) {
      throw new ExecutionError(`Error: No .mkv file found in ${rawInputDir}`, 1);
    }
    if (mkvFiles.length > 1) {
      throw new ExecutionError(
        `Error: Multiple .mkv files found in ${rawInputDir}; refusing to remove directory`,
        1,
      );
    }

    const assFiles = fileEntries.filter((entry) => entry.name.toLowerCase().endsWith(".ass"));
    if (assFiles.length === 0) {
      throw new ExecutionError(`Error: No .ass subtitle file found in ${rawInputDir}`, 1);
    }

    const preferredAss = assFiles.find((entry) => /(?:cht|tc|zh-tw)/i.test(entry.name));
    const selectedMkv = mkvFiles[0];
    const selectedAss = preferredAss ?? assFiles[0];
    if (selectedMkv === undefined || selectedAss === undefined) {
      throw new ExecutionError(`Error: Missing input files in ${rawInputDir}`, 1);
    }

    const inputFile = path.join(absInputDir, selectedMkv.name);
    const inputAssTw = path.join(absInputDir, selectedAss.name);
    const tmpFile = path.join(parentDir, `.tmp_rea_${process.pid.toString()}.mkv`);
    const outputFile = path.join(parentDir, `${inputBase}.mkv`);

    if (ctx.dryRun) {
      ctx.stdout(`[dry-run] Combine "${inputFile}" + "${inputAssTw}" -> "${outputFile}"\n`);
      ctx.stdout(`[dry-run] Remove directory "${absInputDir}"\n`);
      return 0;
    }

    const unregisterSignal = ctx.onSignalCleanup(() => {
      void ctx.fs.rm(tmpFile, { force: true }).catch(() => {});
    });

    try {
      const result = await ctx.runner.exec(
        "ffmpeg",
        [
          "-y",
          "-hide_banner",
          "-loglevel",
          "error",
          "-sn",
          "-i",
          inputFile,
          "-i",
          inputAssTw,
          "-map",
          "0:v:0",
          "-map",
          "0:a:0?",
          "-map",
          "1:s:0",
          "-c",
          "copy",
          "-disposition:s:0",
          "default",
          "-metadata:s:s:0",
          "language=chi",
          "-metadata:s:s:0",
          "title=繁體中文",
          tmpFile,
        ],
        { signal: ctx.signal },
      );

      if (result.exitCode !== 0) {
        const detail = formatNativeErrorDetail([result.stderr, result.stdout], result.exitCode);
        throw new ExecutionError(`Error: ffmpeg failed (${detail})`, result.exitCode);
      }

      await ctx.fs.rename(tmpFile, outputFile);
      await ctx.fs.rm(absInputDir, { recursive: true, force: true });

      const outStats = await ctx.fs.stat(outputFile);
      const readableSize = formatByteSize(outStats.size);
      ctx.stdout(`${path.basename(outputFile)} ${readableSize} ok\n`);
      return 0;
    } finally {
      unregisterSignal();
      await ctx.fs.rm(tmpFile, { force: true }).catch(() => {});
    }
  },
});
