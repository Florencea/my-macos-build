---
name: modern-web-guidance
description: Google Chrome & Web Standards guidance engine (HTML5, CSS layout/animations, Web APIs, Accessibility, Core Web Vitals, legacy pattern scan). Query before writing or modifying client-side web UI or browser APIs.
compatibility: Node.js (Active LTS), npm, Modern Browsers (Baseline Widely & Newly Available)
---

# Google Chrome Modern Web Guidance (External SSOT Gateway)

Query and retrieve modern web practices directly from the official `GoogleChrome/modern-web-guidance` knowledge engine using `npx`.

This repository maintains zero static specifications or cheat sheets for web platform capabilities. All HTML5 semantics, modern CSS, Web APIs, form validation, accessibility patterns, and browser Baseline compatibility are resolved on-demand through live CLI queries.

## Trigger Matrix

- **MANDATORY Trigger**:
  - Native UI overlays: `<dialog>` modals, non-modal dialogs, `[popover]`, dropdowns, tooltips, light dismiss.
  - Modern CSS layouts: Anchor Positioning (`anchor-name`, `anchor()`), Container Queries (`@container`), Subgrid, intrinsic sizing (`min-content`, `max-content`).
  - Animations & Transitions: View Transitions API, Scroll-driven animations (`animation-timeline`), `@starting-style`, CSS transition discrete properties.
  - Forms & Validation: Native validation states (`:user-invalid`, `:user-valid`), accessible error announcements, form autofill, Invoker Commands (`commandfor`, `command`).
  - Accessibility & Performance: Semantic HTML vs ARIA, focus trapping, roving tabindex, Core Web Vitals (LCP, INP, CLS), `content-visibility`, `fetchpriority`.
  - Modern Browser APIs: WebMCP, Sanitizer API, Temporal/dates, WebAssembly, on-device AI (Prompt API).
- **DO NOT Trigger**:
  - Backend logic (Go or Node.js server APIs, SQL schemas, migrations).
  - Infrastructure & automation (GitHub Actions CI, Docker, shell scripts).
  - Framework-only state or routing logic (React state hooks, explicit client route definitions).

---

## Primary Protocol: On-Demand External Resolution

### Stage 1: Action-Oriented Search

Execute a focused 2-4 word query describing the capability (`<verb> + <UI/platform object>`):

```sh
npx modern-web-guidance search "<query>"
```

- **Query Conventions**:
  - Translate intent to concrete web primitives (e.g. search `"confirm dialog modal"` rather than `"confirm destructive action"`; search `"popover dropdown menu"` rather than `"floating select"`).
  - Omit framework names (`React`, `Vue`, `Tailwind`) and application domain terms.
- **Result Handling**:
  - Returns `[{ "id": "...", "description": "..." }]`. Inspect `description` and pick the exact matching ID.
  - If results are empty, rephrase once with alternative platform terms (e.g. `modal` vs `dialog`, `popover` vs `overlay`) before falling back.

### Stage 2: Retrieve Full Best-Practice Specification

Retrieve the implementation guide using the matched ID:

```sh
npx modern-web-guidance retrieve "<id>"
```

- **Large Output Protocol**: When output exceeds 9.5 KB, the CLI automatically writes the guide to a local temporary file (e.g. `/tmp/mwg-guide-*.md`). Read the target file in full using the native file-reading tool.

### Stage 3: Baseline Compliance & Polyfill Governance

- **Baseline Widely Available**: Use native browser platform primitives directly. STRICTLY FORBIDDEN to import third-party polyfills, heavy UI packages, or custom JavaScript measurement hacks.
- **Baseline Newly Available**: Follow the guide's fallback strategy. If a polyfill is required for older browser targets, load it exclusively via runtime feature detection and dynamic `import()`:
  ```js
  if (!("commandForElement" in HTMLButtonElement.prototype)) {
    await import("invokers-polyfill");
  }
  ```
  Never bundle polyfills statically into the production bundle without feature gating.

---

## Secondary Protocol: Project-Wide Legacy Codebase Modernization

When explicitly tasked with auditing or modernizing an existing codebase for legacy web patterns (not during routine single-feature development):

```sh
npx modern-web-guidance legacy-scan [path] --json
```

1. **Scan**: Analyze target directory for deprecated or legacy browser patterns.
2. **Verify**: Evaluate each finding against the guide's `keepWhen` / `dropWhen` criteria to filter intentional fallbacks.
3. **Remediate**: Retrieve the target replacement guide via `npx modern-web-guidance retrieve "<guide-id>"` and refactor code to native standards.
