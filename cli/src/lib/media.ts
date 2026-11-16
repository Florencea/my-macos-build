import os from "node:os";
import path from "node:path";

import { z } from "zod";

import {
  ExecutionError,
  UsageError,
  formatByteSize,
  formatNativeErrorDetail,
  type CommandContext,
} from "./context.ts";

const MediaEnvSchema = z.object({
  YT_DLP_BROWSER: z.string().optional(),
});

const NumericSecondsSchema = z
  .string()
  .trim()
  .regex(/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/);

const PositiveSecondsSchema = z.number().positive();
const NonNegativeSecondsSchema = z.number().nonnegative();

export interface ParseTimeOptions {
  readonly positiveOnly?: boolean;
}

/**
 * Parses a timestamp or duration string (`HH:MM:SS(.ms)`, `MM:SS(.ms)`, or seconds) into seconds.
 */
export function parseTimeToSeconds(timeText: string, options?: ParseTimeOptions): number {
  const trimmed = timeText.trim();
  let seconds = 0;

  const hmsMatch = trimmed.match(/^(\d+):(\d{2}):(\d{2}(?:\.\d+)?)$/);
  if (hmsMatch !== null) {
    const hours = Number(hmsMatch[1]);
    const minutes = Number(hmsMatch[2]);
    const secs = Number(hmsMatch[3]);
    if (minutes >= 60 || secs >= 60) {
      throw new UsageError(
        `Error: Invalid time value '${timeText}' (minutes/seconds must be < 60).`,
        false,
      );
    }
    seconds = hours * 3600 + minutes * 60 + secs;
  } else {
    const msMatch = trimmed.match(/^(\d+):(\d{2}(?:\.\d+)?)$/);
    if (msMatch !== null) {
      const minutes = Number(msMatch[1]);
      const secs = Number(msMatch[2]);
      if (secs >= 60) {
        throw new UsageError(
          `Error: Invalid time value '${timeText}' (seconds must be < 60).`,
          false,
        );
      }
      seconds = minutes * 60 + secs;
    } else {
      const numText = NumericSecondsSchema.safeParse(trimmed);
      if (!numText.success) {
        throw new UsageError(
          `Error: Invalid time value '${timeText}' (expected HH:MM:SS, MM:SS, or seconds).`,
          false,
        );
      }
      seconds = Number(numText.data);
    }
  }

  const nonNegative = NonNegativeSecondsSchema.safeParse(seconds);
  if (!nonNegative.success) {
    throw new UsageError(
      `Error: Time value '${timeText}' must be a finite non-negative number.`,
      false,
    );
  }

  if (options?.positiveOnly === true) {
    const positive = PositiveSecondsSchema.safeParse(nonNegative.data);
    if (!positive.success) {
      throw new UsageError(`Error: Duration '${timeText}' must be greater than zero.`, false);
    }
  }

  return nonNegative.data;
}

/**
 * Resolves the browser name used by `yt-dlp --cookies-from-browser`.
 */
export function resolveYtDlpBrowser(
  browser?: string,
  env: Readonly<Record<string, string | undefined>> = {},
): string {
  const trimmedBrowser = browser?.trim() ?? "";
  if (trimmedBrowser !== "") {
    return trimmedBrowser;
  }

  const parsedEnv = MediaEnvSchema.safeParse(env);
  const envBrowser = parsedEnv.success ? (parsedEnv.data.YT_DLP_BROWSER?.trim() ?? "") : "";
  if (envBrowser !== "") {
    return envBrowser;
  }

  return "chrome";
}

function pad2(value: number): string {
  return value.toString().padStart(2, "0");
}

/**
 * Formats a `Date` into `yyyyMMddHHmmss` for default media output filenames.
 */
export function formatMediaTimestamp(date: Date): string {
  return [
    date.getFullYear().toString().padStart(4, "0"),
    pad2(date.getMonth() + 1),
    pad2(date.getDate()),
    pad2(date.getHours()),
    pad2(date.getMinutes()),
    pad2(date.getSeconds()),
  ].join("");
}

/**
 * Checks whether `inputArg` resolves to an existing local file relative to `ctx.cwd`.
 */
export async function resolveLocalMediaFile(
  ctx: CommandContext,
  inputArg: string,
): Promise<string | null> {
  const candidate = path.resolve(ctx.cwd, inputArg);
  try {
    const stats = await ctx.fs.stat(candidate);
    return stats.isFile() ? candidate : null;
  } catch {
    return null;
  }
}

export interface YtDlpSegmentInput {
  readonly inputSource: string;
  readonly startSecond: number;
  readonly endSecond: number;
  readonly format: string;
  readonly browser?: string;
  readonly forceKeyframesAtCuts?: boolean;
}

export interface YtDlpSegmentResult {
  readonly tempDir: string;
  readonly filePath: string;
}

async function findDownloadedSegmentFile(
  fsPort: CommandContext["fs"],
  tempDir: string,
): Promise<string | null> {
  const entries = await fsPort.readdir(tempDir, { withFileTypes: true });
  const files = entries
    .filter((entry) => {
      if (!entry.isFile()) {
        return false;
      }
      const ext = path.extname(entry.name).toLowerCase();
      return ext !== ".part" && ext !== ".ytdl";
    })
    .toSorted((a, b) => a.name.localeCompare(b.name));

  const first = files[0];
  return first !== undefined ? path.join(tempDir, first.name) : null;
}

/**
 * Downloads a bounded segment via `yt-dlp`, trying browser cookies first and falling back to cookie-less mode.
 */
export async function downloadYtDlpSegment(
  ctx: CommandContext,
  input: YtDlpSegmentInput,
): Promise<YtDlpSegmentResult> {
  const targetBrowser = resolveYtDlpBrowser(input.browser, ctx.env);
  const tempDir = await ctx.fs.mkdtemp(path.join(os.tmpdir(), "yt_seg_"));
  const outputTemplate = path.join(tempDir, "segment.%(ext)s");

  const unregisterSignal = ctx.onSignalCleanup(() =>
    ctx.fs.rm(tempDir, { recursive: true, force: true }).catch(() => {}),
  );

  const commonArgs: string[] = [
    "--quiet",
    "--no-warnings",
    "--force-overwrites",
    "--no-playlist",
    "--download-sections",
    `*${input.startSecond.toString()}-${input.endSecond.toString()}`,
  ];
  if (input.forceKeyframesAtCuts === true) {
    commonArgs.push("--force-keyframes-at-cuts");
  }
  commonArgs.push("-f", input.format, "-o", outputTemplate);

  try {
    const cookieRes = await ctx.runner.exec(
      "yt-dlp",
      ["--cookies-from-browser", targetBrowser, ...commonArgs, input.inputSource],
      { signal: ctx.signal },
    );
    let downloadedPath = await findDownloadedSegmentFile(ctx.fs, tempDir);

    if (cookieRes.exitCode !== 0 || downloadedPath === null) {
      const leftoverEntries = await ctx.fs.readdir(tempDir, { withFileTypes: true });
      await Promise.all(
        leftoverEntries
          .filter((entry) => entry.isFile())
          .map((entry) => ctx.fs.rm(path.join(tempDir, entry.name), { force: true })),
      );

      const fallbackRes = await ctx.runner.exec("yt-dlp", [...commonArgs, input.inputSource], {
        signal: ctx.signal,
      });
      downloadedPath = await findDownloadedSegmentFile(ctx.fs, tempDir);

      if (fallbackRes.exitCode !== 0 || downloadedPath === null) {
        const detail = formatNativeErrorDetail(
          [fallbackRes.stderr, fallbackRes.stdout],
          fallbackRes.exitCode,
        );
        throw new ExecutionError(
          `Error: Failed to download YouTube video segment for input: ${input.inputSource} (${detail})`,
          fallbackRes.exitCode !== 0 ? fallbackRes.exitCode : 1,
        );
      }
    }

    return {
      tempDir,
      filePath: downloadedPath,
    };
  } catch (err) {
    await ctx.fs.rm(tempDir, { recursive: true, force: true }).catch(() => {});
    throw err;
  } finally {
    unregisterSignal();
  }
}

export interface MediaInputSourceSpec {
  readonly inputArg: string;
  readonly localFile: string | null;
  readonly startSecond: number;
  readonly endSecond: number;
  readonly format: string;
  readonly browser?: string;
  readonly forceKeyframesAtCuts?: boolean;
}

/**
 * Resolves a local media file or downloads a bounded remote segment with signal/finally cleanup.
 */
export async function withMediaInputSource<T>(
  ctx: CommandContext,
  spec: MediaInputSourceSpec,
  work: (resolved: { readonly isLocal: boolean; readonly filePath: string }) => Promise<T>,
): Promise<T> {
  if (spec.localFile !== null) {
    return await work({ isLocal: true, filePath: spec.localFile });
  }

  const segment = await downloadYtDlpSegment(ctx, {
    inputSource: spec.inputArg,
    startSecond: spec.startSecond,
    endSecond: spec.endSecond,
    format: spec.format,
    browser: spec.browser,
    forceKeyframesAtCuts: spec.forceKeyframesAtCuts,
  });

  const unregisterSignal = ctx.onSignalCleanup(() =>
    ctx.fs.rm(segment.tempDir, { recursive: true, force: true }).catch(() => {}),
  );

  try {
    return await work({ isLocal: false, filePath: segment.filePath });
  } finally {
    unregisterSignal();
    await ctx.fs.rm(segment.tempDir, { recursive: true, force: true }).catch(() => {});
  }
}

/**
 * Prints the output filename and human-readable byte size if the generated file exists.
 */
export async function reportOutputFileSize(
  ctx: Pick<CommandContext, "fs" | "stdout">,
  resolvedOutput: string,
  displayName: string,
): Promise<void> {
  try {
    const outStats = await ctx.fs.stat(resolvedOutput);
    if (outStats.isFile()) {
      ctx.stdout(`${displayName} ${formatByteSize(outStats.size)}\n`);
    }
  } catch {
    // Output size reporting is best-effort after a zero exit code.
  }
}
