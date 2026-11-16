import os from "node:os";
import path from "node:path";

import { z } from "zod";

import { defineCommand } from "../lib/cli-framework.ts";
import { ErrnoCodeSchema, formatNativeErrorDetail, type CommandContext } from "../lib/context.ts";
import { isDirectory } from "../lib/fs-utils.ts";
import { runSequentially } from "../lib/process.ts";

const JsonValueSchema = z.json();

interface BackupRule {
  readonly pattern: RegExp;
  readonly targetName: string;
  readonly formatJson: boolean;
}

export const EBK_BACKUP_RULES: readonly BackupRule[] = [
  { pattern: /^my-ublock-backup.*\.txt$/i, targetName: "ubo-config.txt", formatJson: false },
  { pattern: /^my-ubol-settings.*\.json$/i, targetName: "ubol-config.json", formatJson: true },
  {
    pattern: /^immersive-translate-config.*\.json$/i,
    targetName: "immersive-translate-config.json",
    formatJson: true,
  },
  { pattern: /^tampermonkey-backup.*\..*$/i, targetName: "tampermonkey.json", formatJson: true },
  { pattern: /^tongwentang.*\.json$/i, targetName: "tongwentang.json", formatJson: true },
  { pattern: /^stylus.*\.json$/i, targetName: "stylus.json", formatJson: true },
] as const;

interface MatchedFile {
  readonly name: string;
  readonly fullPath: string;
  readonly mtimeMs: number;
}

function resolveDownloadsDir(ctx: CommandContext): string {
  const homeDir =
    ctx.platform === "win32"
      ? (ctx.env["USERPROFILE"] ?? ctx.env["HOME"] ?? os.homedir())
      : (ctx.env["HOME"] ?? os.homedir());
  return path.join(homeDir, "Downloads");
}

async function moveFileCrossDevice(
  fsPort: CommandContext["fs"],
  srcPath: string,
  destPath: string,
): Promise<void> {
  try {
    await fsPort.rename(srcPath, destPath);
  } catch (err) {
    const parsedErr = ErrnoCodeSchema.safeParse(err);
    if (parsedErr.success && parsedErr.data.code === "EXDEV") {
      await fsPort.copyFile(srcPath, destPath);
      await fsPort.rm(srcPath, { force: true });
      return;
    }
    throw err;
  }
}

function tryFormatJsonText(rawText: string): string | null {
  try {
    const parsed: unknown = JSON.parse(rawText);
    const validated = JsonValueSchema.safeParse(parsed);
    if (!validated.success) {
      return null;
    }
    return `${JSON.stringify(validated.data, null, 2)}\n`;
  } catch {
    return null;
  }
}

async function findMatchingFiles(
  fsPort: CommandContext["fs"],
  downloadsDir: string,
  pattern: RegExp,
): Promise<readonly MatchedFile[]> {
  const entries = await fsPort.readdir(downloadsDir, { withFileTypes: true });
  const candidates = entries.filter((entry) => entry.isFile() && pattern.test(entry.name));
  const withStats = await Promise.all(
    candidates.map(async (entry) => {
      const fullPath = path.join(downloadsDir, entry.name);
      const stat = await fsPort.stat(fullPath);
      return {
        name: entry.name,
        fullPath,
        mtimeMs: stat.mtimeMs,
      };
    }),
  );
  return withStats.toSorted((a, b) => {
    if (b.mtimeMs !== a.mtimeMs) {
      return b.mtimeMs - a.mtimeMs;
    }
    return b.name.localeCompare(a.name);
  });
}

async function commitBackupFile(
  ctx: CommandContext,
  configHome: string,
  fileName: string,
): Promise<{ readonly ok: boolean; readonly changed: boolean }> {
  const addRes = await ctx.runner.exec("git", ["-C", configHome, "add", "--", fileName]);
  if (addRes.exitCode !== 0) {
    ctx.stderr(`Error: git add failed for ${fileName}\n`);
    return { ok: false, changed: false };
  }

  const statusRes = await ctx.runner.exec("git", [
    "-C",
    configHome,
    "status",
    "--porcelain",
    "--",
    fileName,
  ]);
  if (statusRes.exitCode !== 0) {
    ctx.stderr(`Error: git status failed for ${fileName}\n`);
    return { ok: false, changed: false };
  }

  if (statusRes.stdout.trim() !== "") {
    const commitRes = await ctx.runner.exec("git", [
      "-C",
      configHome,
      "commit",
      "-q",
      "-m",
      `feat: Update ${fileName} by ebk`,
    ]);
    if (commitRes.exitCode !== 0) {
      const detail = formatNativeErrorDetail(
        [commitRes.stderr, commitRes.stdout],
        commitRes.exitCode,
      );
      ctx.stderr(`Error: git commit failed for ${fileName} (${detail})\n`);
      return { ok: false, changed: false };
    }
    ctx.stdout(`Backup ${fileName} ok\n`);
    return { ok: true, changed: true };
  }

  ctx.stdout(`Backup ${fileName} ok (unchanged)\n`);
  return { ok: true, changed: false };
}

/**
 * Backup and sync browser extension configuration files from Downloads to configs/.
 */
export const ebkCommand = defineCommand({
  name: "ebk",
  summary: "Backup and sync browser extension configuration files",
  usage: "ebk [options]",
  examples: ["ebk", "ebk --dry-run"],
  flags: {},
  positionals: { min: 0, max: 0, label: "" },
  requiredCommands: ["git"],
  supportsDryRun: true,
  async run({ ctx }) {
    const downloadsDir = resolveDownloadsDir(ctx);
    if (!(await isDirectory(downloadsDir, ctx.fs))) {
      return 0;
    }

    const configHome = path.join(ctx.repoRoot, "configs");
    const ruleMatches = await Promise.all(
      EBK_BACKUP_RULES.map(async (rule) => ({
        rule,
        matched: await findMatchingFiles(ctx.fs, downloadsDir, rule.pattern),
      })),
    );

    const activeMatches = ruleMatches.filter((entry) => entry.matched.length > 0);
    if (activeMatches.length === 0) {
      return 0;
    }

    if (ctx.dryRun) {
      for (const { rule, matched } of activeMatches) {
        const latest = matched[0];
        if (latest === undefined) {
          continue;
        }
        const destPath = path.join(configHome, rule.targetName);
        const modeNote = rule.formatJson ? " (format JSON)" : "";
        ctx.stdout(`[dry-run] Backup ${latest.fullPath} -> ${destPath}${modeNote}\n`);
        if (matched.length > 1) {
          ctx.stdout(
            `[dry-run] Remove ${String(matched.length - 1)} older duplicate(s) in ${downloadsDir}\n`,
          );
        }
        ctx.stdout(`[dry-run] git -C "${configHome}" add/commit ${rule.targetName}\n`);
      }
      ctx.stdout(`[dry-run] git -C "${configHome}" push -q\n`);
      return 0;
    }

    await ctx.fs.mkdir(configHome, { recursive: true });

    const syncedTargets = await Promise.all(
      activeMatches.map(async ({ rule, matched }) => {
        const latest = matched[0];
        if (latest === undefined) {
          return undefined;
        }
        const destPath = path.join(configHome, rule.targetName);

        if (rule.formatJson) {
          const rawText = await ctx.fs.readFile(latest.fullPath, "utf8");
          const formatted = tryFormatJsonText(rawText);
          if (formatted !== null) {
            await ctx.fs.writeFile(destPath, formatted, "utf8");
            await Promise.all(matched.map((item) => ctx.fs.rm(item.fullPath, { force: true })));
          } else {
            ctx.stderr(
              `Warning: ${latest.name} is not valid JSON; copying raw file to ${rule.targetName}\n`,
            );
            await moveFileCrossDevice(ctx.fs, latest.fullPath, destPath);
            await Promise.all(
              matched.slice(1).map((item) => ctx.fs.rm(item.fullPath, { force: true })),
            );
          }
        } else {
          await moveFileCrossDevice(ctx.fs, latest.fullPath, destPath);
          await Promise.all(
            matched.slice(1).map((item) => ctx.fs.rm(item.fullPath, { force: true })),
          );
        }
        return rule.targetName;
      }),
    );

    const targetNames = syncedTargets.filter((name): name is string => name !== undefined);
    let hasError = false;
    let needPush = false;
    await runSequentially(targetNames, async (fileName) => {
      const outcome = await commitBackupFile(ctx, configHome, fileName);
      if (!outcome.ok) {
        hasError = true;
      } else if (outcome.changed) {
        needPush = true;
      }
    });

    if (needPush) {
      const pushRes = await ctx.runner.exec("git", ["-C", configHome, "push", "-q"]);
      if (pushRes.exitCode !== 0) {
        const detail = formatNativeErrorDetail([pushRes.stderr, pushRes.stdout], pushRes.exitCode);
        ctx.stderr(`Error: git push failed (${detail})\n`);
        hasError = true;
      }
    }

    return hasError ? 1 : 0;
  },
});
