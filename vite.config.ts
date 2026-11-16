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
            "scripts/**/*.ps1",
            "scripts/**/*.psm1",
            "scripts/**/*.psd1",
            "tests/VerifyCommon.psm1",
            "tests/verify-ps-*.ps1",
            "PSScriptAnalyzerSettings.psd1",
          ],
          untrackedEnv: ["DOTNET_ROOT", "DOTNET_ROOT_ARM64"],
          output: [],
        },
      },
      "ps:lint:install": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-lint.ps1 --target install",
        dependsOn: ["ps:fast"],
        cache: {
          input: [
            "scripts/**/*.ps1",
            "scripts/**/*.psm1",
            "scripts/**/*.psd1",
            "tests/VerifyCommon.psm1",
            "tests/verify-ps-lint.ps1",
            "PSScriptAnalyzerSettings.psd1",
          ],
          untrackedEnv: ["DOTNET_ROOT", "DOTNET_ROOT_ARM64"],
          output: [],
        },
      },
      "ps:compat:install": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-compat.ps1 --target install",
        dependsOn: ["ps:fast"],
        cache: {
          input: [
            "scripts/**/*.ps1",
            "scripts/**/*.psm1",
            "scripts/**/*.psd1",
            "tests/VerifyCommon.psm1",
            "tests/verify-ps-compat.ps1",
          ],
          untrackedEnv: ["DOTNET_ROOT", "DOTNET_ROOT_ARM64"],
          output: [],
        },
      },
      "lint:shell": {
        command: "vpx tests/verify-shell.ts",
        cache: {
          input: [
            "scripts/install.sh",
            "configs/zsh/**",
            "configs/bash/**",
            "configs/git/hooks/**",
            "cli/bin/*",
            "cli/src/lib/process.ts",
            "tests/verify-shell.ts",
          ],
          output: [],
        },
      },
      "verify:inner": {
        command: "vp check",
        dependsOn: ["typecheck", "ps:fast", "lint:shell"],
        cache: {
          input: [
            "cli/src/**/*.ts",
            "cli/src/types/**/*.d.ts",
            "scripts/**/*.ts",
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
        dependsOn: ["verify:inner", "ps:lint:install"],
        cache: {
          input: [
            "cli/src/**/*.ts",
            "tests/webread-parser.test.ts",
            "tests/unit/**/*.test.ts",
            "package.json",
            "tsconfig.json",
            "vite.config.ts",
          ],
          output: [],
        },
      },
      "verify:gate": {
        command: "vp test run --project contract --reporter=tap-flat --no-color",
        dependsOn: ["verify:unit", "ps:compat:install"],
        cache: {
          input: [
            "plugins/**",
            "cli/bin/**",
            "cli/src/**/*.ts",
            "scripts/install.sh",
            "scripts/install.ps1",
            "scripts/windows/**",
            "scripts/sync-cli-bins.ts",
            "tests/VerifyCommon.psm1",
            "tests/verify-ps-*.ps1",
            "tests/plugins.test.ts",
            "tests/contract/**/*.test.ts",
            "PSScriptAnalyzerSettings.psd1",
            "package.json",
            "vite.config.ts",
          ],
          untrackedEnv: ["DOTNET_ROOT", "DOTNET_ROOT_ARM64"],
          output: [],
        },
      },
    },
  },
  lint: {
    ignorePatterns: [
      "cli/bin/**",
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
      "cli/bin/**",
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
          include: ["tests/webread-parser.test.ts", "tests/unit/**/*.test.ts"],
        },
      },
      {
        extends: true,
        test: {
          name: "contract",
          include: ["tests/plugins.test.ts", "tests/contract/**/*.test.ts"],
        },
      },
    ],
  },
});
