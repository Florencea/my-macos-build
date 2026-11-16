import { existsSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { parseArgs } from "node:util";
import { z } from "zod";
import { createNodeCommandRunner, resolveExecutableInPath } from "../cli/src/lib/process.ts";

const VerifyShellArgsSchema = z.object({
  fix: z.boolean(),
  help: z.boolean(),
});

async function listFilesInDir(dirPath: string): Promise<string[]> {
  if (!existsSync(dirPath)) {
    return [];
  }
  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(dirPath, entry.name))
    .toSorted();
}

export async function runShellVerification(
  repoRoot: string,
  fixMode: boolean,
): Promise<{ readonly totalFiles: number; readonly failures: readonly string[] }> {
  const runner = createNodeCommandRunner();
  const failures: string[] = [];

  const completionFiles = await listFilesInDir(
    path.join(repoRoot, "configs", "zsh", "completions"),
  );
  const zshFiles = [
    path.join(repoRoot, "scripts", "install.sh"),
    path.join(repoRoot, "configs", "zsh", "zshenv"),
    path.join(repoRoot, "configs", "zsh", "zprofile"),
    path.join(repoRoot, "configs", "zsh", "zshrc"),
    ...completionFiles,
  ];

  const bashFiles = [
    path.join(repoRoot, "configs", "bash", "bash_profile"),
    path.join(repoRoot, "configs", "bash", "bashrc"),
    path.join(repoRoot, "configs", "git", "hooks", "pre-commit.sh"),
  ];

  const binEntries = await listFilesInDir(path.join(repoRoot, "cli", "bin"));
  const posixBinShims = binEntries.filter((filePath) => !filePath.endsWith(".cmd"));

  const [hasZsh, hasBash, hasSh, hasShfmt] = await Promise.all([
    resolveExecutableInPath("zsh", process.env, process.platform),
    resolveExecutableInPath("bash", process.env, process.platform),
    resolveExecutableInPath("sh", process.env, process.platform),
    resolveExecutableInPath("shfmt", process.env, process.platform),
  ]);

  async function checkShellSyntax(shellBin: string, file: string): Promise<void> {
    const res = await runner.exec(shellBin, ["-n", file]);
    if (res.exitCode !== 0) {
      failures.push(`${shellBin} -n failed for ${file}: ${res.stderr.trim()}`);
    }
  }

  const syntaxChecks: Promise<void>[] = [];
  if (hasZsh !== null) {
    for (const file of zshFiles) {
      syntaxChecks.push(checkShellSyntax("zsh", file));
    }
  }

  if (hasBash !== null) {
    for (const file of bashFiles) {
      syntaxChecks.push(checkShellSyntax("bash", file));
    }
  }

  if (hasSh !== null) {
    for (const file of posixBinShims) {
      syntaxChecks.push(checkShellSyntax("sh", file));
    }
  }
  await Promise.all(syntaxChecks);

  const allShellFiles = [...zshFiles, ...bashFiles, ...posixBinShims];
  if (allShellFiles.length > 0 && hasShfmt !== null) {
    const shfmtFlag = fixMode ? "-w" : "-d";
    const res = await runner.exec("shfmt", ["-i", "2", "-ci", shfmtFlag, ...allShellFiles]);
    if (res.exitCode !== 0) {
      const detail = res.stderr.trim() !== "" ? res.stderr.trim() : res.stdout.trim();
      failures.push(`shfmt check failed${detail !== "" ? `: ${detail}` : ""}`);
    }
  }

  return { totalFiles: allShellFiles.length, failures };
}

const isEntryPoint =
  process.argv[1] !== undefined && import.meta.filename === path.resolve(process.argv[1]);
if (isEntryPoint) {
  let fixMode = false;
  let showHelp = false;

  try {
    const parsed = parseArgs({
      args: process.argv.slice(2),
      options: {
        fix: { type: "boolean", default: false },
        help: { type: "boolean", short: "h", default: false },
      },
      strict: true,
      allowPositionals: false,
    });
    const validated = VerifyShellArgsSchema.safeParse(parsed.values);
    if (!validated.success) {
      throw new Error(validated.error.issues.map((i) => i.message).join("; "));
    }
    fixMode = validated.data.fix;
    showHelp = validated.data.help;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    process.stderr.write(`Error: ${msg}\n`);
    process.exitCode = 1;
  }

  if (process.exitCode === undefined) {
    if (showHelp) {
      process.stdout.write("Usage: vpx tests/verify-shell.ts [--fix]\n");
    } else {
      const repoRoot = path.resolve(import.meta.dirname, "..");
      const result = await runShellVerification(repoRoot, fixMode);
      if (result.failures.length > 0) {
        process.stderr.write(
          `Shell verification failed with ${result.failures.length.toString()} issue(s):\n`,
        );
        for (const item of result.failures) {
          process.stderr.write(`  - ${item}\n`);
        }
        process.exitCode = 1;
      } else {
        process.stdout.write(
          `Shell verification passed (${result.totalFiles.toString()} file(s)).\n`,
        );
      }
    }
  }
}
