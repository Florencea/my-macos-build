import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vite-plus/test";
import { ExecutionError, UsageError } from "../../cli/src/lib/context.ts";
import {
  downloadYtDlpSegment,
  formatMediaTimestamp,
  parseTimeToSeconds,
  resolveLocalMediaFile,
  resolveYtDlpBrowser,
} from "../../cli/src/lib/media.ts";
import { createTestContext } from "./test-helpers.ts";

describe("media utilities", () => {
  it("parses HH:MM:SS.ms, MM:SS, and numeric seconds", () => {
    expect(parseTimeToSeconds("01:02:03.5")).toBeCloseTo(3723.5, 4);
    expect(parseTimeToSeconds("02:30")).toBeCloseTo(150.0, 4);
    expect(parseTimeToSeconds("12.5")).toBeCloseTo(12.5, 4);
    expect(parseTimeToSeconds("0")).toBe(0);
  });

  it("rejects negative, >=60 minutes/seconds, non-positive duration, and invalid time text", () => {
    expect(() => parseTimeToSeconds("-1")).toThrow(UsageError);
    expect(() => parseTimeToSeconds("01:60")).toThrow(UsageError);
    expect(() => parseTimeToSeconds("01:60:00")).toThrow(UsageError);
    expect(() => parseTimeToSeconds("0", { positiveOnly: true })).toThrow(UsageError);
    expect(() => parseTimeToSeconds("not-a-time")).toThrow(UsageError);
    expect(() => parseTimeToSeconds("   ")).toThrow(UsageError);
  });

  it("resolves yt-dlp browser with explicit > env > default chrome precedence", () => {
    expect(resolveYtDlpBrowser(undefined, {})).toBe("chrome");
    expect(resolveYtDlpBrowser("   ", {})).toBe("chrome");
    expect(resolveYtDlpBrowser(undefined, { YT_DLP_BROWSER: " edge " })).toBe("edge");
    expect(resolveYtDlpBrowser(" firefox ", { YT_DLP_BROWSER: "edge" })).toBe("firefox");
  });

  it("formats media timestamps and detects local files relative to cwd", async () => {
    const sampleDate = new Date(2026, 0, 2, 3, 4, 5);
    expect(formatMediaTimestamp(sampleDate)).toBe("20260102030405");

    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-media-local-"));
    try {
      await fs.writeFile(path.join(tempDir, "clip.mp4"), "data");
      await fs.mkdir(path.join(tempDir, "folder"));
      const { ctx } = createTestContext({ cwd: tempDir });

      await expect(resolveLocalMediaFile(ctx, "clip.mp4")).resolves.toBe(
        path.join(tempDir, "clip.mp4"),
      );
      await expect(resolveLocalMediaFile(ctx, "folder")).resolves.toBeNull();
      await expect(resolveLocalMediaFile(ctx, "missing.mp4")).resolves.toBeNull();
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("downloads yt-dlp segment with browser cookies and ignores .part/.ytdl files", async () => {
    const calls: Array<{ command: string; args: readonly string[] }> = [];
    const { ctx } = createTestContext({
      env: { YT_DLP_BROWSER: "brave" },
      runner: {
        exec: async (command, args) => {
          calls.push({ command, args });
          const outArgIdx = args.indexOf("-o");
          const outTemplate = outArgIdx >= 0 ? args[outArgIdx + 1] : undefined;
          if (outTemplate !== undefined) {
            const dir = path.dirname(outTemplate);
            await fs.writeFile(path.join(dir, "segment.mp4.part"), "partial");
            await fs.writeFile(path.join(dir, "segment.mp4.ytdl"), "meta");
            await fs.writeFile(path.join(dir, "segment.mp4"), "video");
          }
          return { exitCode: 0, stdout: "", stderr: "" };
        },
      },
    });

    const result = await downloadYtDlpSegment(ctx, {
      inputSource: "JoSY6AWKqHs",
      startSecond: 10,
      endSecond: 15,
      format: "bestvideo+bestaudio",
      forceKeyframesAtCuts: true,
    });

    try {
      expect(calls).toHaveLength(1);
      expect(calls[0]?.command).toBe("yt-dlp");
      expect(calls[0]?.args).toContain("--cookies-from-browser");
      expect(calls[0]?.args).toContain("brave");
      expect(calls[0]?.args).toContain("--force-keyframes-at-cuts");
      expect(calls[0]?.args).toContain("*10-15");
      expect(path.basename(result.filePath)).toBe("segment.mp4");
    } finally {
      await fs.rm(result.tempDir, { recursive: true, force: true });
    }
  });

  it("falls back to cookie-less yt-dlp and cleans temp dir if both attempts fail", async () => {
    const calls: Array<readonly string[]> = [];
    let createdTempDir = "";

    const fallbackRun = createTestContext({
      runner: {
        exec: async (_command, args) => {
          calls.push(args);
          const outArgIdx = args.indexOf("-o");
          const outTemplate = outArgIdx >= 0 ? args[outArgIdx + 1] : undefined;
          if (outTemplate !== undefined) {
            createdTempDir = path.dirname(outTemplate);
            if (args.includes("--cookies-from-browser")) {
              await fs.writeFile(path.join(createdTempDir, "segment.mp4.part"), "broken");
              return { exitCode: 1, stdout: "", stderr: "cookie error" };
            }
            await fs.writeFile(path.join(createdTempDir, "segment.webm"), "ok");
          }
          return { exitCode: 0, stdout: "", stderr: "" };
        },
      },
    });

    const segment = await downloadYtDlpSegment(fallbackRun.ctx, {
      inputSource: "https://youtu.be/abc",
      startSecond: 0,
      endSecond: 5,
      format: "best",
      browser: "firefox",
    });

    try {
      expect(calls).toHaveLength(2);
      expect(calls[0]).toContain("--cookies-from-browser");
      expect(calls[0]).toContain("firefox");
      expect(calls[1]).not.toContain("--cookies-from-browser");
      expect(path.basename(segment.filePath)).toBe("segment.webm");
    } finally {
      await fs.rm(segment.tempDir, { recursive: true, force: true });
    }

    let failedTempDir = "";
    const failingRun = createTestContext({
      runner: {
        exec: async (_command, args) => {
          const outArgIdx = args.indexOf("-o");
          const outTemplate = outArgIdx >= 0 ? args[outArgIdx + 1] : undefined;
          if (outTemplate !== undefined) {
            failedTempDir = path.dirname(outTemplate);
          }
          return { exitCode: 1, stdout: "", stderr: "network error" };
        },
      },
    });

    await expect(
      downloadYtDlpSegment(failingRun.ctx, {
        inputSource: "https://youtu.be/fail",
        startSecond: 0,
        endSecond: 5,
        format: "best",
      }),
    ).rejects.toThrow(ExecutionError);
    await expect(fs.stat(failedTempDir)).rejects.toThrow(/ENOENT/);
  });
});
