import { defineConfig } from "vite-plus";

export default defineConfig({
  run: {
    cache: {
      scripts: true,
      tasks: true,
    },
    tasks: {
      "lint:ps": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify.ps1 --scope ps",
        cache: {
          input: [
            "cli/**/*.ps1",
            "cli/**/*.psm1",
            "scripts/install.ps1",
            "tests/**/*.ps1",
            "PSScriptAnalyzerSettings.psd1",
          ],
          output: [],
        },
      },
      "lint:shell": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify.ps1 --scope shell",
        cache: {
          input: [
            "scripts/install.sh",
            "configs/zsh/**",
            "configs/bash/**",
            "configs/git/hooks/**",
            "tests/verify.ps1",
          ],
          output: [],
        },
      },
      "verify:native": {
        command: "pwsh -NoLogo -NoProfile -File tests/cli.Tests.ps1",
        dependsOn: ["lint:ps", "lint:shell"],
        cache: {
          input: ["cli/**/*.ps1", "cli/**/*.psm1", "tests/cli.Tests.ps1", "package.json"],
          env: ["YT_DLP_BROWSER"],
          output: [],
        },
      },
    },
  },
  staged: {
    "*.{ts,d.ts,json,md}": () => "vp check --fix",
    "*.{ps1,psm1}": () => "pwsh -NoLogo -NoProfile -File tests/verify.ps1 --scope ps",
    "scripts/install.sh": () => "pwsh -NoLogo -NoProfile -File tests/verify.ps1 --scope shell",
    "configs/{bash,zsh,git}/**": () =>
      "pwsh -NoLogo -NoProfile -File tests/verify.ps1 --scope shell",
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
