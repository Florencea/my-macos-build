import { defineConfig } from "vite-plus";

const SHARED_IGNORE_PATTERNS = [
  "cli/bin/**",
  "configs/**",
  "plugins/**/resources/**",
  "node_modules/**",
  "dist/**",
  ".vitest/**",
];

export default defineConfig({
  run: {
    cache: {
      scripts: true,
    },
    tasks: {
      "ps:fast": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-fast.ps1",
        cache: {
          untrackedEnv: ["DOTNET_ROOT", "DOTNET_ROOT_ARM64"],
          output: [],
        },
      },
      "ps:lint:install": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-lint.ps1 --target install",
        dependsOn: ["ps:fast"],
        cache: {
          untrackedEnv: ["DOTNET_ROOT", "DOTNET_ROOT_ARM64"],
          output: [],
        },
      },
      "ps:compat:install": {
        command: "pwsh -NoLogo -NoProfile -File tests/verify-ps-compat.ps1 --target install",
        dependsOn: ["ps:fast"],
        cache: {
          untrackedEnv: ["DOTNET_ROOT", "DOTNET_ROOT_ARM64"],
          output: [],
        },
      },
      "lint:shell": {
        command: "vpx tests/verify-shell.ts",
        cache: {
          output: [],
        },
      },
      "verify:inner": {
        command: "vp check",
        dependsOn: ["ps:fast", "lint:shell"],
        cache: {
          output: [],
        },
      },
      "verify:unit": {
        command: "vp test run --project unit --reporter=tap-flat --no-color",
        dependsOn: ["verify:inner", "ps:lint:install"],
        cache: {
          output: [],
        },
      },
      "verify:gate": {
        command: "vp test run --project contract --reporter=tap-flat --no-color",
        dependsOn: ["verify:unit", "ps:compat:install"],
        cache: {
          untrackedEnv: ["DOTNET_ROOT", "DOTNET_ROOT_ARM64"],
          output: [],
        },
      },
    },
  },
  lint: {
    ignorePatterns: SHARED_IGNORE_PATTERNS,
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
    ignorePatterns: SHARED_IGNORE_PATTERNS,
    sortImports: true,
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
