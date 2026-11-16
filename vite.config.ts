import { defineConfig } from "vite-plus";

export default defineConfig({
  run: {
    cache: {
      scripts: true,
      tasks: true,
    },
    tasks: {
      "ps:fast": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-fast.ps1",
        cache: {
          input: [
            "cli/**/*.ps1",
            "cli/**/*.psm1",
            "scripts/install.ps1",
            "tests/VerifyCommon.psm1",
            "tests/verify-ps-fast.ps1",
            "PSScriptAnalyzerSettings.psd1",
          ],
          output: [],
        },
      },
      "ps:lint:cli": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-lint.ps1 --target cli",
        dependsOn: ["ps:fast"],
        cache: {
          input: [
            "cli/**/*.ps1",
            "cli/**/*.psm1",
            "tests/**/*.ps1",
            "tests/**/*.psm1",
            "PSScriptAnalyzerSettings.psd1",
          ],
          output: [],
        },
      },
      "ps:lint:install": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-lint.ps1 --target install",
        dependsOn: ["ps:fast"],
        cache: {
          input: [
            "scripts/install.ps1",
            "tests/VerifyCommon.psm1",
            "tests/verify-ps-lint.ps1",
            "PSScriptAnalyzerSettings.psd1",
          ],
          output: [],
        },
      },
      "ps:compat:cli": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-compat.ps1 --target cli",
        dependsOn: ["ps:fast"],
        cache: {
          input: [
            "cli/**/*.ps1",
            "cli/**/*.psm1",
            "tests/VerifyCommon.psm1",
            "tests/verify-ps-compat.ps1",
          ],
          output: [],
        },
      },
      "ps:compat:install": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-compat.ps1 --target install",
        dependsOn: ["ps:fast"],
        cache: {
          input: ["scripts/install.ps1", "tests/VerifyCommon.psm1", "tests/verify-ps-compat.ps1"],
          output: [],
        },
      },
      "lint:shell": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-shell.ps1",
        cache: {
          input: [
            "scripts/install.sh",
            "configs/zsh/**",
            "configs/bash/**",
            "configs/git/hooks/**",
            "tests/VerifyCommon.psm1",
            "tests/verify-shell.ps1",
          ],
          output: [],
        },
      },
      "verify:inner": {
        command: "vp check",
        dependsOn: ["typecheck", "ps:fast", "lint:shell"],
        cache: {
          input: [
            "cli/helpers/**/*.ts",
            "cli/helpers/**/*.d.ts",
            "tests/**/*.ts",
            "plugins/**",
            ".agents/**",
            "*.json",
            "*.ts",
            "*.md",
          ],
          output: [],
        },
      },
      "verify:unit": {
        command: "vp test run --project unit --reporter=tap-flat --no-color",
        dependsOn: ["verify:inner", "ps:lint:cli", "ps:lint:install"],
        cache: {
          input: [
            "cli/helpers/webread-parser.ts",
            "tests/webread-parser.test.ts",
            "package.json",
            "tsconfig.json",
            "vite.config.ts",
          ],
          output: [],
        },
      },
      "verify:native": {
        command: "pwsh -NoLogo -NoProfile -File tests/cli.Tests.ps1",
        dependsOn: ["ps:fast"],
        cache: {
          input: [
            "cli/**/*.ps1",
            "cli/**/*.psm1",
            "tests/cli.Tests.ps1",
            "tests/verify-ps-fast.ps1",
            "tests/VerifyCommon.psm1",
            "PSScriptAnalyzerSettings.psd1",
            "package.json",
          ],
          env: ["YT_DLP_BROWSER"],
          output: [],
        },
      },
      "verify:gate": {
        command: "vp test run --project contract --reporter=tap-flat --no-color",
        dependsOn: ["verify:unit", "ps:compat:cli", "ps:compat:install", "verify:native"],
        cache: {
          input: [
            "plugins/**",
            "tests/plugins.test.ts",
            "PSScriptAnalyzerSettings.psd1",
            "package.json",
            "vite.config.ts",
          ],
          output: [],
        },
      },
    },
  },
  lint: {
    ignorePatterns: [
      "configs/**",
      "plugins/**/resources/**",
      "node_modules/**",
      "dist/**",
      ".vitest/**",
    ],
    options: {
      typeAware: true,
      typeCheck: true,
    },
    categories: {
      correctness: "error",
      suspicious: "error",
      perf: "error",
    },
    plugins: ["unicorn", "typescript", "oxc", "vitest", "promise", "node", "import"],
  },
  fmt: {
    ignorePatterns: [
      "configs/**",
      "plugins/**/resources/**",
      "node_modules/**",
      "dist/**",
      ".vitest/**",
    ],
    sortPackageJson: true,
  },
  test: {
    allowOnly: !process.env.CI,
    silent: "passed-only",
    environment: "node",
    projects: [
      {
        extends: true,
        test: {
          name: "unit",
          include: ["tests/webread-parser.test.ts"],
        },
      },
      {
        extends: true,
        test: {
          name: "contract",
          include: ["tests/plugins.test.ts"],
        },
      },
    ],
  },
});
