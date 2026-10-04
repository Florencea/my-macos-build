---
trigger: glob
globs: ".github/workflows/**"
description: CI workflow verification standards, actionlint requirements, and security guidelines.
---

# CI & GitHub Actions Workflow Standards

Standards for maintaining and updating GitHub Actions workflows.

## 1. Shift-Left Local Verification

- **Strict Requirement**: Whenever `.github/workflows/` files are added or modified, running `actionlint` locally with **0 errors and 0 warnings** is mandatory before staging (`git add`).
- **Execution Script**: Execute via `vpr agent:lint:ci` (or `actionlint` directly).

## 2. Guardrail Boundaries

- **Offline-Only Tool**: `actionlint` is strictly an offline / local shift-left verification guardrail.
- **Remote Workflow Invariant**: Never embed `actionlint` steps into remote GitHub Actions workflow files (`.github/workflows/*.yml`).
