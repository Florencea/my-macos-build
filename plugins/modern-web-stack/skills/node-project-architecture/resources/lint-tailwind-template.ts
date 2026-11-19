import { fork } from "node:child_process";
import fs from "node:fs/promises";
import { createRequire } from "node:module";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";
import type {
  Diagnostic,
  InitializeParams,
  Position,
  TextEdit,
} from "vscode-languageserver-protocol/node";
import {
  CodeActionKind,
  CodeActionRequest,
  ConfigurationRequest,
  DidCloseTextDocumentNotification,
  DidOpenTextDocumentNotification,
  ExitNotification,
  IPCMessageReader,
  IPCMessageWriter,
  InitializeRequest,
  InitializedNotification,
  PublishDiagnosticsNotification,
  RegistrationRequest,
  ShutdownRequest,
  UnregistrationRequest,
  createProtocolConnection,
} from "vscode-languageserver-protocol/node";

// --- Supported Extensions & Language Mappings ---

const SUPPORTED_GLOB_EXTENSIONS = "**/*.{tsx,ts,jsx,js,mjs,cjs,html,css,postcss,vue,svelte,astro}";

const EXTENSION_TO_LANGUAGE_ID: Record<string, string> = {
  ".tsx": "typescriptreact",
  ".jsx": "javascriptreact",
  ".ts": "typescript",
  ".js": "javascript",
  ".mjs": "javascript",
  ".cjs": "javascript",
  ".html": "html",
  ".css": "css",
  ".postcss": "css",
  ".vue": "vue",
  ".svelte": "svelte",
  ".astro": "astro",
};

// --- Baseline Exclusions (from official vscode-tailwindcss & standard build tools) ---

const BASELINE_EXCLUDES: readonly string[] = [
  "**/.git/**",
  "**/node_modules/**",
  "**/.hg/**",
  "**/.svn/**",
  "**/dist/**",
  "**/build/**",
  "**/.next/**",
  "**/.turbo/**",
  "**/.parcel-cache/**",
  "**/.DS_Store",
  "**/CVS",
  "**/Thumbs.db",
  "**/*.d.ts",
];

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

function normalizeExcludePattern(rawPattern: string): string {
  const normalized = rawPattern.replace(/\\/g, "/").trim();
  if (normalized.endsWith("/**")) {
    return `${normalized.slice(0, -3)}{,/**}`;
  }
  if (normalized.endsWith("/")) {
    return `${normalized.slice(0, -1)}{,/**}`;
  }
  return normalized;
}

async function loadNormalizedExclusions(projectRoot: string): Promise<string[]> {
  const patterns = new Set<string>(BASELINE_EXCLUDES);

  // 1. Read .vscode/settings.json (if present) via dynamic JSON import
  const vscodeSettingsPath = path.join(projectRoot, ".vscode/settings.json");
  if (await fileExists(vscodeSettingsPath)) {
    try {
      const raw = await fs.readFile(vscodeSettingsPath, "utf8");
      const parsed: unknown = JSON.parse(raw);
      if (typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)) {
        const tailwindExcludes =
          "tailwindCSS.files.exclude" in parsed ? parsed["tailwindCSS.files.exclude"] : undefined;
        if (Array.isArray(tailwindExcludes)) {
          for (const item of tailwindExcludes) {
            if (typeof item === "string") {
              patterns.add(item);
            }
          }
        }

        const filesExcludes = "files.exclude" in parsed ? parsed["files.exclude"] : undefined;
        if (filesExcludes && typeof filesExcludes === "object" && !Array.isArray(filesExcludes)) {
          for (const [key, val] of Object.entries(filesExcludes)) {
            if (val === true) {
              patterns.add(key);
            }
          }
        }
      }
    } catch {
      // Gracefully ignore syntax/JSONC errors in settings.json
    }
  }

  // 2. Read .gitignore (if present)
  const gitignorePath = path.join(projectRoot, ".gitignore");
  if (await fileExists(gitignorePath)) {
    try {
      const raw = await fs.readFile(gitignorePath, "utf8");
      const lines = raw.split(/\r?\n/);
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.length > 0 && !trimmed.startsWith("#")) {
          patterns.add(trimmed);
        }
      }
    } catch {
      // Ignore read errors
    }
  }

  return Array.from(patterns).map(normalizeExcludePattern);
}

// --- Dynamic Server Binary Resolution ---

async function resolveServerBinary(projectRoot: string): Promise<string> {
  // 1. Resolve relative to @tailwindcss/language-server package root
  try {
    const req = createRequire(path.join(projectRoot, "package.json"));
    const pkgJsonPath = req.resolve("@tailwindcss/language-server/package.json");
    const pkgDir = path.dirname(pkgJsonPath);
    const binCandidate = path.join(pkgDir, "bin/tailwindcss-language-server");
    if (await fileExists(binCandidate)) {
      return await fs.realpath(binCandidate);
    }
  } catch {
    // Fallback if direct package resolution is unavailable
  }

  // 2. Resolve hoisted binary in node_modules/.bin
  const hoistedBin = path.join(projectRoot, "node_modules/.bin/tailwindcss-language-server");
  if (await fileExists(hoistedBin)) {
    return await fs.realpath(hoistedBin);
  }

  // 3. Fallback to global command
  return "tailwindcss-language-server";
}

// --- LSP Client ---

interface LSPClient {
  connection: ReturnType<typeof createProtocolConnection>;
  waitForServerReady: (timeoutMs?: number) => Promise<void>;
  waitForDiagnostics: (uri: string, timeoutMs?: number) => Promise<Diagnostic[]>;
  close: () => Promise<void>;
}

async function createLSPClient(projectRoot: string): Promise<LSPClient> {
  const binaryPath = await resolveServerBinary(projectRoot);

  const child = fork(binaryPath, ["--node-ipc"], {
    cwd: projectRoot,
    stdio: ["ignore", "ignore", "inherit", "ipc"],
  });

  const connection = createProtocolConnection(
    new IPCMessageReader(child),
    new IPCMessageWriter(child),
  );

  const tailwindConfig = {
    validate: true,
    lint: {
      suggestCanonicalClasses: "warning",
      cssConflict: "warning",
      invalidApply: "error",
      recommendedVariantOrder: "warning",
    },
    rootFontSize: 16,
    files: {
      exclude: BASELINE_EXCLUDES,
    },
  };

  connection.onRequest(ConfigurationRequest.type, (params) => {
    return params.items.map((item) => {
      if (item.section === "tailwindCSS") return tailwindConfig;
      if (item.section === "editor") return { tabSize: 2 };
      if (item.section === "files")
        return {
          exclude: {
            "**/.git": true,
            "**/node_modules": true,
            "**/dist": true,
          },
        };
      return {};
    });
  });

  connection.onRequest(RegistrationRequest.type, () => {
    // Acknowledge dynamic capability registrations from server
  });
  connection.onRequest(UnregistrationRequest.type, () => {
    // Acknowledge dynamic capability unregistrations from server
  });

  let onServerReadyCallback: (() => void) | null = null;
  connection.onNotification("@/tailwindCSS/serverReady", () => {
    if (onServerReadyCallback) {
      onServerReadyCallback();
      onServerReadyCallback = null;
    }
  });

  const diagnosticsWaiters = new Map<string, (diags: Diagnostic[]) => void>();

  connection.onNotification(PublishDiagnosticsNotification.type, (params) => {
    if (params.uri !== undefined && params.uri !== "") {
      const resolve = diagnosticsWaiters.get(params.uri);
      if (resolve !== undefined) {
        diagnosticsWaiters.delete(params.uri);
        resolve(params.diagnostics);
      }
    }
  });

  connection.listen();

  return {
    connection,
    waitForServerReady: (timeoutMs = 5000): Promise<void> => {
      return new Promise((resolve) => {
        const timer = setTimeout(() => {
          onServerReadyCallback = null;
          resolve();
        }, timeoutMs);
        onServerReadyCallback = () => {
          clearTimeout(timer);
          resolve();
        };
      });
    },
    waitForDiagnostics: (uri: string, timeoutMs = 800): Promise<Diagnostic[]> => {
      return new Promise((resolve) => {
        diagnosticsWaiters.set(uri, resolve);
        setTimeout(() => {
          if (diagnosticsWaiters.has(uri)) {
            diagnosticsWaiters.delete(uri);
            resolve([]);
          }
        }, timeoutMs);
      });
    },
    close: async () => {
      try {
        await Promise.race([
          connection.sendRequest(ShutdownRequest.type),
          new Promise((r) => setTimeout(r, 600)),
        ]);
        await connection.sendNotification(ExitNotification.type);
      } catch {
        // Ignore exit errors
      } finally {
        connection.dispose();
        child.kill();
      }
    },
  };
}

// --- Offset Conversion & Text Editing ---

function positionToOffset(content: string, pos: Position): number {
  let line = 0;
  let offset = 0;
  while (line < pos.line && offset < content.length) {
    if (content[offset] === "\n") {
      line++;
    }
    offset++;
  }
  return offset + pos.character;
}

function applyTextEdits(content: string, edits: TextEdit[]): string {
  // Sort in reverse order of starting position to prevent index shift
  const sortedEdits = edits.map((edit) => {
    return {
      start: positionToOffset(content, edit.range.start),
      end: positionToOffset(content, edit.range.end),
      newText: edit.newText,
    };
  });

  sortedEdits.sort((a, b) => b.start - a.start);

  let updated = content;
  for (const edit of sortedEdits) {
    const before = updated.slice(0, edit.start);
    const after = updated.slice(edit.end);
    updated = before + edit.newText + after;
  }

  return updated;
}

interface LintFileResult {
  diagnostics: number;
  fixes: number;
}

async function collectAsyncIterable<T>(iterable: AsyncIterable<T>): Promise<T[]> {
  const items: T[] = [];
  for await (const item of iterable) {
    items.push(item);
  }
  return items;
}

async function resolveTargetFiles(
  projectRoot: string,
  nonFlagArgs: string[],
  shouldExclude: (filePath: string) => boolean,
): Promise<string[]> {
  if (nonFlagArgs.length > 0) {
    const fileLists = await Promise.all(
      nonFlagArgs.map(async (arg) => {
        const resolved = path.resolve(projectRoot, arg);
        if (!(await fileExists(resolved))) {
          console.warn(`File or directory not found: ${arg}`);
          return [];
        }
        const stat = await fs.stat(resolved);
        if (stat.isDirectory()) {
          const entries = await collectAsyncIterable(
            fs.glob(SUPPORTED_GLOB_EXTENSIONS, {
              cwd: resolved,
              exclude: (e) => shouldExclude(path.relative(projectRoot, path.join(resolved, e))),
            }),
          );
          return entries.map((entry) => path.resolve(resolved, entry));
        }
        if (stat.isFile()) {
          const rel = path.relative(projectRoot, resolved);
          if (path.matchesGlob(rel, SUPPORTED_GLOB_EXTENSIONS) && !shouldExclude(rel)) {
            return [resolved];
          }
        }
        return [];
      }),
    );
    return fileLists.flat();
  }

  const srcDir = path.join(projectRoot, "src");
  const searchDir = (await fileExists(srcDir)) ? srcDir : projectRoot;
  const entries = await collectAsyncIterable(
    fs.glob(SUPPORTED_GLOB_EXTENSIONS, {
      cwd: searchDir,
      exclude: (e) => shouldExclude(path.relative(projectRoot, path.join(searchDir, e))),
    }),
  );
  return entries.map((entry) => path.resolve(searchDir, entry));
}

async function lintSingleFile(
  client: LSPClient,
  file: string,
  isFix: boolean,
  projectRoot: string,
): Promise<LintFileResult> {
  const uri = pathToFileURL(file).toString();
  const ext = path.extname(file);
  const languageId = EXTENSION_TO_LANGUAGE_ID[ext] ?? "plaintext";
  const content = await fs.readFile(file, "utf8");

  const diagsPromise = client.waitForDiagnostics(uri);

  await client.connection.sendNotification(DidOpenTextDocumentNotification.type, {
    textDocument: {
      uri,
      languageId,
      version: 1,
      text: content,
    },
  });

  const diags = await diagsPromise;
  let diagnosticsCount = 0;
  let fixesCount = 0;

  if (diags.length > 0) {
    if (isFix) {
      const editsToApply: TextEdit[] = [];
      const fixedDiagnosticRanges = new Set<string>();

      const rawActionsList = await Promise.all(
        diags.map((diag) =>
          client.connection.sendRequest(CodeActionRequest.type, {
            textDocument: { uri },
            range: diag.range,
            context: { diagnostics: [diag] },
          }),
        ),
      );

      for (let i = 0; i < diags.length; i++) {
        const diag = diags[i];
        const rawActions = rawActionsList[i];
        if (!diag || !Array.isArray(rawActions)) continue;

        for (const action of rawActions) {
          if (
            "kind" in action &&
            action.kind === CodeActionKind.QuickFix &&
            action.title.startsWith("Replace with '") &&
            action.edit?.changes?.[uri]
          ) {
            editsToApply.push(...action.edit.changes[uri]);
            if (Array.isArray(action.diagnostics)) {
              for (const d of action.diagnostics) {
                fixedDiagnosticRanges.add(
                  `${d.range.start.line.toString()}:${d.range.start.character.toString()}`,
                );
              }
            } else {
              fixedDiagnosticRanges.add(
                `${diag.range.start.line.toString()}:${diag.range.start.character.toString()}`,
              );
            }
          }
        }
      }

      if (editsToApply.length > 0) {
        const updated = applyTextEdits(content, editsToApply);
        await fs.writeFile(file, updated, "utf8");
        fixesCount += editsToApply.length;
        console.log(
          `Fixed ${editsToApply.length.toString()} issue(s) in ${path.relative(projectRoot, file)}`,
        );
      }

      // Report remaining unfixable diagnostics (e.g. cssConflict)
      for (const diag of diags) {
        const key = `${diag.range.start.line.toString()}:${diag.range.start.character.toString()}`;
        if (!fixedDiagnosticRanges.has(key)) {
          diagnosticsCount++;
          const rel = path.relative(projectRoot, file);
          const line = diag.range.start.line + 1;
          const col = diag.range.start.character + 1;
          const code =
            typeof diag.code === "string"
              ? diag.code
              : typeof diag.code === "number"
                ? diag.code.toString()
                : "lint";
          const message = typeof diag.message === "string" ? diag.message : diag.message.value;
          console.warn(`  ${rel}:${line.toString()}:${col.toString()} - [${code}] ${message}`);
        }
      }
    } else {
      for (const diag of diags) {
        diagnosticsCount++;
        const rel = path.relative(projectRoot, file);
        const line = diag.range.start.line + 1;
        const col = diag.range.start.character + 1;
        const code =
          typeof diag.code === "string"
            ? diag.code
            : typeof diag.code === "number"
              ? diag.code.toString()
              : "lint";
        const message = typeof diag.message === "string" ? diag.message : diag.message.value;
        console.error(`  ${rel}:${line.toString()}:${col.toString()} - [${code}] ${message}`);
      }
    }
  }

  await client.connection.sendNotification(DidCloseTextDocumentNotification.type, {
    textDocument: { uri },
  });

  return { diagnostics: diagnosticsCount, fixes: fixesCount };
}

// --- Main Runner ---

async function main() {
  const { values, positionals } = parseArgs({
    options: {
      fix: {
        type: "boolean",
        default: false,
      },
    },
    allowPositionals: true,
  });

  const isFix = values.fix ?? false;
  const nonFlagArgs = positionals;

  const projectRoot = process.cwd();
  const exclusionPatterns = await loadNormalizedExclusions(projectRoot);

  const shouldExclude = (filePath: string): boolean => {
    const normalized = filePath.replace(/\\/g, "/");
    return exclusionPatterns.some((pattern) => path.matchesGlob(normalized, pattern));
  };

  const targetFiles = await resolveTargetFiles(projectRoot, nonFlagArgs, shouldExclude);

  if (targetFiles.length === 0) {
    console.log("No eligible Tailwind CSS files found to lint.");
    return;
  }

  const client = await createLSPClient(projectRoot);

  try {
    const initParams: InitializeParams = {
      processId: process.pid,
      rootUri: pathToFileURL(projectRoot).toString(),
      workspaceFolders: [
        {
          uri: pathToFileURL(projectRoot).toString(),
          name: path.basename(projectRoot),
        },
      ],
      capabilities: {
        workspace: {
          configuration: true,
          didChangeWatchedFiles: { dynamicRegistration: true },
        },
        textDocument: {
          publishDiagnostics: {},
          codeAction: {
            codeActionLiteralSupport: {
              codeActionKind: { valueSet: [CodeActionKind.QuickFix] },
            },
          },
        },
      },
      initializationOptions: {
        testMode: true,
      },
    };

    await client.connection.sendRequest(InitializeRequest.type, initParams);
    await client.connection.sendNotification(InitializedNotification.type, {});

    // Wait for server project discovery to be fully ready
    await client.waitForServerReady();

    let totalDiagnostics = 0;
    let totalFixes = 0;

    await targetFiles.reduce(async (prevPromise, file) => {
      await prevPromise;
      const res = await lintSingleFile(client, file, isFix, projectRoot);
      totalDiagnostics += res.diagnostics;
      totalFixes += res.fixes;
    }, Promise.resolve());

    await client.close();

    if (isFix) {
      if (totalFixes > 0) {
        console.log(`Successfully auto-fixed ${totalFixes.toString()} issue(s).`);
      }
      if (totalDiagnostics > 0) {
        console.warn(
          `\n${totalDiagnostics.toString()} issue(s) cannot be automatically resolved (e.g. conflicting CSS properties).`,
        );
        process.exitCode = 1;
        return;
      }
      console.log("All Tailwind CSS classes are clean.");
      return;
    }

    if (totalDiagnostics > 0) {
      console.error(`\nFound ${totalDiagnostics.toString()} Tailwind CSS diagnostic issue(s).`);
      console.error("Run `npm run lint:tailwind:fix` to auto-fix applicable issues.");
      process.exitCode = 1;
      return;
    }

    console.log("All Tailwind CSS classes are canonical and conflict-free.");
  } catch (err) {
    console.error("Tailwind language server execution error:", err);
    await client.close();
    process.exitCode = 1;
  }
}

void main();
