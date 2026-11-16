import path from "node:path";

import { z } from "zod";

import { defineCommand, parseValidatedInt } from "../lib/cli-framework.ts";
import {
  ExecutionError,
  MissingDependencyError,
  UsageError,
  formatNativeErrorDetail,
  type CommandContext,
} from "../lib/context.ts";
import {
  formatMediaTimestamp,
  parseTimeToSeconds,
  reportOutputFileSize,
  resolveLocalMediaFile,
  resolveYtDlpBrowser,
  withMediaInputSource,
} from "../lib/media.ts";
import { resolveExecutableInPath } from "../lib/process.ts";

const MkgifOptionsSchema = z.object({
  width: z.string().optional(),
  fps: z.string().optional(),
  quality: z.string().optional(),
  lossy: z.boolean().default(false),
  browser: z.string().optional(),
  output: z.string().trim().min(1, "--output cannot be empty").optional(),
});

const PE_DOS_HEADER_MIN_BYTES = 0x40;
const PE_LFANEW_OFFSET = 0x3c;
const PE_SUBSYSTEM_OFFSET_FROM_PE = 0x5c;
const PE_SUBSYSTEM_MIN_SIZE = 0x5e;
const PE_CONSOLE_SUBSYSTEM = 3;

async function isCliCapableGifski(ctx: CommandContext): Promise<boolean> {
  if (ctx.platform !== "win32") {
    return await ctx.runner.commandExists("gifski", { env: ctx.env, platform: ctx.platform });
  }

  // On Windows, resolve the actual executable (.exe/.cmd) and verify console PE subsystem.
  try {
    let exePath = await resolveExecutableInPath("gifski", ctx.env, ctx.platform);
    if (exePath === null) {
      const hasCommand = await ctx.runner.commandExists("gifski", {
        env: ctx.env,
        platform: ctx.platform,
      });
      if (!hasCommand) {
        return false;
      }
      exePath = await resolveExecutableInPath("gifski", process.env, ctx.platform);
    }
    if (exePath === null) {
      return false;
    }
    const handle = await ctx.fs.open(exePath, "r");
    try {
      const headerBuf = Buffer.alloc(4096);
      const { bytesRead } = await handle.read(headerBuf, 0, headerBuf.length, 0);
      if (bytesRead < PE_DOS_HEADER_MIN_BYTES) {
        return false;
      }
      const peOffset = headerBuf.readInt32LE(PE_LFANEW_OFFSET);
      if (peOffset < 0 || peOffset + PE_SUBSYSTEM_MIN_SIZE > bytesRead) {
        return false;
      }
      const subsystem = headerBuf.readUInt16LE(peOffset + PE_SUBSYSTEM_OFFSET_FROM_PE);
      return subsystem === PE_CONSOLE_SUBSYSTEM;
    } finally {
      await handle.close();
    }
  } catch {
    return false;
  }
}

function selectYtDlpMaxHeight(width: number): number {
  if (width <= 480) {
    return 480;
  }
  if (width <= 720) {
    return 720;
  }
  if (width <= 1280) {
    return 1080;
  }
  return 2160;
}

/**
 * High-quality GIF maker using `ffmpeg | gifski` when available, with FFmpeg palette fallback.
 */
export const mkgifCommand = defineCommand({
  name: "mkgif",
  summary: "High-quality Gif Maker via gifski / FFmpeg palette",
  usage:
    "mkgif [-w 720] [--fps 10] [-q 70] [-l] [input_file_or_url] [from(hh:mm:ss or sec)] [during(sec)]",
  examples: ["mkgif 'input.mp4' 01:02:08 11.0", "mkgif JoSY6AWKqHs 00:01:59 20 --fps 10 -w 720"],
  flags: {
    width: {
      type: "string",
      short: "w",
      valueName: "num",
      description: "Output gif width in pixels (default: 720)",
    },
    fps: {
      type: "string",
      valueName: "num",
      description: "Frame rate per second (default: 10)",
    },
    quality: {
      type: "string",
      short: "q",
      valueName: "num",
      description: "Gifski encoding quality 1-100 (default: 70)",
    },
    lossy: {
      type: "boolean",
      short: "l",
      description: "Enable lossy optimization",
    },
    browser: {
      type: "string",
      short: "b",
      valueName: "name",
      description: "Browser for YouTube cookies (default: chrome, or YT_DLP_BROWSER)",
    },
    output: {
      type: "string",
      short: "o",
      valueName: "file",
      description: "Custom output file path",
    },
  },
  optionsSchema: MkgifOptionsSchema,
  positionals: { min: 3, max: 3, label: "input_file_or_url from duration" },
  requiredCommands: ["ffmpeg"],
  supportsDryRun: true,
  async run({ options, positionals, ctx }) {
    const inputArg = positionals[0] ?? "";
    const startText = positionals[1] ?? "";
    const durationText = positionals[2] ?? "";

    if (inputArg.trim() === "") {
      throw new UsageError("Error: input_file_or_url cannot be empty", true);
    }

    const startSec = parseTimeToSeconds(startText);
    const durSec = parseTimeToSeconds(durationText, { positiveOnly: true });

    const width =
      options.width !== undefined ? parseValidatedInt(options.width, "--width", 16, 7680) : 720;
    const fps = options.fps !== undefined ? parseValidatedInt(options.fps, "--fps", 1, 60) : 10;
    const quality =
      options.quality !== undefined ? parseValidatedInt(options.quality, "--quality", 1, 100) : 70;

    const localFile = await resolveLocalMediaFile(ctx, inputArg);
    const isLocal = localFile !== null;

    if (!isLocal) {
      const hasYtDlp = await ctx.runner.commandExists("yt-dlp");
      if (!hasYtDlp) {
        throw new MissingDependencyError("yt-dlp");
      }
    }

    const outputName =
      options.output ?? `${formatMediaTimestamp(ctx.now())}_fps${fps.toString()}.gif`;
    const resolvedOutput = path.resolve(ctx.cwd, outputName);
    const useGifski = await isCliCapableGifski(ctx);

    if (ctx.dryRun) {
      if (!isLocal) {
        const endSec = startSec + durSec;
        const browser = resolveYtDlpBrowser(options.browser, ctx.env);
        ctx.stdout(
          `[dry-run] Download segment ${startSec.toString()}-${endSec.toString()} from "${inputArg}" via yt-dlp (browser=${browser})\n`,
        );
      }
      const encoderMode = useGifski ? "ffmpeg | gifski" : "ffmpeg palettegen/paletteuse";
      ctx.stdout(
        `[dry-run] Encode GIF (${encoderMode}, ${width.toString()}px, ${fps.toString()}fps) -> "${resolvedOutput}"\n`,
      );
      return 0;
    }

    const ytHeight = selectYtDlpMaxHeight(width);
    const ytFormat = `bestvideo[height<=${ytHeight.toString()}]/best[height<=${ytHeight.toString()}]/bestvideo/best`;

    return await withMediaInputSource(
      ctx,
      {
        inputArg,
        localFile,
        startSecond: startSec,
        endSecond: startSec + durSec,
        format: ytFormat,
        browser: options.browser,
        forceKeyframesAtCuts: true,
      },
      async ({ isLocal: resolvedIsLocal, filePath: inputSource }) => {
        const ffmpegStart = resolvedIsLocal ? startText : "0";

        if (useGifski) {
          const gifskiArgs = ["-q", "-Q", quality.toString(), "-W", width.toString()];
          if (options.lossy) {
            gifskiArgs.push("--lossy-quality", "75");
          }
          gifskiArgs.push("-o", resolvedOutput, "-");

          const pipeRes = await ctx.runner.pipe(
            {
              command: "ffmpeg",
              args: [
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-ss",
                ffmpegStart,
                "-i",
                inputSource,
                "-t",
                durationText,
                "-vf",
                `fps=${fps.toString()},scale=${width.toString()}:-2:flags=lanczos,format=yuv420p`,
                "-f",
                "yuv4mpegpipe",
                "-",
              ],
            },
            {
              command: "gifski",
              args: gifskiArgs,
            },
            { signal: ctx.signal },
          );

          if (pipeRes.leftExitCode !== 0 || pipeRes.rightExitCode !== 0) {
            const exitCode =
              pipeRes.rightExitCode !== 0 ? pipeRes.rightExitCode : pipeRes.leftExitCode;
            const detail = formatNativeErrorDetail([pipeRes.stderr, pipeRes.stdout], exitCode);
            throw new ExecutionError(
              `Error: GIF generation failed (ffmpeg=${pipeRes.leftExitCode.toString()}, gifski=${pipeRes.rightExitCode.toString()}: ${detail})`,
              exitCode,
            );
          }
        } else {
          const filterComplex = `[0:v] fps=${fps.toString()},scale=${width.toString()}:-1:flags=lanczos,split [a][b];[a] palettegen=max_colors=256:stats_mode=diff [p];[b][p] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle`;
          const paletteRes = await ctx.runner.exec(
            "ffmpeg",
            [
              "-y",
              "-hide_banner",
              "-loglevel",
              "error",
              "-ss",
              ffmpegStart,
              "-i",
              inputSource,
              "-t",
              durationText,
              "-filter_complex",
              filterComplex,
              resolvedOutput,
            ],
            { signal: ctx.signal },
          );

          if (paletteRes.exitCode !== 0) {
            const detail = formatNativeErrorDetail(
              [paletteRes.stderr, paletteRes.stdout],
              paletteRes.exitCode,
            );
            throw new ExecutionError(
              `Error: GIF generation failed (${detail})`,
              paletteRes.exitCode,
            );
          }
        }

        await reportOutputFileSize(ctx, resolvedOutput, outputName);
        return 0;
      },
    );
  },
});
