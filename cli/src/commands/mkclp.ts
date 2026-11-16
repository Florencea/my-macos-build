import path from "node:path";
import { z } from "zod";
import { defineCommand, parseValidatedInt } from "../lib/cli-framework.ts";
import {
  ExecutionError,
  MissingDependencyError,
  UsageError,
  formatByteSize,
  formatNativeErrorDetail,
  type CommandContext,
} from "../lib/context.ts";
import {
  downloadYtDlpSegment,
  formatMediaTimestamp,
  parseTimeToSeconds,
  resolveLocalMediaFile,
  resolveYtDlpBrowser,
  type YtDlpSegmentResult,
} from "../lib/media.ts";

const MkclpOptionsSchema = z.object({
  quality: z.string().optional(),
  copy: z.boolean().default(false),
  browser: z.string().optional(),
  output: z.string().trim().min(1, "--output cannot be empty").optional(),
});

const FfprobeOutputSchema = z.object({
  format: z
    .object({
      format_name: z.string().optional(),
    })
    .optional(),
  streams: z
    .array(
      z.object({
        codec_name: z.string().optional(),
      }),
    )
    .optional(),
});

interface VideoProbeInfo {
  readonly formatName: string;
  readonly codecName: string;
}

async function probeVideoStream(ctx: CommandContext, inputSource: string): Promise<VideoProbeInfo> {
  const probeRes = await ctx.runner.exec("ffprobe", [
    "-v",
    "error",
    "-select_streams",
    "v:0",
    "-show_entries",
    "stream=codec_name:format=format_name",
    "-of",
    "json",
    inputSource,
  ]);
  if (probeRes.exitCode !== 0 || probeRes.stdout.trim() === "") {
    return { formatName: "", codecName: "" };
  }

  let parsedJson: unknown;
  try {
    parsedJson = JSON.parse(probeRes.stdout);
  } catch {
    return { formatName: "", codecName: "" };
  }

  const validated = FfprobeOutputSchema.safeParse(parsedJson);
  if (!validated.success) {
    return { formatName: "", codecName: "" };
  }

  const formatName = validated.data.format?.format_name ?? "";
  const firstStream = validated.data.streams?.[0];
  const codecName = firstStream?.codec_name?.trim() ?? "";
  return { formatName, codecName };
}

function buildCodecArgs(input: {
  readonly copy: boolean;
  readonly isLocal: boolean;
  readonly probe: VideoProbeInfo;
  readonly qualityExplicitlySet: boolean;
  readonly isMac: boolean;
  readonly effectiveQuality: number;
}): readonly string[] {
  const canStreamCopy =
    input.copy ||
    (input.isLocal &&
      /mp4/i.test(input.probe.formatName) &&
      (input.probe.codecName === "h264" || input.probe.codecName === "hevc") &&
      !input.qualityExplicitlySet);

  if (canStreamCopy) {
    return ["-c:v", "copy", "-c:a", "copy"];
  }

  if (input.isMac) {
    return [
      "-c:v",
      "hevc_videotoolbox",
      "-q:v",
      input.effectiveQuality.toString(),
      "-profile:v",
      "main",
      "-pix_fmt",
      "yuv420p",
      "-tag:v",
      "hvc1",
      "-c:a",
      "aac",
      "-b:a",
      "192k",
    ];
  }

  return [
    "-c:v",
    "libx264",
    "-crf",
    input.effectiveQuality.toString(),
    "-preset",
    "fast",
    "-pix_fmt",
    "yuv420p",
    "-c:a",
    "aac",
    "-b:a",
    "192k",
  ];
}

/**
 * Fast video clip maker supporting local files (stream copy / HEVC / x264) and YouTube URLs.
 */
export const mkclpCommand = defineCommand({
  name: "mkclp",
  summary:
    "Clip Maker (Supports --quality [value], --copy, --browser, local files and YouTube videos)",
  usage: "mkclp [options] [input_file_or_url] [from(hh:mm:ss or sec)] [during(sec)]",
  examples: [
    "mkclp 'input.mp4' 01:02:08 11.0",
    "mkclp 'input.mp4' 00:00:10 5.0 --copy",
    "mkclp JoSY6AWKqHs 00:01:59 2 --quality 45",
  ],
  flags: {
    quality: {
      type: "string",
      short: "q",
      valueName: "num",
      description: "Set video quality factor (default: 50 on macOS HEVC, 23 on Windows x264)",
    },
    copy: {
      type: "boolean",
      short: "c",
      description: "Force lossless stream copy without re-encoding",
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
  optionsSchema: MkclpOptionsSchema,
  positionals: { min: 3, max: 3, label: "input_file_or_url from duration" },
  requiredCommands: ["ffmpeg", "ffprobe"],
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
    const parsedQuality =
      options.quality !== undefined
        ? parseValidatedInt(options.quality, "--quality", 0, 100)
        : null;

    const qualityExplicitlySet = parsedQuality !== null;
    const isMac = ctx.platform === "darwin";
    const effectiveQuality = parsedQuality ?? (isMac ? 50 : 23);

    const localFile = await resolveLocalMediaFile(ctx, inputArg);
    const isLocal = localFile !== null;

    const outputName = options.output ?? `${formatMediaTimestamp(ctx.now())}_clip.mp4`;
    const resolvedOutput = path.resolve(ctx.cwd, outputName);

    if (!isLocal) {
      const hasYtDlp = await ctx.runner.commandExists("yt-dlp");
      if (!hasYtDlp) {
        throw new MissingDependencyError("yt-dlp");
      }
    }

    if (ctx.dryRun) {
      if (!isLocal) {
        const endSec = startSec + durSec;
        const browser = resolveYtDlpBrowser(options.browser, ctx.env);
        ctx.stdout(
          `[dry-run] Download segment ${startSec.toString()}-${endSec.toString()} from "${inputArg}" via yt-dlp (browser=${browser})\n`,
        );
      }
      ctx.stdout(
        `[dry-run] Clip "${localFile ?? inputArg}" (start=${isLocal ? startText : "0"}, duration=${durationText}) -> "${resolvedOutput}"\n`,
      );
      return 0;
    }

    let tempSegment: YtDlpSegmentResult | null = null;
    let unregisterSignal: (() => void) | null = null;

    try {
      let inputSource = localFile ?? inputArg;
      let ffmpegStart = startText;

      if (!isLocal) {
        tempSegment = await downloadYtDlpSegment(ctx, {
          inputSource: inputArg,
          startSecond: startSec,
          endSecond: startSec + durSec,
          format: "bestvideo[height<=1080]+bestaudio/best[height<=1080]",
          browser: options.browser,
          forceKeyframesAtCuts: true,
        });
        const segmentDir = tempSegment.tempDir;
        unregisterSignal = ctx.onSignalCleanup(() => {
          void ctx.fs.rm(segmentDir, { recursive: true, force: true }).catch(() => {});
        });
        inputSource = tempSegment.filePath;
        ffmpegStart = "0";
      }

      const probe = await probeVideoStream(ctx, inputSource);
      const vcArgs = buildCodecArgs({
        copy: options.copy,
        isLocal,
        probe,
        qualityExplicitlySet,
        isMac,
        effectiveQuality,
      });

      const ffmpegRes = await ctx.runner.exec("ffmpeg", [
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
        "-map",
        "0:v:0",
        "-map",
        "0:a?",
        ...vcArgs,
        "-map_chapters",
        "-1",
        "-movflags",
        "+faststart",
        resolvedOutput,
      ]);

      if (ffmpegRes.exitCode !== 0) {
        const detail = formatNativeErrorDetail(
          [ffmpegRes.stderr, ffmpegRes.stdout],
          ffmpegRes.exitCode,
        );
        throw new ExecutionError(`Error: ffmpeg failed (${detail})`, ffmpegRes.exitCode);
      }

      try {
        const outStats = await ctx.fs.stat(resolvedOutput);
        if (outStats.isFile()) {
          ctx.stdout(`${outputName} ${formatByteSize(outStats.size)}\n`);
        }
      } catch {
        // Output size reporting is best-effort after a zero exit code.
      }

      return 0;
    } finally {
      unregisterSignal?.();
      if (tempSegment !== null) {
        await ctx.fs.rm(tempSegment.tempDir, { recursive: true, force: true }).catch(() => {});
      }
    }
  },
});
