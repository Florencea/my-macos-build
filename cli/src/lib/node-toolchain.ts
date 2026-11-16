import fs from "node:fs/promises";
import path from "node:path";

import { z } from "zod";

import { ExecutionError, formatNativeErrorDetail, type CommandContext } from "./context.ts";
import { isDirectory, isFile, pathExists } from "./fs-utils.ts";
import { buildSpawnEnv, resolveExecutableInPath } from "./process.ts";

const LOCKFILE_NAMES = [
  "pnpm-lock.yaml",
  "package-lock.json",
  "npm-shrinkwrap.json",
  "yarn.lock",
  "bun.lock",
  "bun.lockb",
] as const;

const FULL_PLAYWRIGHT_PACKAGES = new Set([
  "playwright",
  "@playwright/test",
  "@vitest/browser-playwright",
]);

const PLAYWRIGHT_BIN_NAMES = ["playwright", "playwright.cmd", "playwright.ps1"] as const;
const PLAYWRIGHT_CORE_BIN_NAMES = [
  "playwright-core",
  "playwright-core.cmd",
  "playwright-core.ps1",
] as const;

const WIN_PATH_SEPARATOR_MARKER = "---VP-WIN-PATH-SEP---";
const NODE_MODULES_BIN_RE = /(?:^|[\\/])node_modules[\\/]\.bin(?:[\\/]?)$/i;

export const StringMapSchema = z.record(z.string(), z.string());

const PackageJsonSchema = z.looseObject({
  name: z.string().optional(),
  packageManager: z.string().optional(),
  engines: z.looseObject({ node: z.string().optional() }).optional(),
  scripts: StringMapSchema.optional(),
  dependencies: StringMapSchema.optional(),
  devDependencies: StringMapSchema.optional(),
  optionalDependencies: StringMapSchema.optional(),
  peerDependencies: StringMapSchema.optional(),
});

export type PackageJsonManifest = z.infer<typeof PackageJsonSchema>;

const PnpmRemoteEntrySchema = z.object({
  version: z.string().optional(),
  latest: z.boolean().optional(),
  installed: z.boolean().optional(),
});

const PnpmRemoteJsonSchema = z.object({
  package_managers: z.object({
    pnpm: z.array(z.unknown()),
  }),
});

const ToolchainGraphSchema = z.object({
  nodes: z.array(
    z.object({
      id: z.string(),
      version: z.string().optional(),
    }),
  ),
});

const GlobalPackageListSchema = z.array(
  z.object({
    name: z.string(),
    version: z.string().optional(),
  }),
);

export interface WorkspaceProjectEntry {
  readonly name: string;
  readonly dir: string;
}

export interface PlaywrightSyncStep {
  readonly exe: string;
  readonly args: readonly string[];
  readonly stepLabel: string;
}

export interface ProjectVerifyStep {
  readonly exe: string;
  readonly args: readonly string[];
  readonly message: string;
  readonly stepLabel: string;
}

export interface LatestPnpmVersion {
  readonly version: string;
  readonly installed: boolean;
}

export interface PnpmPackageManagerSpec {
  readonly isPnpm: boolean;
  readonly isOther: boolean;
  readonly raw: string;
  readonly version: string;
}

/**
 * Discovers sorted direct subdirectories under `projectsDir` that satisfy `predicate`.
 */
export async function discoverWorkspaceProjects(
  fsPort: CommandContext["fs"],
  projectsDir: string,
  predicate: (dir: string) => Promise<boolean>,
): Promise<readonly WorkspaceProjectEntry[]> {
  const entries = await fsPort.readdir(projectsDir, { withFileTypes: true });
  const dirs = entries
    .filter((entry) => entry.isDirectory())
    .toSorted((a, b) => a.name.localeCompare(b.name));

  const checks = await Promise.all(
    dirs.map(async (entry) => {
      const dir = path.join(projectsDir, entry.name);
      return (await predicate(dir)) ? { name: entry.name, dir } : undefined;
    }),
  );

  return checks.filter((item): item is WorkspaceProjectEntry => item !== undefined);
}

/**
 * Resolves the global `vp` executable path, bypassing local `node_modules/.bin` shims injected by `vpx`.
 */
export async function resolveGlobalVpExecutable(
  ctx: Pick<CommandContext, "env" | "platform">,
): Promise<string> {
  const pathSep = ctx.platform === "win32" ? ";" : ":";
  const rawPath = ctx.env["PATH"] ?? ctx.env["Path"] ?? "";
  if (rawPath !== "") {
    const filteredPath = rawPath
      .split(pathSep)
      .filter((segment) => segment.trim() !== "" && !NODE_MODULES_BIN_RE.test(segment.trim()))
      .join(pathSep);
    if (filteredPath !== "") {
      const resolved = await resolveExecutableInPath(
        "vp",
        { ...ctx.env, PATH: filteredPath },
        ctx.platform,
      );
      if (resolved !== null) {
        return resolved;
      }
    }
  }

  const envVpHome = ctx.env["VP_HOME"]?.trim();
  if (envVpHome !== undefined && envVpHome !== "") {
    const exeName = ctx.platform === "win32" ? "vp.exe" : "vp";
    const resolved = await resolveExecutableInPath(
      path.join(envVpHome, "bin", exeName),
      ctx.env,
      ctx.platform,
    );
    if (resolved !== null) {
      return resolved;
    }
  }

  return "vp";
}

/**
 * Resolves the active Node.js version via `vp node -v` with `node -v` fallback.
 */
export async function resolveActiveNodeVersion(
  ctx: Pick<CommandContext, "runner" | "env" | "platform">,
): Promise<string> {
  const vpExe = await resolveGlobalVpExecutable(ctx);
  const vpNodeRes = await ctx.runner.exec(vpExe, ["node", "-v"], {
    env: { VP_LOG: "error" },
  });
  if (vpNodeRes.exitCode === 0 && vpNodeRes.stdout.trim() !== "") {
    return vpNodeRes.stdout.trim();
  }
  const nodeRes = await ctx.runner.exec("node", ["-v"]);
  return nodeRes.exitCode === 0 ? nodeRes.stdout.trim() : "";
}

/**
 * Reads the global `vp` CLI version via `vp --version`.
 */
export async function getGlobalVitePlusVersion(
  ctx: Pick<CommandContext, "runner" | "env" | "platform">,
  cwd?: string,
): Promise<string> {
  const vpExe = await resolveGlobalVpExecutable(ctx);
  const vpVerRes = await ctx.runner.exec(
    vpExe,
    ["--version"],
    cwd !== undefined ? { cwd } : undefined,
  );
  for (const line of vpVerRes.stdout.split(/\r?\n/)) {
    const match = line.match(/^vp v([^\s]+)/);
    if (match !== null && match[1] !== undefined) {
      return match[1];
    }
  }
  return "";
}

/**
 * Reads and validates a `package.json` file with Zod, returning `null` if missing or invalid.
 */
export async function readPackageJsonManifest(
  fsPort: CommandContext["fs"],
  projectDir: string,
): Promise<PackageJsonManifest | null> {
  const pkgPath = path.join(projectDir, "package.json");
  if (!(await isFile(pkgPath, fsPort))) {
    return null;
  }
  try {
    const rawText = await fsPort.readFile(pkgPath, "utf8");
    const parsedJson: unknown = JSON.parse(rawText);
    const validated = PackageJsonSchema.safeParse(parsedJson);
    return validated.success ? validated.data : null;
  } catch {
    return null;
  }
}

/**
 * Merges Windows `PATH` strings while deduplicating segments case-insensitively.
 */
export function mergeWindowsPathSegments(sources: readonly (string | undefined)[]): string {
  const seen = new Set<string>();
  const entries: string[] = [];

  for (const raw of sources) {
    if (raw === undefined || raw.trim() === "") {
      continue;
    }
    for (const segment of raw.split(";")) {
      const trimmed = segment.trim();
      if (trimmed === "") {
        continue;
      }
      const key = trimmed.toLowerCase();
      if (!seen.has(key)) {
        seen.add(key);
        entries.push(trimmed);
      }
    }
  }

  return entries.join(";");
}

/**
 * Returns a `CommandContext` enriched with User and Machine Windows `PATH` entries when running on `win32`.
 */
export async function withWindowsMachinePath(ctx: CommandContext): Promise<CommandContext> {
  if (ctx.platform !== "win32") {
    return ctx;
  }

  const currentPath = ctx.env["PATH"] ?? ctx.env["Path"] ?? "";
  let userPath = "";
  let machinePath = "";

  const psScript = [
    "$u = [Environment]::GetEnvironmentVariable('Path', 'User')",
    "$m = [Environment]::GetEnvironmentVariable('Path', 'Machine')",
    "Write-Output $u",
    `Write-Output '${WIN_PATH_SEPARATOR_MARKER}'`,
    "Write-Output $m",
  ].join("; ");

  const queryShell = async (shellExe: string): Promise<boolean> => {
    try {
      const res = await ctx.runner.exec(shellExe, ["-NoLogo", "-NoProfile", "-Command", psScript]);
      if (res.exitCode !== 0 || !res.stdout.includes(WIN_PATH_SEPARATOR_MARKER)) {
        return false;
      }
      const parts = res.stdout.split(WIN_PATH_SEPARATOR_MARKER);
      userPath = (parts[0] ?? "").trim();
      machinePath = (parts[1] ?? "").trim();
      return true;
    } catch {
      return false;
    }
  };

  if (!(await queryShell("powershell"))) {
    await queryShell("pwsh");
  }

  const mergedPath = mergeWindowsPathSegments([currentPath, userPath, machinePath]);
  if (mergedPath === "" || mergedPath === currentPath) {
    return ctx;
  }

  const mergedEnv: Record<string, string | undefined> = buildSpawnEnv(
    ctx.env,
    { PATH: mergedPath },
    ctx.platform,
  );

  return {
    ...ctx,
    env: mergedEnv,
    runner: {
      async commandExists(name, cmdOptions) {
        if (await ctx.runner.commandExists(name, cmdOptions)) {
          return true;
        }
        return (
          (await resolveExecutableInPath(
            name,
            cmdOptions?.env ?? mergedEnv,
            cmdOptions?.platform ?? ctx.platform,
          )) !== null
        );
      },
      exec(command, args, options) {
        return ctx.runner.exec(command, args, {
          ...options,
          env: buildSpawnEnv({ PATH: mergedPath }, options?.env, ctx.platform),
        });
      },
      pipe(left, right, options) {
        return ctx.runner.pipe(left, right, {
          ...options,
          env: buildSpawnEnv({ PATH: mergedPath }, options?.env, ctx.platform),
        });
      },
      spawnInteractive(command, args, options) {
        return ctx.runner.spawnInteractive(command, args, {
          ...options,
          env: buildSpawnEnv({ PATH: mergedPath }, options?.env, ctx.platform),
        });
      },
      cleanupActiveProcesses() {
        ctx.runner.cleanupActiveProcesses();
      },
    },
  };
}

/**
 * Resolves the Playwright browser installation step for a Node.js project, or `null` if unused.
 */
export async function resolvePlaywrightSyncStep(
  pkgJson: PackageJsonManifest,
  projectRoot = ".",
  fsPort: CommandContext["fs"] = fs,
): Promise<PlaywrightSyncStep | null> {
  const scriptsMap = pkgJson.scripts ?? {};
  const depSections = [
    pkgJson.dependencies ?? {},
    pkgJson.devDependencies ?? {},
    pkgJson.optionalDependencies ?? {},
    pkgJson.peerDependencies ?? {},
  ];

  let hasFullPlaywrightDep = false;
  let hasCoreOnlyDep = false;

  for (const section of depSections) {
    for (const pkgName of Object.keys(section)) {
      if (FULL_PLAYWRIGHT_PACKAGES.has(pkgName)) {
        hasFullPlaywrightDep = true;
      } else if (pkgName === "playwright-core") {
        hasCoreOnlyDep = true;
      }
    }
  }

  const binDir = path.join(projectRoot, "node_modules", ".bin");
  const fullBinChecks = await Promise.all(
    PLAYWRIGHT_BIN_NAMES.map((binName) => isFile(path.join(binDir, binName), fsPort)),
  );
  const hasPlaywrightBin = fullBinChecks.includes(true);

  const coreBinChecks = await Promise.all(
    PLAYWRIGHT_CORE_BIN_NAMES.map((binName) => isFile(path.join(binDir, binName), fsPort)),
  );
  const hasCoreBin = coreBinChecks.includes(true);

  const hasAnyPlaywright = hasFullPlaywrightDep || hasCoreOnlyDep || hasPlaywrightBin || hasCoreBin;

  const setupCmd = scriptsMap["test:setup"];
  if (setupCmd !== undefined) {
    if (hasAnyPlaywright || /\bplaywright\b/.test(setupCmd)) {
      return {
        exe: "vpr",
        args: ["--no-cache", "test:setup"],
        stepLabel: "vpr --no-cache test:setup",
      };
    }
  }

  if (hasFullPlaywrightDep || hasPlaywrightBin) {
    return {
      exe: "vp",
      args: ["exec", "playwright", "install", "chromium", "--no-progress"],
      stepLabel: "vp exec playwright install chromium",
    };
  }

  if (hasCoreOnlyDep || hasCoreBin) {
    return {
      exe: "vp",
      args: ["exec", "playwright-core", "install", "chromium", "--no-progress"],
      stepLabel: "vp exec playwright-core install chromium",
    };
  }

  return null;
}

/**
 * Resolves the verification pipeline (`agent:verify:gate` or unit -> build -> e2e fallback) from `scripts`.
 */
export function resolveProjectVerifySteps(
  scriptsMap: Readonly<Record<string, string>>,
): readonly ProjectVerifyStep[] {
  if (scriptsMap["agent:verify:gate"] !== undefined) {
    return [
      {
        exe: "vpr",
        args: ["agent:verify:gate"],
        message: "Verifying gate (unit, build, e2e)",
        stepLabel: "vpr agent:verify:gate (gate)",
      },
    ];
  }

  const steps: ProjectVerifyStep[] = [];
  for (const candidate of ["agent:verify:unit", "agent:test:unit", "test:unit"]) {
    if (scriptsMap[candidate] !== undefined) {
      steps.push({
        exe: "vpr",
        args: [candidate],
        message: "Verifying unit tests",
        stepLabel: `vpr ${candidate} (unit-test)`,
      });
      break;
    }
  }

  let e2eScript = "";
  for (const candidate of ["agent:test:e2e", "test:e2e"]) {
    if (scriptsMap[candidate] !== undefined) {
      e2eScript = candidate;
      break;
    }
  }

  if (e2eScript !== "") {
    for (const buildCandidate of ["build:all", "build"]) {
      if (scriptsMap[buildCandidate] !== undefined) {
        steps.push({
          exe: "vpr",
          args: [buildCandidate],
          message: "Building project for E2E",
          stepLabel: `vpr ${buildCandidate} (build)`,
        });
        break;
      }
    }

    steps.push({
      exe: "vpr",
      args: [e2eScript],
      message: "Verifying E2E tests",
      stepLabel: `vpr ${e2eScript} (e2e-test)`,
    });
  }

  return steps;
}

/**
 * Determines whether a pulled workspace repository requires `vp install --frozen-lockfile`.
 */
export async function isWorkspaceNodeSyncTarget(
  fsPort: CommandContext["fs"],
  repoPath: string,
  pullUpdated = false,
): Promise<boolean> {
  if (!(await isFile(path.join(repoPath, "package.json"), fsPort))) {
    return false;
  }

  const lockChecks = await Promise.all(
    LOCKFILE_NAMES.map((lockfile) => isFile(path.join(repoPath, lockfile), fsPort)),
  );
  if (!lockChecks.includes(true)) {
    return false;
  }

  const hasNodeModules = await isDirectory(path.join(repoPath, "node_modules"), fsPort);
  return pullUpdated || !hasNodeModules;
}

/**
 * Extracts the latest `pnpm` version entry from `vp env list-remote --json --sort desc pnpm`.
 */
export function resolveLatestPnpmVersionFromJson(
  jsonText: string | null | undefined,
): LatestPnpmVersion | null {
  if (jsonText === null || jsonText === undefined || jsonText.trim() === "") {
    return null;
  }

  let parsedJson: unknown;
  try {
    parsedJson = JSON.parse(jsonText);
  } catch {
    return null;
  }

  const validated = PnpmRemoteJsonSchema.safeParse(parsedJson);
  if (!validated.success) {
    return null;
  }

  const entries: LatestPnpmVersion[] = [];
  let latestEntry: LatestPnpmVersion | null = null;

  for (const rawEntry of validated.data.package_managers.pnpm) {
    const parsedEntry = PnpmRemoteEntrySchema.safeParse(rawEntry);
    if (!parsedEntry.success) {
      continue;
    }
    const ver = parsedEntry.data.version?.trim() ?? "";
    if (ver === "") {
      continue;
    }
    const candidate: LatestPnpmVersion = {
      version: ver,
      installed: parsedEntry.data.installed ?? false,
    };
    if (parsedEntry.data.latest === true && latestEntry === null) {
      latestEntry = candidate;
    }
    entries.push(candidate);
  }

  return latestEntry ?? entries[0] ?? null;
}

/**
 * Parses a `package.json` `packageManager` field and identifies whether it pins `pnpm`.
 */
export function parsePnpmPackageManagerSpec(
  packageManagerField: string | null | undefined,
): PnpmPackageManagerSpec {
  if (
    packageManagerField === null ||
    packageManagerField === undefined ||
    packageManagerField.trim() === ""
  ) {
    return {
      isPnpm: false,
      isOther: false,
      raw: "",
      version: "",
    };
  }

  const trimmed = packageManagerField.trim();
  const match = trimmed.match(/^pnpm@([^\s+]+)(?:\+.*)?$/);
  if (match !== null && match[1] !== undefined) {
    return {
      isPnpm: true,
      isOther: false,
      raw: trimmed,
      version: match[1],
    };
  }

  return {
    isPnpm: false,
    isOther: true,
    raw: trimmed,
    version: "",
  };
}

/**
 * Checks whether a directory is a Git-backed Node.js project managed by `pnpm`.
 */
export async function isPnpmWorkspaceProject(
  fsPort: CommandContext["fs"],
  repoPath: string,
): Promise<boolean> {
  if (!(await pathExists(path.join(repoPath, ".git"), fsPort))) {
    return false;
  }

  const pkg = await readPackageJsonManifest(fsPort, repoPath);
  if (pkg === null) {
    return false;
  }

  const pmSpec = parsePnpmPackageManagerSpec(pkg.packageManager);
  if (pmSpec.isOther) {
    return false;
  }
  if (pmSpec.isPnpm) {
    return true;
  }

  const [hasLock, hasWorkspace] = await Promise.all([
    isFile(path.join(repoPath, "pnpm-lock.yaml"), fsPort),
    isFile(path.join(repoPath, "pnpm-workspace.yaml"), fsPort),
  ]);
  return hasLock || hasWorkspace;
}

/**
 * Formats `package.json` inside `projectDir` via `vp fmt` while capturing native error output.
 */
export async function formatProjectPackageManifest(
  ctx: Pick<CommandContext, "runner" | "fs">,
  projectDir: string,
): Promise<{ readonly success: boolean; readonly errorDetail: string }> {
  const manifestPath = path.join(projectDir, "package.json");
  if (!(await isFile(manifestPath, ctx.fs))) {
    return {
      success: false,
      errorDetail: `package.json not found in ${projectDir}`,
    };
  }

  const fmtRes = await ctx.runner.exec("vp", [
    "-C",
    projectDir,
    "fmt",
    "--no-error-on-unmatched-pattern",
    "package.json",
  ]);
  if (fmtRes.exitCode !== 0) {
    return {
      success: false,
      errorDetail: formatNativeErrorDetail([fmtRes.stderr, fmtRes.stdout], fmtRes.exitCode),
    };
  }

  return {
    success: true,
    errorDetail: "",
  };
}

/**
 * Aligns the global `oxfmt` package to the version required by the active `vite-plus` toolchain.
 */
export async function syncGlobalOxfmt(ctx: CommandContext): Promise<void> {
  const vpExe = await resolveGlobalVpExecutable(ctx);
  if (!(await ctx.runner.commandExists(vpExe))) {
    return;
  }

  let targetVer = "";
  const toolchainRes = await ctx.runner.exec(vpExe, ["toolchain", "--global", "--json", "oxfmt"]);
  if (toolchainRes.exitCode === 0 && toolchainRes.stdout.trim() !== "") {
    try {
      const parsedJson: unknown = JSON.parse(toolchainRes.stdout);
      const validated = ToolchainGraphSchema.safeParse(parsedJson);
      if (validated.success) {
        targetVer = validated.data.nodes.find((node) => node.id === "oxfmt")?.version?.trim() ?? "";
      }
    } catch {
      targetVer = "";
    }
  }

  if (targetVer === "") {
    ctx.stderr(
      "Warning: Unable to determine bundled oxfmt version from global vite-plus toolchain.\n",
    );
    return;
  }

  let currentVer = "";
  const listRes = await ctx.runner.exec(vpExe, ["list", "-g", "--json"]);
  if (listRes.exitCode === 0 && listRes.stdout.trim() !== "") {
    try {
      const parsedJson: unknown = JSON.parse(listRes.stdout);
      const validated = GlobalPackageListSchema.safeParse(parsedJson);
      if (validated.success) {
        currentVer = validated.data.find((pkg) => pkg.name === "oxfmt")?.version?.trim() ?? "";
      }
    } catch {
      currentVer = "";
    }
  }

  if (currentVer !== targetVer) {
    if (ctx.dryRun) {
      ctx.stdout(`[dry-run] vp install -g oxfmt@${targetVer}\n`);
      return;
    }

    const installRes = await ctx.runner.exec(vpExe, ["install", "-g", `oxfmt@${targetVer}`]);
    if (installRes.exitCode !== 0) {
      const detail = formatNativeErrorDetail(
        [installRes.stderr, installRes.stdout],
        installRes.exitCode,
      );
      ctx.stderr(`${detail}\n`);
      throw new ExecutionError(`Failed to align global oxfmt to ${targetVer}`, installRes.exitCode);
    }

    if (currentVer !== "") {
      ctx.stdout(`oxfmt: ${currentVer} -> ${targetVer}\n`);
    } else {
      ctx.stdout(`oxfmt: ${targetVer}\n`);
    }
  }
}
