import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { z } from "zod";
import { ExecutionError, formatNativeErrorDetail, type CommandContext } from "./context.ts";
import { resolveExecutableInPath } from "./process.ts";

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

export const StringMapSchema = z.record(z.string(), z.string());

export const PackageJsonSchema = z.looseObject({
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

const VitePlusPkgJsonSchema = z.object({
  dependencies: StringMapSchema.optional(),
});

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

export interface VitePlusOxfmtSpec {
  readonly vpHome: string;
  readonly oxfmtVersion: string;
}

async function isFile(fsPort: CommandContext["fs"], filePath: string): Promise<boolean> {
  try {
    const stats = await fsPort.stat(filePath);
    return stats.isFile();
  } catch {
    return false;
  }
}

async function isDirectory(fsPort: CommandContext["fs"], dirPath: string): Promise<boolean> {
  try {
    const stats = await fsPort.stat(dirPath);
    return stats.isDirectory();
  } catch {
    return false;
  }
}

async function pathExists(fsPort: CommandContext["fs"], targetPath: string): Promise<boolean> {
  try {
    await fsPort.stat(targetPath);
    return true;
  } catch {
    return false;
  }
}

/**
 * Reads and validates a `package.json` file with Zod, returning `null` if missing or invalid.
 */
export async function readPackageJsonManifest(
  fsPort: CommandContext["fs"],
  projectDir: string,
): Promise<PackageJsonManifest | null> {
  const pkgPath = path.join(projectDir, "package.json");
  if (!(await isFile(fsPort, pkgPath))) {
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
    `Write-Output "$u\n${WIN_PATH_SEPARATOR_MARKER}\n$m"`,
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

  const mergedEnv: Record<string, string | undefined> = {
    ...ctx.env,
    PATH: mergedPath,
  };

  return {
    ...ctx,
    env: mergedEnv,
    runner: {
      async commandExists(name: string): Promise<boolean> {
        if (await ctx.runner.commandExists(name)) {
          return true;
        }
        return (await resolveExecutableInPath(name, mergedEnv, ctx.platform)) !== null;
      },
      exec(command, args, options) {
        return ctx.runner.exec(command, args, {
          ...options,
          env: { PATH: mergedPath, ...options?.env },
        });
      },
      pipe(left, right, options) {
        return ctx.runner.pipe(left, right, {
          ...options,
          env: { PATH: mergedPath, ...options?.env },
        });
      },
      spawnInteractive(command, args, options) {
        return ctx.runner.spawnInteractive(command, args, {
          ...options,
          env: { PATH: mergedPath, ...options?.env },
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
    PLAYWRIGHT_BIN_NAMES.map((binName) => isFile(fsPort, path.join(binDir, binName))),
  );
  const hasPlaywrightBin = fullBinChecks.includes(true);

  const coreBinChecks = await Promise.all(
    PLAYWRIGHT_CORE_BIN_NAMES.map((binName) => isFile(fsPort, path.join(binDir, binName))),
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
  if (!(await isFile(fsPort, path.join(repoPath, "package.json")))) {
    return false;
  }

  const lockChecks = await Promise.all(
    LOCKFILE_NAMES.map((lockfile) => isFile(fsPort, path.join(repoPath, lockfile))),
  );
  if (!lockChecks.includes(true)) {
    return false;
  }

  const hasNodeModules = await isDirectory(fsPort, path.join(repoPath, "node_modules"));
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
  if (!(await pathExists(fsPort, path.join(repoPath, ".git")))) {
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
    isFile(fsPort, path.join(repoPath, "pnpm-lock.yaml")),
    isFile(fsPort, path.join(repoPath, "pnpm-workspace.yaml")),
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
  if (!(await isFile(ctx.fs, manifestPath))) {
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
 * Resolves the bundled `oxfmt` version and `VP_HOME` directory from a Vite+ installation.
 */
export async function getVitePlusOxfmtSpec(
  ctx: Pick<CommandContext, "fs" | "env" | "platform">,
  options?: {
    readonly vpCommandPath?: string;
    readonly vpVersion?: string;
    readonly fallbackRoots?: readonly string[];
    readonly homeDir?: string;
  },
): Promise<VitePlusOxfmtSpec | null> {
  const homeDir = options?.homeDir ?? ctx.env["HOME"] ?? ctx.env["USERPROFILE"] ?? os.homedir();
  const candidateRoots: string[] = [];

  const envVpHome = ctx.env["VP_HOME"]?.trim();
  if (envVpHome !== undefined && envVpHome !== "") {
    candidateRoots.push(envVpHome);
  }

  const vpCommandPath = options?.vpCommandPath;
  if (vpCommandPath !== undefined && vpCommandPath.trim() !== "") {
    const binDir = path.dirname(vpCommandPath);
    const parentDir = path.dirname(binDir);
    if (parentDir !== "") {
      candidateRoots.push(parentDir);
    }
    try {
      const realPath = await ctx.fs.realpath(vpCommandPath);
      const targetParent = path.dirname(path.dirname(realPath));
      if (targetParent !== "") {
        candidateRoots.push(targetParent);
      }
    } catch {
      // Ignore unresolvable symlink during candidate discovery
    }
  }

  if (options?.fallbackRoots !== undefined) {
    for (const extraRoot of options.fallbackRoots) {
      if (extraRoot.trim() !== "") {
        candidateRoots.push(extraRoot);
      }
    }
  }

  if (ctx.platform === "win32") {
    candidateRoots.push("E:\\vite-plus");
    candidateRoots.push(path.join(homeDir, ".vite-plus"));
  } else {
    candidateRoots.push(path.join(homeDir, ".local", "share", "vite-plus"));
  }

  const seen = new Set<string>();
  const uniqueRoots: string[] = [];
  for (const root of candidateRoots) {
    const trimmedRoot = root.trim();
    const dedupKey = trimmedRoot.toLowerCase();
    if (trimmedRoot !== "" && !seen.has(dedupKey)) {
      seen.add(dedupKey);
      uniqueRoots.push(trimmedRoot);
    }
  }

  const readCandidateSpec = async (
    trimmedRoot: string,
    pkgPath: string,
    directPkgPath: string,
  ): Promise<VitePlusOxfmtSpec | null> => {
    if (!(await isFile(ctx.fs, pkgPath))) {
      return null;
    }
    try {
      const rawText = await ctx.fs.readFile(pkgPath, "utf8");
      const parsedJson: unknown = JSON.parse(rawText);
      const validated = VitePlusPkgJsonSchema.safeParse(parsedJson);
      if (!validated.success) {
        return null;
      }
      const rawOxfmt = validated.data.dependencies?.["oxfmt"];
      if (rawOxfmt === undefined) {
        return null;
      }
      const targetVer = rawOxfmt.trim().replace(/^[^0-9]*/, "");
      if (targetVer === "") {
        return null;
      }
      const vpHome = pkgPath === directPkgPath ? path.dirname(trimmedRoot) : trimmedRoot;
      return { vpHome, oxfmtVersion: targetVer };
    } catch {
      return null;
    }
  };

  const perRootSpecs = await Promise.all(
    uniqueRoots.map(async (trimmedRoot): Promise<VitePlusOxfmtSpec | null> => {
      if (!(await isDirectory(ctx.fs, trimmedRoot))) {
        return null;
      }

      const pkgCandidates = [
        path.join(trimmedRoot, "current", "node_modules", "vite-plus", "package.json"),
      ];
      if (options?.vpVersion !== undefined && options.vpVersion !== "") {
        pkgCandidates.push(
          path.join(trimmedRoot, options.vpVersion, "node_modules", "vite-plus", "package.json"),
        );
      }
      const directPkgPath = path.join(trimmedRoot, "node_modules", "vite-plus", "package.json");
      pkgCandidates.push(directPkgPath);

      const candidateSpecs = await Promise.all(
        pkgCandidates.map((pkgPath) => readCandidateSpec(trimmedRoot, pkgPath, directPkgPath)),
      );
      return candidateSpecs.find((item) => item !== null) ?? null;
    }),
  );

  return perRootSpecs.find((item) => item !== null) ?? null;
}

/**
 * Aligns the global `oxfmt` shim to the version bundled with the active `vite-plus` toolchain.
 */
export async function syncGlobalOxfmt(ctx: CommandContext): Promise<void> {
  if (!(await ctx.runner.commandExists("vp"))) {
    return;
  }

  const vpCommandPath = (await resolveExecutableInPath("vp", ctx.env, ctx.platform)) ?? undefined;

  const vpVerRes = await ctx.runner.exec("vp", ["--version"]);
  let vpVersion = "";
  for (const line of vpVerRes.stdout.split(/\r?\n/)) {
    const match = line.match(/^vp v([^\s]+)/);
    if (match !== null && match[1] !== undefined) {
      vpVersion = match[1];
      break;
    }
  }

  const spec = await getVitePlusOxfmtSpec(ctx, { vpCommandPath, vpVersion });
  if (spec === null) {
    ctx.stderr(
      "Warning: Unable to determine bundled oxfmt version from global vite-plus installation.\n",
    );
    return;
  }

  const targetVer = spec.oxfmtVersion;
  const shimName = ctx.platform === "win32" ? "oxfmt.exe" : "oxfmt";
  const shimPath = path.join(spec.vpHome, "bin", shimName);
  const shimExists = await isFile(ctx.fs, shimPath);
  let currentVer = "";

  if (shimExists) {
    const verRes = await ctx.runner.exec(shimPath, ["--version"]);
    for (const line of verRes.stdout.split(/\r?\n/)) {
      const match = line.match(/(\d+\.\d+\.\d+(?:-[^\s]+)?)/);
      if (match !== null && match[1] !== undefined) {
        currentVer = match[1];
        break;
      }
    }
  }

  if (!shimExists || currentVer !== targetVer) {
    if (ctx.dryRun) {
      ctx.stdout(`[dry-run] vp install -g oxfmt@${targetVer}\n`);
      return;
    }

    const installRes = await ctx.runner.exec("vp", ["install", "-g", `oxfmt@${targetVer}`]);
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
