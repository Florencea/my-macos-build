import { Buffer } from "node:buffer";
import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";

import { describe, expect, it } from "vite-plus/test";
import { z } from "zod";

const REPO_ROOT = path.resolve(import.meta.dirname, "..");
const PLUGINS_ROOT = path.join(REPO_ROOT, "plugins");
const MAX_RULE_BYTES = 8192;

const AuthorObjectSchema = z.strictObject({
  name: z.string().min(1),
  email: z.string().min(1).optional(),
  url: z.string().min(1).optional(),
});

const PluginManifestSchema = z.strictObject({
  $schema: z.literal("https://antigravity.google/schemas/v1/plugin.json").optional(),
  name: z.string().regex(/^[a-z0-9-]+$/),
  displayName: z.string().min(1).optional(),
  description: z.string().min(1),
  version: z.string().min(1).optional(),
  disabled: z.boolean().optional(),
  logo: z.string().min(1).optional(),
  suggestedPrompts: z.array(z.string().regex(/\S/)).max(3).optional(),
  skills: z.union([z.string().regex(/\S/), z.array(z.string().regex(/\S/))]).optional(),
  author: z.union([z.string().min(1), AuthorObjectSchema]).optional(),
  homepage: z.string().min(1).optional(),
  repository: z.string().min(1).optional(),
  license: z.string().min(1).optional(),
  keywords: z.array(z.string().min(1)).optional(),
  extensions: z.record(z.string(), z.record(z.string(), z.unknown())).optional(),
});

const NamedRuleFrontmatterSchema = z.object({
  trigger: z.enum(["glob", "model_decision", "manual"]),
  globs: z.string().min(1).optional(),
  description: z.string().min(1),
});

const SkillFrontmatterSchema = z.object({
  name: z.string().regex(/^[a-z0-9-]+$/),
  description: z.string().min(1),
  compatibility: z.string().min(1).optional(),
});

function parseYamlFrontmatter(raw: string): Record<string, string> | null {
  const normalized = raw.replace(/\r\n/g, "\n");
  if (!normalized.startsWith("---\n")) {
    return null;
  }
  const endIndex = normalized.indexOf("\n---\n", 4);
  if (endIndex === -1) {
    return null;
  }

  const block = normalized.slice(4, endIndex);
  const record: Record<string, string> = {};
  for (const line of block.split("\n")) {
    const trimmed = line.trim();
    if (trimmed === "" || trimmed.startsWith("#")) {
      continue;
    }
    const colonIndex = trimmed.indexOf(":");
    if (colonIndex <= 0) {
      continue;
    }
    const key = trimmed.slice(0, colonIndex).trim();
    let value = trimmed.slice(colonIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    record[key] = value;
  }
  return record;
}

async function listSubdirectories(dirPath: string): Promise<string[]> {
  const entries = await readdir(dirPath, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .toSorted();
}

async function collectFiles(dirPath: string): Promise<string[]> {
  const entries = await readdir(dirPath, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map(async (entry) => {
      const fullPath = path.join(dirPath, entry.name);
      if (entry.isDirectory()) {
        return await collectFiles(fullPath);
      }
      return entry.isFile() && entry.name !== ".DS_Store" ? [fullPath] : [];
    }),
  );
  return nested.flat();
}

function findBrokenWebreadUrls(raw: string): string[] {
  const broken: string[] = [];
  for (const match of raw.matchAll(/webread\s+(https:\/\/[^\s`)"',]+)/g)) {
    const url = match[1];
    if (url === undefined) {
      continue;
    }
    if (url.startsWith("https://learn.microsoft.com")) {
      broken.push(url);
      continue;
    }
    if (
      (url.startsWith("https://react.dev/") || url.startsWith("https://tanstack.com/")) &&
      !url.endsWith(".md") &&
      !url.endsWith("llms.txt")
    ) {
      broken.push(url);
    }
  }
  return broken;
}

describe("antigravity plugins, rules, and skills contracts", () => {
  it("validates every plugin.json manifest against the Antigravity schema", async () => {
    const pluginDirs = await listSubdirectories(PLUGINS_ROOT);
    expect(pluginDirs.length).toBeGreaterThan(0);

    const results = await Promise.all(
      pluginDirs.map(async (pluginDir) => {
        const manifestPath = path.join(PLUGINS_ROOT, pluginDir, "plugin.json");
        const rawJson = await readFile(manifestPath, "utf8");
        const parsedUnknown: unknown = JSON.parse(rawJson);
        const parsed = PluginManifestSchema.safeParse(parsedUnknown);
        return {
          pluginDir,
          manifestPath,
          success: parsed.success,
          name: parsed.success ? parsed.data.name : null,
          issues: parsed.success ? [] : parsed.error.issues,
        };
      }),
    );

    for (const item of results) {
      expect(item.issues, `${item.manifestPath} failed schema validation`).toEqual([]);
      expect(item.success).toBe(true);
      expect(item.name).toBe(item.pluginDir);
    }
  });

  it("enforces rule filename, frontmatter, CRLF, and 8 KB budget invariants", async () => {
    const pluginDirs = await listSubdirectories(PLUGINS_ROOT);

    const pluginRuleGroups = await Promise.all(
      pluginDirs.map(async (pluginDir) => {
        const rulesDir = path.join(PLUGINS_ROOT, pluginDir, "rules");
        const entries = await readdir(rulesDir, { withFileTypes: true });
        const mdFiles = entries.filter((entry) => entry.isFile() && entry.name.endsWith(".md"));
        const inspections = await Promise.all(
          mdFiles.map(async (fileEntry) => {
            const rulePath = path.join(rulesDir, fileEntry.name);
            const raw = await readFile(rulePath, "utf8");
            const frontmatter = parseYamlFrontmatter(raw);
            return {
              fileName: fileEntry.name,
              rulePath,
              hasCrlf: raw.includes("\r\n"),
              byteSize: Buffer.byteLength(raw, "utf8"),
              frontmatter,
              parsedNamed:
                fileEntry.name === "AGENTS.md"
                  ? null
                  : NamedRuleFrontmatterSchema.safeParse(frontmatter),
            };
          }),
        );
        return { pluginDir, inspections };
      }),
    );

    for (const group of pluginRuleGroups) {
      expect(group.inspections.length, `${group.pluginDir} has no rule files`).toBeGreaterThan(0);

      for (const rule of group.inspections) {
        expect(rule.hasCrlf, `${rule.rulePath} must use LF line endings`).toBe(false);
        expect(
          rule.byteSize,
          `${rule.rulePath} exceeds ${MAX_RULE_BYTES} bytes`,
        ).toBeLessThanOrEqual(MAX_RULE_BYTES);

        const isAlwaysOnAgents = rule.fileName === "AGENTS.md";
        expect(isAlwaysOnAgents ? rule.frontmatter : null).toBeNull();
        expect(isAlwaysOnAgents ? true : (rule.parsedNamed?.success ?? false)).toBe(true);

        const globs =
          rule.parsedNamed !== null &&
          rule.parsedNamed.success &&
          rule.parsedNamed.data.trigger === "glob"
            ? rule.parsedNamed.data.globs
            : "ok";
        expect(globs).toBeDefined();
        expect((globs ?? "").includes("\\")).toBe(false);
      }
    }
  });

  it("validates SKILL.md frontmatter, folder parity, and reliable webread endpoints", async () => {
    const pluginDirs = await listSubdirectories(PLUGINS_ROOT);

    const skillGroups = await Promise.all(
      pluginDirs.map(async (pluginDir) => {
        const skillsDir = path.join(PLUGINS_ROOT, pluginDir, "skills");
        const skillDirs = await listSubdirectories(skillsDir);
        const inspections = await Promise.all(
          skillDirs.map(async (skillDir) => {
            const skillPath = path.join(skillsDir, skillDir, "SKILL.md");
            const fileStat = await stat(skillPath);
            const raw = await readFile(skillPath, "utf8");
            const frontmatter = parseYamlFrontmatter(raw);
            const parsed = SkillFrontmatterSchema.safeParse(frontmatter);
            return {
              skillDir,
              skillPath,
              isFile: fileStat.isFile(),
              hasCrlf: raw.includes("\r\n"),
              brokenUrls: findBrokenWebreadUrls(raw),
              hasFrontmatter: frontmatter !== null,
              hasTriggerKey: frontmatter !== null && "trigger" in frontmatter,
              schemaValid: parsed.success,
              parsedName: parsed.success ? parsed.data.name : null,
            };
          }),
        );
        return { pluginDir, inspections };
      }),
    );

    for (const group of skillGroups) {
      expect(group.inspections.length, `${group.pluginDir} has no skills`).toBeGreaterThan(0);

      for (const skill of group.inspections) {
        expect(skill.isFile).toBe(true);
        expect(skill.hasCrlf, `${skill.skillPath} must use LF line endings`).toBe(false);
        expect(skill.brokenUrls, `${skill.skillPath} uses known failing webread HTML URLs`).toEqual(
          [],
        );
        expect(skill.hasFrontmatter, `${skill.skillPath} is missing YAML frontmatter`).toBe(true);
        expect(skill.hasTriggerKey, `${skill.skillPath} must not set trigger`).toBe(false);
        expect(skill.schemaValid, `${skill.skillPath} frontmatter failed schema validation`).toBe(
          true,
        );
        expect(skill.parsedName).toBe(skill.skillDir);
      }
    }
  });

  it("keeps PSScriptAnalyzerSettings.psd1 identical between root and common-modern-tools", async () => {
    const rootSettings = (
      await readFile(path.join(REPO_ROOT, "PSScriptAnalyzerSettings.psd1"), "utf8")
    ).replace(/\r\n/g, "\n");
    const pluginSettings = (
      await readFile(
        path.join(PLUGINS_ROOT, "common-modern-tools", "PSScriptAnalyzerSettings.psd1"),
        "utf8",
      )
    ).replace(/\r\n/g, "\n");

    expect(pluginSettings).toBe(rootSettings);
  });

  it("validates skill reference/resource markdown files and install.sh fallback coverage", async () => {
    const macosPlugins = ["common-modern-tools", "macos-modern-tools", "modern-web-stack"];

    const [pluginFiles, installShRaw] = await Promise.all([
      Promise.all(macosPlugins.map((name) => collectFiles(path.join(PLUGINS_ROOT, name)))),
      readFile(path.join(REPO_ROOT, "scripts", "install.sh"), "utf8"),
    ]);
    const allFiles = pluginFiles.flat();

    const markdownExtras = allFiles.filter(
      (filePath) =>
        filePath.endsWith(".md") &&
        (filePath.includes(`${path.sep}references${path.sep}`) ||
          filePath.includes(`${path.sep}resources${path.sep}`)),
    );

    const extraChecks = await Promise.all(
      markdownExtras.map(async (filePath) => {
        const raw = await readFile(filePath, "utf8");
        return {
          filePath,
          hasCrlf: raw.includes("\r\n"),
          brokenUrls: findBrokenWebreadUrls(raw),
        };
      }),
    );

    for (const item of extraChecks) {
      expect(item.hasCrlf, `${item.filePath} must use LF line endings`).toBe(false);
      expect(item.brokenUrls, `${item.filePath} uses known failing webread URLs`).toEqual([]);
    }

    for (const filePath of allFiles) {
      const rel = path.relative(REPO_ROOT, filePath).replace(/\\/g, "/");
      const fileName = path.basename(rel);
      const isCovered =
        installShRaw.includes(rel) ||
        rel.endsWith("/plugin.json") ||
        (rel.startsWith("plugins/common-modern-tools/rules/") && fileName === "AGENTS.md") ||
        (rel.startsWith("plugins/macos-modern-tools/rules/") && fileName === "AGENTS.md") ||
        (rel.startsWith("plugins/modern-web-stack/rules/") && installShRaw.includes(fileName)) ||
        (rel.startsWith("plugins/modern-web-stack/skills/") &&
          fileName === "SKILL.md" &&
          installShRaw.includes(path.basename(path.dirname(rel)))) ||
        (rel.startsWith("plugins/modern-web-stack/skills/node-project-architecture/resources/") &&
          installShRaw.includes(fileName));

      expect(isCovered, `${rel} is missing from scripts/install.sh fallback deployment`).toBe(true);
    }
  });
});
