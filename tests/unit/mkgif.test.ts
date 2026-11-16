import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { describe, expect, it } from "vite-plus/test";

import { mkgifCommand } from "../../cli/src/commands/mkgif.ts";
import { ExecutionError, MissingDependencyError, UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

function buildPeBinary(subsystem: number): Buffer {
  const buf = Buffer.alloc(256);
  // DOS magic "MZ" and e_lfanew pointer at 0x3c -> 0x80
  buf.write("MZ", 0, "ascii");
  buf.writeInt32LE(0x80, 0x3c);
  // PE signature + subsystem field at peOffset + 0x5c
  buf.write("PE\0\0", 0x80, "ascii");
  buf.writeUInt16LE(subsystem, 0x80 + 0x5c);
  return buf;
}

describe("mkgif command", () => {
  it("prints help documenting default browser as chrome", async () => {
    const { ctx, getStdout } = createTestContext();
    await expect(mkgifCommand.execute(["--help"], ctx)).resolves.toBe(0);
    const out = getStdout();
    expect(out).toContain("mkgif:");
    expect(out).toMatch(/default:\s*chrome/);
    expect(out).toContain("--dry-run");
  });

  it("validates --width, --fps, --quality, time arguments, and yt-dlp presence", async () => {
    const { ctx } = createTestContext({
      runner: {
        commandExists: async (cmd) => cmd === "ffmpeg",
      },
    });

    await expect(mkgifCommand.execute(["--width", "10", "a.mp4", "0", "2"], ctx)).rejects.toThrow(
      UsageError,
    );
    await expect(mkgifCommand.execute(["--fps", "61", "a.mp4", "0", "2"], ctx)).rejects.toThrow(
      UsageError,
    );
    await expect(mkgifCommand.execute(["--quality", "0", "a.mp4", "0", "2"], ctx)).rejects.toThrow(
      UsageError,
    );
    await expect(mkgifCommand.execute(["a.mp4", "0", "-1"], ctx)).rejects.toThrow(UsageError);
    await expect(mkgifCommand.execute(["JoSY6AWKqHs", "0", "2"], ctx)).rejects.toThrow(
      MissingDependencyError,
    );
  });

  it("supports --dry-run without running yt-dlp, ffmpeg, or gifski", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-mkgif-dry-"));
    try {
      await fs.writeFile(path.join(tempDir, "in.mp4"), "video");
      let ranProcess = false;

      const { ctx, getStdout } = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async () => {
            ranProcess = true;
            return { exitCode: 0, stdout: "", stderr: "" };
          },
          pipe: async () => {
            ranProcess = true;
            return { leftExitCode: 0, rightExitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(
        mkgifCommand.execute(["--dry-run", "in.mp4", "0", "3", "-w", "480", "--fps", "15"], ctx),
      ).resolves.toBe(0);
      expect(ranProcess).toBe(false);
      expect(getStdout()).toContain("ffmpeg | gifski");
      expect(getStdout()).toContain("480px");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("pipes ffmpeg into gifski and checks both exit codes", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-mkgif-pipe-"));
    try {
      await fs.writeFile(path.join(tempDir, "clip.mp4"), "video");
      const pipeCalls: Array<{
        left: { command: string; args: readonly string[] };
        right: { command: string; args: readonly string[] };
      }> = [];

      const okRun = createTestContext({
        cwd: tempDir,
        platform: "darwin",
        runner: {
          commandExists: async () => true,
          pipe: async (left, right) => {
            pipeCalls.push({ left, right });
            const outIdx = right.args.indexOf("-o");
            const outPath = outIdx >= 0 ? right.args[outIdx + 1] : undefined;
            if (outPath !== undefined) {
              await fs.writeFile(outPath, "G".repeat(3072));
            }
            return { leftExitCode: 0, rightExitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      const code = await mkgifCommand.execute(
        [
          "clip.mp4",
          "00:00:01",
          "2.5",
          "-w",
          "640",
          "--fps",
          "12",
          "-q",
          "80",
          "-l",
          "-o",
          "out.gif",
        ],
        okRun.ctx,
      );
      expect(code).toBe(0);
      expect(pipeCalls).toHaveLength(1);
      expect(pipeCalls[0]?.left.command).toBe("ffmpeg");
      expect(pipeCalls[0]?.left.args).toContain("yuv4mpegpipe");
      expect(pipeCalls[0]?.right.command).toBe("gifski");
      expect(pipeCalls[0]?.right.args).toContain("--lossy-quality");
      expect(pipeCalls[0]?.right.args).toContain("80");
      expect(okRun.getStdout()).toBe("out.gif 3K\n");

      const leftFailRun = createTestContext({
        cwd: tempDir,
        platform: "darwin",
        runner: {
          commandExists: async () => true,
          pipe: async () => ({
            leftExitCode: 1,
            rightExitCode: 0,
            stdout: "",
            stderr: "ffmpeg decode failed",
          }),
        },
      });
      await expect(mkgifCommand.execute(["clip.mp4", "0", "2"], leftFailRun.ctx)).rejects.toThrow(
        ExecutionError,
      );
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("falls back to ffmpeg palettegen/paletteuse when gifski is missing or Windows GUI binary", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-mkgif-fallback-"));
    try {
      await fs.writeFile(path.join(tempDir, "clip.mp4"), "video");
      const binDir = path.join(tempDir, "bin");
      await fs.mkdir(binDir);
      const gifskiExe = path.join(binDir, "gifski.exe");

      // Case 1: gifski absent on POSIX -> palette fallback
      const posixCalls: Array<readonly string[]> = [];
      const noGifskiRun = createTestContext({
        cwd: tempDir,
        platform: "darwin",
        runner: {
          commandExists: async (cmd) => cmd === "ffmpeg",
          exec: async (_command, args) => {
            posixCalls.push(args);
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(
        mkgifCommand.execute(["clip.mp4", "0", "2", "-o", "fallback.gif"], noGifskiRun.ctx),
      ).resolves.toBe(0);
      expect(posixCalls[0]).toContain("-filter_complex");

      // Case 2: Windows GUI subsystem (2) -> palette fallback
      await fs.writeFile(gifskiExe, buildPeBinary(2));
      const winGuiCalls: Array<readonly string[]> = [];
      const winGuiRun = createTestContext({
        cwd: tempDir,
        platform: "win32",
        env: { PATH: binDir, PATHEXT: ".EXE" },
        runner: {
          commandExists: async () => true,
          exec: async (_command, args) => {
            winGuiCalls.push(args);
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(
        mkgifCommand.execute(["clip.mp4", "0", "2", "-o", "gui.gif"], winGuiRun.ctx),
      ).resolves.toBe(0);
      expect(winGuiCalls[0]).toContain("-filter_complex");

      // Case 3: Windows Console subsystem (3) -> uses gifski pipe even if extensionless shim coexists
      await fs.writeFile(path.join(binDir, "gifski"), "not-a-pe-posix-shim");
      await fs.writeFile(gifskiExe, buildPeBinary(3));
      let usedPipe = false;
      const winCliRun = createTestContext({
        cwd: tempDir,
        platform: "win32",
        env: { PATH: binDir, PATHEXT: ".EXE" },
        runner: {
          commandExists: async () => true,
          pipe: async () => {
            usedPipe = true;
            return { leftExitCode: 0, rightExitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(
        mkgifCommand.execute(["clip.mp4", "0", "2", "-o", "cli.gif"], winCliRun.ctx),
      ).resolves.toBe(0);
      expect(usedPipe).toBe(true);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("downloads remote segment with width-capped yt-dlp format and cleans up temp dir", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-mkgif-yt-"));
    let segmentTempDir = "";
    const execArgs: Array<{ command: string; args: readonly string[] }> = [];

    try {
      const { ctx } = createTestContext({
        cwd: tempDir,
        platform: "darwin",
        runner: {
          commandExists: async (cmd) => cmd === "ffmpeg" || cmd === "yt-dlp",
          exec: async (command, args) => {
            execArgs.push({ command, args });
            if (command === "yt-dlp") {
              const outIdx = args.indexOf("-o");
              const outTemplate = outIdx >= 0 ? args[outIdx + 1] : undefined;
              if (outTemplate !== undefined) {
                segmentTempDir = path.dirname(outTemplate);
                await fs.writeFile(path.join(segmentTempDir, "segment.mp4"), "seg");
              }
              return { exitCode: 0, stdout: "", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(
        mkgifCommand.execute(["JoSY6AWKqHs", "00:01:59", "3", "-w", "480", "-o", "yt.gif"], ctx),
      ).resolves.toBe(0);

      expect(execArgs[0]?.command).toBe("yt-dlp");
      expect(execArgs[0]?.args).toContain("--force-keyframes-at-cuts");
      expect(execArgs[0]?.args).toContain(
        "bestvideo[height<=480]/best[height<=480]/bestvideo/best",
      );
      await expect(fs.stat(segmentTempDir)).rejects.toThrow(/ENOENT/);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
