import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vite-plus/test";
import { reaCommand } from "../../cli/src/commands/rea.ts";
import { ExecutionError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

describe("rea command", () => {
  it("prints help on --help", async () => {
    const { ctx, getStdout } = createTestContext();
    await expect(reaCommand.execute(["--help"], ctx)).resolves.toBe(0);
    expect(getStdout()).toContain("rea:");
    expect(getStdout()).toContain("--dry-run");
  });

  it("rejects directory with multiple .mkv files without deleting directory", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-rea-multi-"));
    try {
      const inputDir = path.join(tempDir, "episode");
      await fs.mkdir(inputDir, { recursive: true });
      await fs.writeFile(path.join(inputDir, "a.mkv"), "");
      await fs.writeFile(path.join(inputDir, "b.mkv"), "");
      await fs.writeFile(path.join(inputDir, "a.cht.ass"), "");

      let ffmpegInvoked = false;
      const { ctx } = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async (cmd) => cmd === "ffmpeg",
          exec: async () => {
            ffmpegInvoked = true;
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(reaCommand.execute(["episode"], ctx)).rejects.toThrow(
        /Multiple \.mkv files found/,
      );
      expect(ffmpegInvoked).toBe(false);
      const stat = await fs.stat(inputDir);
      expect(stat.isDirectory()).toBe(true);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("rejects missing directory, root path, missing mkv, and missing ass", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-rea-guards-"));
    try {
      const { ctx } = createTestContext({
        cwd: tempDir,
        runner: { commandExists: async () => true },
      });

      await expect(reaCommand.execute(["nonexistent"], ctx)).rejects.toThrow(ExecutionError);
      await expect(reaCommand.execute([path.parse(tempDir).root], ctx)).rejects.toThrow(
        /cannot be root or empty/,
      );

      const noMkvDir = path.join(tempDir, "no-mkv");
      await fs.mkdir(noMkvDir);
      await fs.writeFile(path.join(noMkvDir, "sub.ass"), "");
      await expect(reaCommand.execute(["no-mkv"], ctx)).rejects.toThrow(/No \.mkv file found/);

      const noAssDir = path.join(tempDir, "no-ass");
      await fs.mkdir(noAssDir);
      await fs.writeFile(path.join(noAssDir, "video.mkv"), "");
      await expect(reaCommand.execute(["no-ass"], ctx)).rejects.toThrow(
        /No \.ass subtitle file found/,
      );
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("supports --dry-run without running ffmpeg or deleting files", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-rea-dry-"));
    try {
      const inputDir = path.join(tempDir, "Episode01");
      await fs.mkdir(inputDir);
      await fs.writeFile(path.join(inputDir, "video.mkv"), "mkv");
      await fs.writeFile(path.join(inputDir, "sub.chs.ass"), "chs");
      await fs.writeFile(path.join(inputDir, "sub.cht.ass"), "cht");

      let execCount = 0;
      const { ctx, getStdout } = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async () => {
            execCount += 1;
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(reaCommand.execute(["--dry-run", "Episode01"], ctx)).resolves.toBe(0);
      expect(execCount).toBe(0);
      expect(getStdout()).toContain("[dry-run] Combine");
      expect(getStdout()).toContain("sub.cht.ass");
      await expect(fs.stat(inputDir)).resolves.toBeDefined();
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("prefers cht/tc/zh-tw subtitle, runs ffmpeg, moves output up, and removes source dir", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-rea-ok-"));
    try {
      const inputDir = path.join(tempDir, "Movie");
      await fs.mkdir(inputDir);
      await fs.writeFile(path.join(inputDir, "movie.mkv"), "video");
      await fs.writeFile(path.join(inputDir, "movie.chs.ass"), "chs");
      await fs.writeFile(path.join(inputDir, "movie.zh-tw.ass"), "cht");

      const execCalls: Array<{ command: string; args: readonly string[] }> = [];
      const { ctx, getStdout } = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (command, args) => {
            execCalls.push({ command, args });
            const outPath = args[args.length - 1];
            if (outPath !== undefined) {
              await fs.writeFile(outPath, "A".repeat(2048));
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      const code = await reaCommand.execute(["Movie"], ctx);
      expect(code).toBe(0);
      expect(execCalls).toHaveLength(1);
      expect(execCalls[0]?.command).toBe("ffmpeg");
      expect(execCalls[0]?.args).toContain(path.join(inputDir, "movie.zh-tw.ass"));

      expect(getStdout()).toBe("Movie.mkv 2K ok\n");
      const outputData = await fs.readFile(path.join(tempDir, "Movie.mkv"), "utf8");
      expect(outputData).toHaveLength(2048);
      await expect(fs.stat(inputDir)).rejects.toThrow(/ENOENT/);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("preserves input directory and cleans temp file when ffmpeg fails", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-rea-fail-"));
    try {
      const inputDir = path.join(tempDir, "Show");
      await fs.mkdir(inputDir);
      await fs.writeFile(path.join(inputDir, "show.mkv"), "video");
      await fs.writeFile(path.join(inputDir, "show.ass"), "sub");

      const { ctx } = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (_command, args) => {
            const tmpPath = args[args.length - 1];
            if (tmpPath !== undefined) {
              await fs.writeFile(tmpPath, "partial");
            }
            return { exitCode: 1, stdout: "", stderr: "muxing error" };
          },
        },
      });

      await expect(reaCommand.execute(["Show"], ctx)).rejects.toThrow(/muxing error/);
      await expect(fs.stat(inputDir)).resolves.toBeDefined();
      const parentFiles = await fs.readdir(tempDir);
      expect(parentFiles.some((name) => name.startsWith(".tmp_rea_"))).toBe(false);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
