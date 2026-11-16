import tailwindcss from "@tailwindcss/vite";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite-plus";
import { playwright } from "vite-plus/test/browser-playwright";

export default defineConfig({
  run: {
    cache: {
      scripts: true,
    },
  },
  build: {
    outDir: "dist",
    chunkSizeWarningLimit: 1000,
  },
  lint: {
    ignorePatterns: [
      "dist/**",
      ".cache/**",
      ".tanstack/**",
      ".vitest/**",
      "test-results/**",
      "playwright-report/**",
      "blob-report/**",
      "src/routeTree.gen.ts",
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
    plugins: ["react", "unicorn", "typescript", "oxc", "vitest", "promise", "node", "import"],
    jsPlugins: ["@shadcn/lint"],
    settings: {
      shadcn: {
        ui: "src/components/ui",
        componentImports: ["^src/components/ui(/|$)"],
      },
    },
    rules: {
      "react/react-in-jsx-scope": "off",
      "shadcn/no-restyle": [
        "error",
        {
          allow: ["layout"],
          contracts: [
            { pattern: "^Button$", allow: ["layout"] },
            { pattern: "^CardContent$", allow: ["layout", "spacing"] },
          ],
        },
      ],
      "shadcn/no-raw-colors": "error",
      "shadcn/no-arbitrary-values": "error",
      "shadcn/no-inline-styles": "error",
    },
    overrides: [
      {
        files: ["src/components/ui/**"],
        rules: {
          "shadcn/no-restyle": "off",
          "shadcn/no-arbitrary-values": "off",
        },
      },
    ],
  },
  fmt: {
    ignorePatterns: [
      "dist/**",
      ".cache/**",
      ".tanstack/**",
      ".vitest/**",
      "test-results/**",
      "playwright-report/**",
      "blob-report/**",
      "src/routeTree.gen.ts",
    ],
    sortPackageJson: true,
  },
  plugins: [
    tanstackRouter({
      routesDirectory: "./src/routes",
      generatedRouteTree: "./src/routeTree.gen.ts",
      autoCodeSplitting: true,
    }),
    react({
      compiler: true,
    }),
    tailwindcss(),
  ],
  test: {
    allowOnly: !process.env.CI,
    silent: "passed-only",
    projects: [
      {
        test: {
          name: "unit",
          include: ["test/unit/**/*.{test,spec}.{ts,tsx}"],
          environment: "node",
        },
      },
      {
        test: {
          name: "e2e",
          include: ["test/e2e/**/*.{test,spec}.{ts,tsx}"],
          browser: {
            enabled: true,
            provider: playwright(),
            headless: true,
            instances: [{ browser: "chromium" }],
          },
        },
      },
    ],
  },
});
