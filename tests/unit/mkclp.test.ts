import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { describe, expect, it } from "vite-plus/test";

import { mkclpCommand } from "../../cli/src/commands/mkclp.ts";
import { ExecutionError, MissingDependencyError, UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

describe("mkclp command", () => {
  it("prints help documenting default browser as chrome", async () => {
    const { ctx, getStdout } = createTestContext();
    await expect(mkclpCommand.execute(["--help"], ctx)).resolves.toBe(0);
    const out = getStdout();
    expect(out).toContain("mkclp:");
    expect(out).toMatch(/default:\s*chrome/);
    expect(out).toContain("--dry-run");
  });

  it("validates options, time arguments, and required yt-dlp for remote sources", async () => {
    const { ctx } = createTestContext({
      runner: {
        commandExists: async (cmd) => cmd === "ffmpeg" || cmd === "ffprobe",
      },
    });

    await expect(mkclpCommand.execute(["input.mp4", "00:00:00"], ctx)).rejects.toThrow(UsageError);
    await expect(
      mkclpCommand.execute(["--quality", "101", "a.mp4", "0", "2"], ctx),
    ).rejects.toThrow(UsageError);
    await expect(mkclpCommand.execute(["a.mp4", "bad-time", "2"], ctx)).rejects.toThrow(UsageError);
    await expect(mkclpCommand.execute(["a.mp4", "0", "0"], ctx)).rejects.toThrow(UsageError);
    await expect(mkclpCommand.execute(["JoSY6AWKqHs", "0", "2"], ctx)).rejects.toThrow(
      MissingDependencyError,
    );
  });

  it("supports --dry-run for both local and remote inputs", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-mkclp-dry-"));
    try {
      await fs.writeFile(path.join(tempDir, "local.mp4"), "video");
      let execCount = 0;

      const localRun = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async () => {
            execCount += 1;
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(
        mkclpCommand.execute(["--dry-run", "local.mp4", "00:00:05", "3"], localRun.ctx),
      ).resolves.toBe(0);
      expect(execCount).toBe(0);
      expect(localRun.getStdout()).toContain("[dry-run] Clip");

      const remoteRun = createTestContext({
        cwd: tempDir,
        env: { YT_DLP_BROWSER: "safari" },
        runner: {
          commandExists: async () => true,
          exec: async () => {
            execCount += 1;
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(
        mkclpCommand.execute(["--dry-run", "JoSY6AWKqHs", "00:01:00", "4"], remoteRun.ctx),
      ).resolves.toBe(0);
      expect(execCount).toBe(0);
      expect(remoteRun.getStdout()).toContain("browser=safari");
      expect(remoteRun.getStdout()).toContain("[dry-run] Clip");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("uses lossless stream copy for compatible local MP4 without explicit quality", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-mkclp-copy-"));
    try {
      await fs.writeFile(path.join(tempDir, "video.mp4"), "mp4");
      const calls: Array<{ command: string; args: readonly string[] }> = [];

      const { ctx, getStdout } = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (command, args) => {
            calls.push({ command, args });
            if (command === "ffprobe") {
              return {
                exitCode: 0,
                stdout: JSON.stringify({
                  format: { format_name: "mov,mp4,m4a,3gp,3g2,mj2" },
                  streams: [{ codec_name: "h264" }],
                }),
                stderr: "",
              };
            }
            const outPath = args[args.length - 1];
            if (outPath !== undefined) {
              await fs.writeFile(outPath, "X".repeat(2048));
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      const code = await mkclpCommand.execute(
        ["video.mp4", "00:00:10", "5.0", "-o", "clip.mp4"],
        ctx,
      );
      expect(code).toBe(0);
      expect(calls).toHaveLength(2);
      expect(calls[1]?.command).toBe("ffmpeg");
      expect(calls[1]?.args).toContain("-c:v");
      expect(calls[1]?.args).toContain("copy");
      expect(getStdout()).toBe("clip.mp4 2K\n");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("uses hevc_videotoolbox on darwin and libx264 on win32 when re-encoding", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-mkclp-enc-"));
    try {
      await fs.writeFile(path.join(tempDir, "raw.mkv"), "mkv");

      const macCalls: Array<readonly string[]> = [];
      const macRun = createTestContext({
        cwd: tempDir,
        platform: "darwin",
        runner: {
          commandExists: async () => true,
          exec: async (command, args) => {
            if (command === "ffmpeg") {
              macCalls.push(args);
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(mkclpCommand.execute(["raw.mkv", "0", "2"], macRun.ctx)).resolves.toBe(0);
      expect(macCalls[0]).toContain("hevc_videotoolbox");
      expect(macCalls[0]).toContain("50");

      const winCalls: Array<readonly string[]> = [];
      const winRun = createTestContext({
        cwd: tempDir,
        platform: "win32",
        runner: {
          commandExists: async () => true,
          exec: async (command, args) => {
            if (command === "ffmpeg") {
              winCalls.push(args);
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(
        mkclpCommand.execute(["raw.mkv", "0", "2", "--quality", "20"], winRun.ctx),
      ).resolves.toBe(0);
      expect(winCalls[0]).toContain("libx264");
      expect(winCalls[0]).toContain("20");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("downloads remote segment, cleans temp dir on ffmpeg failure, and throws ExecutionError", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-mkclp-yt-"));
    let segmentTempDir = "";
    const calls: Array<{ command: string; args: readonly string[] }> = [];

    try {
      const { ctx } = createTestContext({
        cwd: tempDir,
        platform: "darwin",
        runner: {
          commandExists: async () => true,
          exec: async (command, args) => {
            calls.push({ command, args });
            if (command === "yt-dlp") {
              const outIdx = args.indexOf("-o");
              const outTemplate = outIdx >= 0 ? args[outIdx + 1] : undefined;
              if (outTemplate !== undefined) {
                segmentTempDir = path.dirname(outTemplate);
                await fs.writeFile(path.join(segmentTempDir, "segment.mp4"), "seg");
              }
              return { exitCode: 0, stdout: "", stderr: "" };
            }
            if (command === "ffprobe") {
              return { exitCode: 0, stdout: "{}", stderr: "" };
            }
            return { exitCode: 1, stdout: "", stderr: "encode error" };
          },
        },
      });

      await expect(
        mkclpCommand.execute(["JoSY6AWKqHs", "00:01:59", "2", "-b", "firefox"], ctx),
      ).rejects.toThrow(ExecutionError);

      expect(calls[0]?.command).toBe("yt-dlp");
      expect(calls[0]?.args).toContain("--force-keyframes-at-cuts");
      expect(calls[0]?.args).toContain("firefox");
      const ffmpegCall = calls.find((entry) => entry.command === "ffmpeg");
      expect(ffmpegCall?.args).toContain("0");
      await expect(fs.stat(segmentTempDir)).rejects.toThrow(/ENOENT/);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
