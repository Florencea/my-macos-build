import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vite-plus/test";
import { EBK_BACKUP_RULES, ebkCommand } from "../../cli/src/commands/ebk.ts";
import { createTestContext } from "./test-helpers.ts";

describe("ebk command", () => {
  it("prints help on --help and exits 0 when Downloads directory is absent", async () => {
    const helpRun = createTestContext();
    await expect(ebkCommand.execute(["--help"], helpRun.ctx)).resolves.toBe(0);
    expect(helpRun.getStdout()).toContain("ebk:");
    expect(helpRun.getStdout()).toContain("--dry-run");

    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-ebk-empty-"));
    try {
      const missingRun = createTestContext({
        env: { HOME: tempDir },
        repoRoot: tempDir,
        runner: { commandExists: async () => true },
      });
      await expect(ebkCommand.execute([], missingRun.ctx)).resolves.toBe(0);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("declares all 6 browser extension backup rules", () => {
    expect(EBK_BACKUP_RULES).toHaveLength(6);
    expect(EBK_BACKUP_RULES.map((rule) => rule.targetName)).toEqual([
      "ubo-config.txt",
      "ubol-config.json",
      "immersive-translate-config.json",
      "tampermonkey.json",
      "tongwentang.json",
      "stylus.json",
    ]);
  });

  it("formats JSON natively, deduplicates Downloads, and commits/pushes changes", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-ebk-ok-"));
    try {
      const downloadsDir = path.join(tempDir, "Downloads");
      const configsDir = path.join(tempDir, "configs");
      await fs.mkdir(downloadsDir, { recursive: true });
      await fs.mkdir(configsDir, { recursive: true });

      // Older and newer uBO plain-text backups
      const uboOld = path.join(downloadsDir, "my-ublock-backup_old.txt");
      const uboNew = path.join(downloadsDir, "my-ublock-backup_new.txt");
      await fs.writeFile(uboOld, "old-ubo\n");
      await fs.writeFile(uboNew, "new-ubo\n");
      await fs.utimes(uboOld, new Date("2026-01-01T00:00:00Z"), new Date("2026-01-01T00:00:00Z"));
      await fs.utimes(uboNew, new Date("2026-01-02T00:00:00Z"), new Date("2026-01-02T00:00:00Z"));

      // Newer minified JSON + older duplicate for uBOL and invalid JSON fallback for stylus
      const ubolOld = path.join(downloadsDir, "my-ubol-settings-1.json");
      const ubolNew = path.join(downloadsDir, "my-ubol-settings-2.json");
      await fs.writeFile(ubolOld, '{"version":"1"}');
      await fs.writeFile(ubolNew, '{"version":"2","rules":[1,2]}');
      await fs.utimes(ubolOld, new Date("2026-01-01T00:00:00Z"), new Date("2026-01-01T00:00:00Z"));
      await fs.utimes(ubolNew, new Date("2026-01-02T00:00:00Z"), new Date("2026-01-02T00:00:00Z"));

      const stylusFile = path.join(downloadsDir, "stylus-2026.json");
      await fs.writeFile(stylusFile, "not-json-fallback");

      const gitCalls: Array<readonly string[]> = [];
      const { ctx, getStdout, getStderr } = createTestContext({
        env: { HOME: tempDir },
        repoRoot: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (_command, args) => {
            gitCalls.push(args);
            if (args.includes("status")) {
              if (args.includes("stylus.json")) {
                return { exitCode: 0, stdout: "", stderr: "" };
              }
              return { exitCode: 0, stdout: "M  file", stderr: "" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      const code = await ebkCommand.execute([], ctx);
      expect(code).toBe(0);
      expect(getStderr()).toContain("stylus-2026.json is not valid JSON");

      expect(await fs.readFile(path.join(configsDir, "ubo-config.txt"), "utf8")).toBe("new-ubo\n");
      expect(await fs.readFile(path.join(configsDir, "ubol-config.json"), "utf8")).toBe(
        '{\n  "version": "2",\n  "rules": [\n    1,\n    2\n  ]\n}\n',
      );
      expect(await fs.readFile(path.join(configsDir, "stylus.json"), "utf8")).toBe(
        "not-json-fallback",
      );

      const remainingDownloads = await fs.readdir(downloadsDir);
      expect(remainingDownloads).toEqual([]);

      const out = getStdout();
      expect(out).toContain("Backup ubo-config.txt ok");
      expect(out).toContain("Backup ubol-config.json ok");
      expect(out).toContain("Backup stylus.json ok (unchanged)");
      expect(gitCalls.some((args) => args.includes("push"))).toBe(true);
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("supports --dry-run without modifying files or running git commands", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-ebk-dry-"));
    try {
      const downloadsDir = path.join(tempDir, "Downloads");
      await fs.mkdir(downloadsDir, { recursive: true });
      const backupFile = path.join(downloadsDir, "tongwentang-backup.json");
      await fs.writeFile(backupFile, '{"a":1}');

      let gitInvoked = false;
      const { ctx, getStdout } = createTestContext({
        env: { HOME: tempDir },
        repoRoot: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async () => {
            gitInvoked = true;
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(ebkCommand.execute(["--dry-run"], ctx)).resolves.toBe(0);
      expect(gitInvoked).toBe(false);
      expect(getStdout()).toContain("[dry-run] Backup");
      expect(getStdout()).toContain("tongwentang.json");
      await expect(fs.stat(backupFile)).resolves.toBeDefined();
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it("returns exit code 1 when git commit or push fails", async () => {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mmb-ebk-fail-"));
    try {
      const downloadsDir = path.join(tempDir, "Downloads");
      await fs.mkdir(downloadsDir, { recursive: true });
      await fs.writeFile(path.join(downloadsDir, "tampermonkey-backup-1.zip"), "raw");

      const { ctx, getStderr } = createTestContext({
        env: { HOME: tempDir },
        repoRoot: tempDir,
        runner: {
          commandExists: async () => true,
          exec: async (_command, args) => {
            if (args.includes("status")) {
              return { exitCode: 0, stdout: "M tampermonkey.json", stderr: "" };
            }
            if (args.includes("commit")) {
              return { exitCode: 1, stdout: "", stderr: "hook rejected" };
            }
            return { exitCode: 0, stdout: "", stderr: "" };
          },
        },
      });

      await expect(ebkCommand.execute([], ctx)).resolves.toBe(1);
      expect(getStderr()).toContain("git commit failed for tampermonkey.json");
    } finally {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });
});
