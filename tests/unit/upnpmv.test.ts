import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { describe, expect, it } from "vite-plus/test";

import { upnpmvCommand } from "../../cli/src/commands/upnpmv.ts";
import { MissingDependencyError, UsageError } from "../../cli/src/lib/context.ts";
import { createTestContext } from "./test-helpers.ts";

describe("upnpmv command", () => {
  it("prints help and rejects unknown flags, positional args, and missing commands", async () => {
    const helpRun = createTestContext();
    await expect(upnpmvCommand.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("packageManager");
    expect(helpRun.getStdout()).toContain("--dry-run");

    await expect(upnpmvCommand.execute(["--unknown-flag"], helpRun.ctx)).rejects.toThrow(
      UsageError,
    );
    await expect(upnpmvCommand.execute(["extra-arg"], helpRun.ctx)).rejects.toThrow(UsageError);

    const missingRun = createTestContext({
      runner: {
        commandExists: async (name) => name !== "git",
      },
    });
    await expect(upnpmvCommand.execute([], missingRun.ctx)).rejects.toThrow(MissingDependencyError);
  });

  it("handles remote query failures and supports --dry-run", async () => {
    const failRun = createTestContext({
      runner: {
        commandExists: async () => true,
        exec: async () => ({ exitCode: 1, stdout: "", stderr: "network down" }),
      },
    });
    await expect(upnpmvCommand.execute([], failRun.ctx)).resolves.toBe(1);
    expect(failRun.getStderr()).toContain("Failed to query remote pnpm versions");

    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-upnpmv-dry-"));
    try {
      const repoRoot = path.join(tempDir, "proj-a");
      await fs.mkdir(path.join(repoRoot, ".git"), { recursive: true });
      await fs.writeFile(
        path.join(repoRoot, "package.json"),
        '{"name":"proj-a","packageManager":"pnpm@12.20.0"}\n',
      );

      const mutatingCalls: string[] = [];
      const { ctx, getStdout } = createTestContext({
        repoRoot,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            if (cmd === "vp" && args[0] === "env" && args[1] === "list-remote") {
              return {
                exitCode: 0,
                stdout: JSON.stringify({
                  package_managers: {
                    pnpm: [{ version: "12.21.0", latest: true, installed: false }],
                  },
                }),
                stderr: "",
              };
            }
            mutatingCalls.push(`${cmd} ${args.join(" ")}`);
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(upnpmvCommand.execute(["--dry-run"], ctx)).resolves.toBe(0);
      expect(getStdout()).toContain("[dry-run] vp env install pnpm@12.21.0");
      expect(getStdout()).toContain("pnpm: v12.21.0");
      expect(getStdout()).toContain("[dry-run] Pin pnpm@12.21.0");
      expect(mutatingCalls).toEqual([]);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("pins outdated projects, syncs missing node_modules, and restores manifests on failure", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-upnpmv-exec-"));
    try {
      const okRepo = path.join(tempDir, "a-ok");
      const syncOnlyRepo = path.join(tempDir, "b-sync-only");
      const failInstallRepo = path.join(tempDir, "c-fail-install");

      await Promise.all(
        [okRepo, syncOnlyRepo, failInstallRepo].map((dir) =>
          fs.mkdir(path.join(dir, ".git"), { recursive: true }),
        ),
      );
      await fs.writeFile(
        path.join(okRepo, "package.json"),
        '{"name":"a-ok","packageManager":"pnpm@12.20.0"}\n',
      );
      await fs.writeFile(path.join(okRepo, "pnpm-lock.yaml"), "lockfileVersion: '9.0'\n");

      await fs.writeFile(
        path.join(syncOnlyRepo, "package.json"),
        '{"name":"b-sync","packageManager":"pnpm@12.21.0"}\n',
      );
      await fs.writeFile(path.join(syncOnlyRepo, "pnpm-lock.yaml"), "lockfileVersion: '9.0'\n");

      await fs.writeFile(
        path.join(failInstallRepo, "package.json"),
        '{"name":"c-fail","packageManager":"pnpm@12.20.0"}\n',
      );
      // Untracked lockfile created/not present before failure
      const calls: string[] = [];
      const { ctx, getStdout, getStderr } = createTestContext({
        repoRoot: okRepo,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            calls.push(`${cmd} ${args.join(" ")}`);
            if (cmd === "vp" && args[0] === "env" && args[1] === "list-remote") {
              return {
                exitCode: 0,
                stdout: JSON.stringify({
                  package_managers: {
                    pnpm: [{ version: "12.21.0", latest: true, installed: true }],
                  },
                }),
                stderr: "",
              };
            }
            if (cmd === "git" && args.includes("ls-files") && args[1] === failInstallRepo) {
              return { exitCode: 1, stdout: "", stderr: "" };
            }
            if (cmd === "vp" && args[1] === failInstallRepo && args.includes("install")) {
              await fs.writeFile(path.join(failInstallRepo, "pnpm-lock.yaml"), "temp");
              return { exitCode: 1, stdout: "", stderr: "install error" };
            }
            if (cmd === "git" && args.includes("--short") && args[1] === okRepo) {
              return { exitCode: 0, stdout: "M  package.json\n", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      const code = await upnpmvCommand.execute([], ctx);
      expect(code).toBe(1);
      expect(getStdout()).toContain("packageManager a-ok: pnpm@12.20.0 -> pnpm@12.21.0 ok");
      expect(getStdout()).toContain(
        "packageManager b-sync-only: pnpm@12.21.0 (node_modules synced) ok",
      );
      expect(getStderr()).toContain(
        "packageManager c-fail-install: vp install failed (install error)",
      );
      expect(calls.some((c) => c.includes(`-C ${okRepo} push -q`))).toBe(true);
      await expect(fs.stat(path.join(failInstallRepo, "pnpm-lock.yaml"))).rejects.toThrow(/ENOENT/);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("resets staged files and restores manifest when git commit fails", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-upnpmv-commit-fail-"));
    try {
      const repoRoot = path.join(tempDir, "proj-commit-fail");
      await fs.mkdir(path.join(repoRoot, ".git"), { recursive: true });
      await fs.writeFile(
        path.join(repoRoot, "package.json"),
        '{"name":"proj","packageManager":"pnpm@12.20.0"}\n',
      );
      await fs.writeFile(path.join(repoRoot, "pnpm-lock.yaml"), "lockfileVersion: '9.0'\n");

      const calls: string[] = [];
      const { ctx, getStderr } = createTestContext({
        repoRoot,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            calls.push(`${cmd} ${args.join(" ")}`);
            if (cmd === "vp" && args[0] === "env" && args[1] === "list-remote") {
              return {
                exitCode: 0,
                stdout: JSON.stringify({
                  package_managers: {
                    pnpm: [{ version: "12.21.0", latest: true, installed: true }],
                  },
                }),
                stderr: "",
              };
            }
            if (cmd === "git" && args.includes("--short")) {
              return { exitCode: 0, stdout: "M  package.json\n", stderr: "" };
            }
            if (cmd === "git" && args.includes("commit")) {
              return { exitCode: 1, stdout: "", stderr: "hook rejected" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(upnpmvCommand.execute([], ctx)).resolves.toBe(1);
      expect(getStderr()).toContain("failed to commit");
      expect(calls).toContain(`git -C ${repoRoot} reset -q HEAD -- package.json pnpm-lock.yaml`);
      expect(calls).toContain(`git -C ${repoRoot} checkout -q -- package.json`);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
