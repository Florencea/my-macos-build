import tailwindcss from "@tailwindcss/vite";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import react from "@vitejs/plugin-react";
import { playwright } from "@vitest/browser-playwright";
import { defineConfig } from "vitest/config";

export default defineConfig({
  build: {
    outDir: "dist",
    chunkSizeWarningLimit: 1000,
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
        extends: true,
        test: {
          name: "unit",
          include: ["test/unit/**/*.{test,spec}.{ts,tsx}"],
          environment: "node",
        },
      },
      {
        extends: true,
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
