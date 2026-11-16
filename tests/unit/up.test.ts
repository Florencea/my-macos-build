import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import { describe, expect, it } from "vite-plus/test";

import { upCommand } from "../../cli/src/commands/up.ts";
import { MissingDependencyError, UsageError } from "../../cli/src/lib/context.ts";
import {
  backupNodeModules,
  removeNodeModulesBackup,
  restoreNodeModulesBackup,
  runBranchTransaction,
} from "../../cli/src/lib/transaction.ts";
import { createTestContext } from "./test-helpers.ts";

describe("up command and transactional rollback", () => {
  it("prints help and rejects unknown flags, positional args, and missing binaries", async () => {
    const helpRun = createTestContext();
    await expect(upCommand.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("up:");
    expect(helpRun.getStdout()).toContain("--dry-run");

    await expect(upCommand.execute(["--unknown"], helpRun.ctx)).rejects.toThrow(UsageError);
    await expect(upCommand.execute(["extra"], helpRun.ctx)).rejects.toThrow(UsageError);

    const missingRun = createTestContext({
      runner: {
        commandExists: async (name) => name !== "yq",
      },
    });
    await expect(upCommand.execute([], missingRun.ctx)).rejects.toThrow(MissingDependencyError);
  });

  it("enforces preflight guards (missing package.json, non-main branch, dirty tree, pull failure)", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-up-guards-"));
    try {
      const noPkg = createTestContext({
        cwd: tempDir,
        runner: { commandExists: async () => true },
      });
      await expect(upCommand.execute([], noPkg.ctx)).resolves.toBe(1);
      expect(noPkg.getStderr()).toContain("File package.json does not exist");

      await fs.writeFile(path.join(tempDir, "package.json"), '{"name":"demo"}\n');

      const wrongBranch = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "feat/test\n", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(upCommand.execute([], wrongBranch.ctx)).resolves.toBe(1);
      expect(wrongBranch.getStderr()).toContain("Current branch is not 'main'");

      const dirtyTree = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "git" && args.includes("--porcelain")) {
              return { exitCode: 0, stdout: " M README.md\n", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(upCommand.execute([], dirtyTree.ctx)).resolves.toBe(1);
      expect(dirtyTree.getStderr()).toContain("Working directory is not clean");

      const pullFail = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "git" && args[0] === "pull") {
              return { exitCode: 1, stdout: "", stderr: "diverged" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(upCommand.execute([], pullFail.ctx)).resolves.toBe(1);
      expect(pullFail.getStderr()).toContain("Cannot fast-forward with remote");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("exits 0 when up-to-date and supports --dry-run without creating branches", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-up-dry-"));
    try {
      await fs.writeFile(
        path.join(tempDir, "package.json"),
        '{"name":"demo","devDependencies":{"vite-plus":"1.5.0","zod":"4.6.0"}}\n',
      );

      const upToDateRun = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "git" && args.includes("@{u}")) {
              return { exitCode: 1, stdout: "", stderr: "" };
            }
            if (cmd === "vp" && args[0] === "--version") {
              return { exitCode: 0, stdout: "vp v1.5.0\n", stderr: "" };
            }
            if (cmd === "vpx") {
              return { exitCode: 0, stdout: "{}\n", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });
      await expect(upCommand.execute([], upToDateRun.ctx)).resolves.toBe(0);
      expect(upToDateRun.getStdout()).toBe("");

      const branchCalls: string[] = [];
      const dryRun = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            if (cmd === "git" && (args.includes("-b") || args[0] === "pull")) {
              branchCalls.push(`${cmd} ${args.join(" ")}`);
            }
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "vp" && args[0] === "--version") {
              return { exitCode: 0, stdout: "vp v1.6.0\n", stderr: "" };
            }
            if (cmd === "vpx" && args.includes("--jsonUpgraded")) {
              return { exitCode: 0, stdout: '{"zod":"4.6.7"}\n', stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(upCommand.execute(["--dry-run"], dryRun.ctx)).resolves.toBe(0);
      expect(branchCalls).toEqual([]);
      expect(dryRun.getStdout()).toContain("zod  4.6.0  ->  4.6.7");
      expect(dryRun.getStdout()).toContain("vite-plus  1.5.0  ->  1.6.0");
      expect(dryRun.getStdout()).toContain("[dry-run] Would run transactional upgrade");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("executes Vite+ and GitHub Actions upgrade transaction, merges to main, and pushes", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-up-ok-"));
    try {
      await fs.mkdir(path.join(tempDir, ".github", "workflows"), { recursive: true });
      const wfPath = path.join(tempDir, ".github", "workflows", "ci.yml");
      await fs.writeFile(wfPath, "jobs:\n  ci:\n    steps:\n      - uses: actions/checkout@v4\n");
      await fs.writeFile(
        path.join(tempDir, "package.json"),
        JSON.stringify({
          name: "demo",
          devDependencies: { "vite-plus": "1.5.0", typescript: "7.0.2" },
          scripts: { "agent:verify:gate": "vp test" },
        }),
      );

      let pendingStatusPhase = 0;
      const execCalls: string[] = [];
      const { ctx, getStdout } = createTestContext({
        cwd: tempDir,
        now: () => new Date("2026-01-01T00:00:10Z"),
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            execCalls.push(args.length > 0 ? `${cmd} ${args.join(" ")}` : cmd);
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "git" && args.includes("--porcelain")) {
              pendingStatusPhase += 1;
              // Call 1: initial clean check; Call 2: dep commit check; Call 3: ci commit check
              return {
                exitCode: 0,
                stdout: pendingStatusPhase === 1 ? "" : "M  changed\n",
                stderr: "",
              };
            }
            if (cmd === "vp" && args[0] === "--version") {
              return { exitCode: 0, stdout: "vp v1.6.0\n", stderr: "" };
            }
            if (cmd === "vpx" && args.includes("--jsonUpgraded")) {
              return { exitCode: 0, stdout: '{"zod":"4.6.7"}\n', stderr: "" };
            }
            if (cmd === "yq") {
              return {
                exitCode: 0,
                stdout: JSON.stringify([{ uses: "actions/checkout@v4", line: 4 }]),
                stderr: "",
              };
            }
            if (cmd === "git" && args.includes("ls-remote")) {
              return { exitCode: 0, stdout: "sha\trefs/tags/v4.2.1\n", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(upCommand.execute([], ctx)).resolves.toBe(0);
      expect(execCalls).toContain("git checkout -q -b chore/deps-upgrade-1767225610");
      expect(execCalls).toContain("vp migrate --no-interactive");
      expect(execCalls).toContain("vpr agent:verify:gate");
      expect(execCalls).toContain("actionlint");
      expect(execCalls).toContain("git merge --ff-only -q chore/deps-upgrade-1767225610");
      expect(execCalls).toContain("git push -q origin main");

      const updatedWf = await fs.readFile(wfPath, "utf8");
      expect(updatedWf).toContain("actions/checkout@v4.2.1");

      const out = getStdout();
      expect(out).toContain("Pushed: chore(deps): update dependencies (2 packages)");
      expect(out).toContain("Pushed: chore(ci): update action actions/checkout v4 -> v4.2.1");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("rolls back to main and restores .node_modules.bak or re-syncs frozen lockfile on failure", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-up-rollback-"));
    try {
      await fs.mkdir(path.join(tempDir, "node_modules", "sample-pkg"), { recursive: true });
      await fs.writeFile(path.join(tempDir, "node_modules", "sample-pkg", "index.js"), "ok");
      await fs.writeFile(
        path.join(tempDir, "package.json"),
        JSON.stringify({
          name: "non-vp-app",
          dependencies: { zod: "4.6.0" },
          scripts: { "agent:verify:gate": "vp test" },
        }),
      );

      // Case 1: vp install fails while .node_modules.bak exists -> backup restored
      const installFailCalls: string[] = [];
      const installFailRun = createTestContext({
        cwd: tempDir,
        now: () => new Date("2026-01-01T00:00:20Z"),
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            installFailCalls.push(args.length > 0 ? `${cmd} ${args.join(" ")}` : cmd);
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "git" && args.includes("@{u}")) {
              return { exitCode: 1, stdout: "", stderr: "" };
            }
            if (cmd === "vpx" && args.includes("--jsonUpgraded")) {
              return { exitCode: 0, stdout: '{"zod":"4.6.7"}\n', stderr: "" };
            }
            if (cmd === "vp" && args[0] === "install" && args[1] === "--frozen-lockfile") {
              return { exitCode: 1, stdout: "", stderr: "lockfile install error" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(upCommand.execute([], installFailRun.ctx)).resolves.toBe(1);
      expect(installFailRun.getStderr()).toContain("lockfile install error");
      expect(installFailRun.getStderr()).toContain(
        "Error: Pre-checks failed at step 'vp install'. Rolling back changes to 'main'...",
      );
      expect(installFailCalls).toContain("git reset --hard -q");
      expect(installFailCalls).toContain("git checkout -q main");
      expect(installFailCalls).toContain("git branch -D chore/deps-upgrade-1767225620");
      await expect(
        fs.readFile(path.join(tempDir, "node_modules", "sample-pkg", "index.js"), "utf8"),
      ).resolves.toBe("ok");
      await expect(fs.stat(path.join(tempDir, ".node_modules.bak"))).rejects.toThrow(/ENOENT/);

      // Case 2: gate fails after backup cleanup -> re-syncs frozen lockfile during rollback
      const gateFailCalls: string[] = [];
      const gateFailRun = createTestContext({
        cwd: tempDir,
        now: () => new Date("2026-01-01T00:00:30Z"),
        runner: {
          commandExists: async () => true,
          exec: async (cmd, args) => {
            gateFailCalls.push(args.length > 0 ? `${cmd} ${args.join(" ")}` : cmd);
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "git" && args.includes("@{u}")) {
              return { exitCode: 1, stdout: "", stderr: "" };
            }
            if (cmd === "vpx" && args.includes("--jsonUpgraded")) {
              return { exitCode: 0, stdout: '{"zod":"4.6.7"}\n', stderr: "" };
            }
            if (cmd === "vpr" && args[0] === "agent:verify:gate") {
              return { exitCode: 1, stdout: "", stderr: "gate test failed" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(upCommand.execute([], gateFailRun.ctx)).resolves.toBe(1);
      expect(gateFailRun.getStderr()).toContain("gate test failed");
      expect(gateFailRun.getStderr()).toContain(
        "Error: Pre-checks failed at step 'vpr agent:verify:gate (gate)'. Rolling back changes to 'main'...",
      );
      expect(gateFailCalls).toContain("vp install --frozen-lockfile --silent");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("supports node_modules backup lifecycle and branch transaction helper directly", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-tx-direct-"));
    try {
      await fs.mkdir(path.join(tempDir, "node_modules", "pkg"), { recursive: true });
      await expect(backupNodeModules(fs, tempDir)).resolves.toBe(true);
      await expect(fs.stat(path.join(tempDir, ".node_modules.bak", "pkg"))).resolves.toBeDefined();
      await expect(restoreNodeModulesBackup(fs, tempDir)).resolves.toBe(true);
      await expect(fs.stat(path.join(tempDir, "node_modules", "pkg"))).resolves.toBeDefined();
      await backupNodeModules(fs, tempDir);
      await removeNodeModulesBackup(fs, tempDir);
      await expect(fs.stat(path.join(tempDir, ".node_modules.bak"))).rejects.toThrow(/ENOENT/);

      let rollbackRan = false;
      const { ctx, getStderr } = createTestContext({
        cwd: tempDir,
        runner: { exec: async () => ({ exitCode: 0, stdout: "", stderr: "" }) },
      });
      await expect(
        runBranchTransaction(
          ctx,
          {
            tempBranch: "chore/tx-test",
            onRollback: async () => {
              rollbackRan = true;
            },
          },
          async (tx) => {
            tx.setStep("custom-step");
            throw new Error("boom");
          },
        ),
      ).rejects.toThrow("boom");
      expect(rollbackRan).toBe(true);
      expect(getStderr()).toContain("Pre-checks failed at step 'custom-step'");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("reports non-spinner errors such as missing actionlint before rolling back", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-up-actionlint-"));
    try {
      await fs.mkdir(path.join(tempDir, ".github", "workflows"), { recursive: true });
      await fs.writeFile(
        path.join(tempDir, ".github", "workflows", "ci.yml"),
        "jobs:\n  ci:\n    steps:\n      - uses: actions/checkout@v4\n",
      );
      await fs.writeFile(
        path.join(tempDir, "package.json"),
        JSON.stringify({ name: "demo", dependencies: { zod: "4.6.0" } }),
      );

      const { ctx, getStderr } = createTestContext({
        cwd: tempDir,
        runner: {
          commandExists: async (cmd) => cmd !== "actionlint",
          exec: async (cmd, args) => {
            if (cmd === "git" && args.includes("HEAD")) {
              return { exitCode: 0, stdout: "main\n", stderr: "" };
            }
            if (cmd === "git" && args.includes("@{u}")) {
              return { exitCode: 1, stdout: "", stderr: "" };
            }
            if (cmd === "vpx" && args.includes("--jsonUpgraded")) {
              return { exitCode: 0, stdout: "{}\n", stderr: "" };
            }
            if (cmd === "yq") {
              return {
                exitCode: 0,
                stdout: JSON.stringify([{ uses: "actions/checkout@v4", line: 4 }]),
                stderr: "",
              };
            }
            if (cmd === "git" && args.includes("ls-remote")) {
              return { exitCode: 0, stdout: "sha\trefs/tags/v4.2.1\n", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(upCommand.execute([], ctx)).resolves.toBe(1);
      expect(getStderr()).toContain("actionlint is not installed");
      expect(getStderr()).toContain("Pre-checks failed at step 'actionlint pre-check'");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
