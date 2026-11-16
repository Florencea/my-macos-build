import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import process from "node:process";

import { describe, expect, it } from "vite-plus/test";

import {
  buildSpawnEnv,
  createNodeCommandRunner,
  mapWithConcurrency,
  resolveExecutableInPath,
  runSequentially,
} from "../../cli/src/lib/process.ts";
import { runMain } from "../../cli/src/main.ts";

describe("main entrypoint and process utilities", () => {
  it("reports missing or unknown commands with exit code 2", async () => {
    let errMissing = "";
    const missingCode = await runMain([], {
      stderr: (text) => {
        errMissing += text;
      },
    });
    expect(missingCode).toBe(2);
    expect(errMissing).toContain("Missing command name");

    let errUnknown = "";
    const unknownCode = await runMain(["does-not-exist"], {
      stderr: (text) => {
        errUnknown += text;
      },
    });
    expect(unknownCode).toBe(2);
    expect(errUnknown).toContain("Unknown command 'does-not-exist'");
  });

  it("runs signal cleanup, aborts pending execution, and returns 130 on SIGINT", async () => {
    let cleanedProcesses = false;
    let terminatedSignal: string | undefined;
    let out = "";
    let err = "";

    let resolveExecStarted: (() => void) | undefined;
    const execStarted = new Promise<void>((resolve) => {
      resolveExecStarted = resolve;
    });

    const runPromise = runMain(["up"], {
      stdout: (text) => {
        out += text;
      },
      stderr: (text) => {
        err += text;
      },
      onSignalTerminate: (sig) => {
        terminatedSignal = sig;
      },
      runner: {
        commandExists: async () => true,
        exec: () => {
          resolveExecStarted?.();
          return new Promise(() => {
            // Never resolves unless signal aborts runMain
          });
        },
        pipe: async () => ({ leftExitCode: 0, rightExitCode: 0, stdout: "", stderr: "" }),
        spawnInteractive: async () => 0,
        cleanupActiveProcesses: () => {
          cleanedProcesses = true;
        },
      },
    });

    await execStarted;
    process.emit("SIGINT");

    const exitCode = await runPromise;
    expect(exitCode).toBe(130);
    expect(cleanedProcesses).toBe(true);
    expect(terminatedSignal).toBe("SIGINT");
    expect(out).toBe("");
    expect(err).toBe("");
  });

  it("awaits async onSignalCleanup rollback handlers before resolving on SIGINT", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-sigint-rollback-"));
    const prevCwd = process.cwd();
    try {
      await fs.writeFile(
        path.join(tempDir, "package.json"),
        JSON.stringify({ name: "demo", devDependencies: { "vite-plus": "1.5.0" } }),
      );
      process.chdir(tempDir);

      let resolveEntered: (() => void) | undefined;
      const enteredTransaction = new Promise<void>((resolve) => {
        resolveEntered = resolve;
      });
      let rollbackCompleted = false;
      let terminatedBeforeRollback = false;

      const runPromise = runMain(["up"], {
        stdout: () => {},
        stderr: () => {},
        onSignalTerminate: () => {
          terminatedBeforeRollback = !rollbackCompleted;
        },
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "git" && args.includes("@{u}")) {
              return { exitCode: 1, stdout: "", stderr: "" };
            }
            if (args[0] === "--version") {
              return { exitCode: 0, stdout: "vp v1.6.0\n", stderr: "" };
            }
            if (cmd === "vpx" && args.includes("--jsonUpgraded")) {
              return { exitCode: 0, stdout: '{"zod":"4.6.7"}\n', stderr: "" };
            }
            if (cmd === "vp" && args[0] === "migrate") {
              resolveEntered?.();
              return await new Promise(() => {
                // Simulate long-running command interrupted by SIGINT
              });
            }
            if (cmd === "git" && args.includes("reset")) {
              await new Promise((resolve) => {
                setTimeout(resolve, 30);
              });
              rollbackCompleted = true;
              return { exitCode: 0, stdout: "", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
          pipe: async () => ({ leftExitCode: 0, rightExitCode: 0, stdout: "", stderr: "" }),
          spawnInteractive: async () => 0,
          cleanupActiveProcesses: () => {},
        },
      });

      await enteredTransaction;

      process.emit("SIGINT");
      const exitCode = await runPromise;
      expect(exitCode).toBe(130);
      expect(rollbackCompleted).toBe(true);
      expect(terminatedBeforeRollback).toBe(false);
    } finally {
      process.chdir(prevCwd);
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("ignores extensionless POSIX shims on win32 and resolves .cmd/.exe via PATHEXT", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-win-pathext-"));
    try {
      await fs.writeFile(path.join(tempDir, "ebk"), "#!/usr/bin/env sh\n");
      await fs.writeFile(path.join(tempDir, "ebk.cmd"), "@echo off\n");

      const resolved = await resolveExecutableInPath(
        "ebk",
        { PATH: tempDir, PATHEXT: ".COM;.EXE;.BAT;.CMD" },
        "win32",
      );
      expect(resolved?.toLowerCase()).toBe(path.join(tempDir, "ebk.cmd").toLowerCase());

      const missingExt = await resolveExecutableInPath(
        "only-posix",
        { PATH: tempDir, PATHEXT: ".COM;.EXE;.BAT;.CMD" },
        "win32",
      );
      await fs.writeFile(path.join(tempDir, "only-posix"), "#!/usr/bin/env sh\n");
      expect(missingExt).toBeNull();
      await expect(
        resolveExecutableInPath(
          "only-posix",
          { PATH: tempDir, PATHEXT: ".COM;.EXE;.BAT;.CMD" },
          "win32",
        ),
      ).resolves.toBeNull();
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("collapses case-variant env keys on win32 in buildSpawnEnv", () => {
    const merged = buildSpawnEnv(
      { Path: "C:\\Windows", SystemRoot: "C:\\Windows" },
      { PATH: "C:\\Custom;C:\\Windows" },
      "win32",
    );
    expect(merged["PATH"]).toBe("C:\\Custom;C:\\Windows");
    expect(Object.hasOwn(merged, "Path")).toBe(false);
    expect(merged["SystemRoot"]).toBe("C:\\Windows");
  });

  it("preserves order and undefined values in mapWithConcurrency and runs sequentially", async () => {
    const mapped = await mapWithConcurrency(["a", "b", "c", "d"], 2, async (item, index) => {
      if (index % 2 === 1) {
        return undefined;
      }
      return `${item}-${index.toString()}`;
    });
    expect(mapped).toEqual(["a-0", undefined, "c-2", undefined]);

    const order: string[] = [];
    await runSequentially(["first", "second", "third"], async (item) => {
      order.push(`start:${item}`);
      await new Promise((resolve) => {
        setTimeout(resolve, 10);
      });
      order.push(`end:${item}`);
    });
    expect(order).toEqual([
      "start:first",
      "end:first",
      "start:second",
      "end:second",
      "start:third",
      "end:third",
    ]);
  });

  it("handles downstream early exit cleanly in runner.pipe", async () => {
    const runner = createNodeCommandRunner();
    const res = await runner.pipe(
      {
        command: process.execPath,
        args: ["-e", "process.stdout.write('line1\\n'.repeat(5000))"],
      },
      {
        command: process.execPath,
        args: ["-e", "process.exit(0)"],
      },
    );
    expect(res.rightExitCode).toBe(0);
  });
});
