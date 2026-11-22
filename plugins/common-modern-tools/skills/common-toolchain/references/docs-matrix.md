# Verified External Documentation Lookup Matrix

Verify local ground truth first (`<tool> --help`, `go doc`, `node_modules/<pkg>/**/*.d.ts`) before fetching external documentation. For large hubs, run Stage 1 (`llms.txt` or index) first via `curl -fsSL`, then retrieve only the targeted path.

## Language & Framework Gateways

- **Go**: `go doc <pkg>[.<sym>]` / `go help <topic>` | `https://go.dev/doc/` / `https://pkg.go.dev/<module>`
- **Node.js**: `node --help` / `npm help <cmd>` | `curl -fsSL https://nodejs.org/llms.txt | head -n 120` -> `https://nodejs.org/docs/latest/api/<module>.md`
- **TypeScript**: `npx tsc --help` / `node_modules/typescript/lib/*.d.ts` | `https://www.typescriptlang.org/docs/handbook/<topic>.html`
- **ESLint / typescript-eslint**: `npx eslint --help` / `npx eslint --print-config <file>` | `https://eslint.org/docs/latest/rules/` / `https://typescript-eslint.io/rules/`
- **Prettier**: `npx prettier --help` | `curl -fsSL https://prettier.io/llms.txt | head -n 120` -> `https://prettier.io/docs/options`
- **Vite**: `npx vite --help` / `node_modules/vite/**/*.d.ts` | `curl -fsSL https://vite.dev/llms.txt | head -n 120` -> targeted `.md`
- **Vitest**: `npx vitest --help` / `node_modules/vitest/**/*.d.ts` | `curl -fsSL https://vitest.dev/llms.txt | head -n 120` -> targeted `.md`
- **React**: `node_modules/@types/react/**/*.d.ts` | `curl -fsSL https://react.dev/llms.txt | head -n 120` -> `https://react.dev/<path>.md` (HTML pages return empty shells)
- **Tailwind CSS**: local `@theme` CSS definitions | `https://tailwindcss.com/docs/<topic>`
- **Zod**: `node_modules/zod/**/*.d.ts` | `curl -fsSL https://zod.dev/llms.txt | head -n 120` -> `https://zod.dev/api`
- **TanStack Router**: `node_modules/@tanstack/react-router/**/*.d.ts` | `curl -fsSL https://tanstack.com/router/latest/llms.txt | head -n 120` -> `https://tanstack.com/router/latest/docs/<path>.md`
- **Web Platform (Baseline)**: `npx modern-web-guidance search "<query>"` -> `npx modern-web-guidance retrieve "<id>"`
- **Antigravity**: — | `curl -fsSL https://antigravity.google/llms.txt | head -n 120` -> `/docs/<topic>`

## Core CLI Tools

- **ast-grep**: `ast-grep --help` / `sg --help` | `curl -fsSL https://ast-grep.github.io/llms.txt | head -n 120` -> targeted doc page
- **actionlint**: `actionlint -help` | `https://raw.githubusercontent.com/rhysd/actionlint/main/docs/usage.md`
- **shellcheck**: `shellcheck --help` | `https://www.shellcheck.net/wiki/`
- **shfmt**: `shfmt --help` | `https://github.com/mvdan/sh`
- **fish**: `fish --help` / `fish_indent --help` | `https://fishshell.com/docs/current/`
- **fnm**: `fnm --help` | `https://github.com/Schniz/fnm`
- **ripgrep**: `rg --help` | `https://raw.githubusercontent.com/BurntSushi/ripgrep/master/GUIDE.md`
- **fd**: `fd --help` | `https://github.com/sharkdp/fd`
- **jq / yq**: `jq --help` / `yq --help` | `https://jqlang.github.io/jq/manual/` / `https://mikefarah.gitbook.io/yq/`
- **FFmpeg / FFprobe**: `ffmpeg -h full` / `ffprobe -h` | `https://ffmpeg.org/ffmpeg.html`
- **gifski**: `gifski --help` | `https://github.com/ImageOptim/gifski`
- **yt-dlp**: `yt-dlp --help` | `https://github.com/yt-dlp/yt-dlp#usage-and-options`
