#!/bin/zsh
emulate -L zsh
set -euo pipefail
setopt POSIX_TRAPS

# Description: Check and update Node.js package dependencies with clean spinner feedback
# Usage: up
# Example: up

# 1. Parse arguments
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "up: Check and update Node.js package dependencies with clean spinner feedback"
  echo "Usage: up"
  exit 0
fi

# 2. Check required tools
for cmd in git jq vp vpr vpx yq; do
  if ! (($+commands[$cmd])); then
    echo "Error: $cmd is not installed" >&2
    exit 1
  fi
done

# 3. Check project files
[[ -f "package.json" ]] || {
  echo "Error: File package.json does not exist" >&2
  exit 1
}

# 4. Check git status and branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "Error: Current branch is not 'main' ($CURRENT_BRANCH)" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working directory is not clean. Please commit or stash your changes first." >&2
  exit 1
fi

# 5. Sync repository
if git rev-parse --abbrev-ref @{u} &>/dev/null; then
  git pull --ff-only --quiet || {
    echo "Error: Cannot fast-forward with remote. Please sync your branch first." >&2
    exit 1
  }
fi

# 6. Spinner helper for time-consuming steps
run_with_spinner() {
  local msg="$1"
  shift
  local pid
  local -a spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local -i i=1
  local tmp_log
  tmp_log="$(mktemp -t up-spinner.XXXXXX)"

  # Run target command in background with output captured to temp log
  "$@" >"$tmp_log" 2>&1 &
  pid=$!

  # Show dynamic spinner while command is running
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  %s %s..." "${spin[i]}" "$msg"
    i=$(((i % $#spin) + 1))
    sleep 0.08
  done

  # Clear line immediately upon completion
  printf "\r\033[K"

  if ! wait "$pid"; then
    cat "$tmp_log" >&2
    rm -f "$tmp_log"
    return 1
  fi
  rm -f "$tmp_log"
}

# 7. Detect Vite+ project and inspect toolchain
IS_VITE_PLUS=0
if jq -e '((.dependencies // {}) + (.devDependencies // {})) | has("vite-plus")' package.json >/dev/null 2>&1; then
  IS_VITE_PLUS=1
fi

VP_TOOLCHAIN_UPGRADED=0
VP_OLD_VER=""
VP_NEW_VER=""

if ((IS_VITE_PLUS)); then
  GLOBAL_VP_VER="$(vp --version 2>/dev/null | awk '/^vp v/ {sub(/^vp v/, ""); print $1}')"
  LOCAL_VP_VER="$(jq -r '((.dependencies // {}) + (.devDependencies // {}))["vite-plus"] // empty' package.json 2>/dev/null)"

  # If catalog-backed, resolve concrete version from pnpm-workspace.yaml
  if [[ "$LOCAL_VP_VER" == "catalog:" && -f "pnpm-workspace.yaml" ]]; then
    LOCAL_VP_VER="$(yq '.catalog.vite-plus // .catalogs.default.vite-plus // ""' pnpm-workspace.yaml 2>/dev/null)"
  fi

  if [[ -n "$GLOBAL_VP_VER" && -n "$LOCAL_VP_VER" && "$LOCAL_VP_VER" != "$GLOBAL_VP_VER" ]]; then
    VP_TOOLCHAIN_UPGRADED=1
    VP_OLD_VER="$LOCAL_VP_VER"
    VP_NEW_VER="$GLOBAL_VP_VER"
  fi
fi

# 8. Check minor updates via NCU
NCU_JSON="$(vpx -s npm-check-updates@latest -t minor --install never --jsonUpgraded)"

if ((! IS_VITE_PLUS || ! VP_TOOLCHAIN_UPGRADED)) && [[ -z "$NCU_JSON" || "$NCU_JSON" == "{}" ]]; then
  exit 0
fi

# 9. Parse updates safely
count=0
commit_body=""
single_pkg_summary=""

has_vite_plus_in_targets=0

if [[ -n "$NCU_JSON" && "$NCU_JSON" != "{}" ]]; then
  raw_entries=("${(@f)$(jq -r 'to_entries[] | "\(.key)=\(.value)"' <<<"$NCU_JSON")}")

  for entry in "${raw_entries[@]}"; do
    [[ -z "$entry" ]] && continue
    pkg="${entry%%=*}"
    new_ver="${entry#*=}"
    old_ver="$(jq -r ".dependencies[\"$pkg\"] // .devDependencies[\"$pkg\"] // .peerDependencies[\"$pkg\"] // .optionalDependencies[\"$pkg\"] // \"?\"" package.json)"

    if [[ "$pkg" == "vite-plus" ]]; then
      has_vite_plus_in_targets=1
    fi

    printf "  %s  %s  ->  %s\n" "$pkg" "$old_ver" "$new_ver"
    commit_body+=$'\n'"- ${pkg}: ${old_ver} -> ${new_ver}"
    single_pkg_summary="${pkg} ${old_ver} -> ${new_ver}"
    ((count++)) || true
  done
fi

if ((VP_TOOLCHAIN_UPGRADED && ! has_vite_plus_in_targets)); then
  printf "  %s  %s  ->  %s\n" "vite-plus" "$VP_OLD_VER" "$VP_NEW_VER"
  commit_body+=$'\n'"- vite-plus: ${VP_OLD_VER} -> ${VP_NEW_VER}"
  single_pkg_summary="vite-plus ${VP_OLD_VER} -> ${VP_NEW_VER}"
  ((count++)) || true
fi

# 10. Create sandbox branch and register rollback trap
TEMP_BRANCH="chore/deps-upgrade-$(date +%s)"
git checkout -q -b "$TEMP_BRANCH"

FAILED_STEP="Verification"

cleanup() {
  local orig_exit=$?
  trap - EXIT INT TERM
  printf "\r\033[K" # Clear any remaining spinner line on failure

  if [[ $orig_exit -ne 0 ]]; then
    echo "Error: Pre-checks failed at step '${FAILED_STEP}'. Rolling back changes to 'main'..." >&2
    git checkout -q main || true
    git branch -D "$TEMP_BRANCH" >/dev/null 2>&1 || true
    if [[ -d ".node_modules.bak" ]]; then
      rm -rf node_modules
      mv .node_modules.bak node_modules
    else
      VP_LOG=error vp install --frozen-lockfile --silent 2>/dev/null || true
    fi
  fi
  exit "$orig_exit"
}
trap cleanup EXIT INT TERM

# 11. Update package manifests and lockfile
if ((IS_VITE_PLUS)); then
  # 11.1 Vite+ native toolchain migration MUST run first while original package.json and lockfile are intact,
  # ensuring migrator can accurately determine source Vitest version and prevent v4/v5 migration blocking errors.
  FAILED_STEP="vp migrate --no-interactive"
  run_with_spinner "Aligning Vite+ toolchain (vp migrate)" env VP_LOG=error vp migrate --no-interactive

  # 11.2 Update remaining third-party dependencies via NCU
  if [[ -n "$NCU_JSON" && "$NCU_JSON" != "{}" ]]; then
    FAILED_STEP="vpx npm-check-updates"
    run_with_spinner "Updating packages (NCU)" vpx -s npm-check-updates@latest -u -t minor
  fi

  FAILED_STEP="vp pm pkg fix"
  run_with_spinner "Normalizing manifest (vp pm pkg fix)" env VP_LOG=error vp pm pkg fix

  # Refresh lockfile with any new third-party dependencies updated by NCU
  FAILED_STEP="vp install"
  run_with_spinner "Syncing dependencies (vp install)" env VP_LOG=error vp install

  # Verify frozen lockfile consistency
  FAILED_STEP="vp install (frozen verification)"
  run_with_spinner "Verifying frozen lockfile" env VP_LOG=error vp install --frozen-lockfile
else
  # Generic Node.js project: update via NCU, normalize, isolate node_modules, and update lockfile
  if [[ -n "$NCU_JSON" && "$NCU_JSON" != "{}" ]]; then
    FAILED_STEP="vpx npm-check-updates"
    run_with_spinner "Updating packages (NCU)" vpx -s npm-check-updates@latest -u -t minor
  fi

  FAILED_STEP="vp pm pkg fix"
  run_with_spinner "Normalizing manifest (vp pm pkg fix)" env VP_LOG=error vp pm pkg fix

  if [[ -d "node_modules" ]]; then
    mv node_modules .node_modules.bak
  fi
  rm -f package-lock.json

  FAILED_STEP="vp install (lockfile update)"
  run_with_spinner "Writing lockfile" env VP_LOG=error vp install --lockfile-only --ignore-scripts

  FAILED_STEP="vp install"
  run_with_spinner "Syncing dependencies (vp install)" env VP_LOG=error vp install --frozen-lockfile
  rm -rf .node_modules.bak
fi

# 12. Run project pre-checks
run_first_matching_script() {
  local category="$1"
  local display_name="$2"
  shift 2
  for script_name in "$@"; do
    if jq -e ".scripts[\"$script_name\"]" package.json >/dev/null 2>&1; then
      FAILED_STEP="vpr $script_name ($category)"
      run_with_spinner "Verifying $display_name" env VP_LOG=error vpr "$script_name"
      return 0
    fi
  done
  return 0
}

# 12.1 Auto-format: native vp fmt formats all code & config files in place
# (Resolves pnpm-workspace.yaml and package.json formatting drift immediately)
FAILED_STEP="vp fmt"
run_with_spinner "Formatting code & configs (vp fmt)" env VP_LOG=error vp fmt

# 12.2 Code quality & lint: native vp check verifies formatting, runs Oxlint, and type checks
FAILED_STEP="vp check"
run_with_spinner "Checking quality & lint (vp check)" env VP_LOG=error vp check --quiet --no-error-on-unmatched-pattern

# Run optional auxiliary linters not covered by Oxlint (e.g. Tailwind or custom CI linters)
run_first_matching_script "lint" "additional lint rules" "lint:tailwind" "agent:lint:ci"

# 12.3 Typecheck
has_typecheck=0
for script_name in "agent:typecheck" "typecheck"; do
  if jq -e ".scripts[\"$script_name\"]" package.json >/dev/null 2>&1; then
    has_typecheck=1
    FAILED_STEP="vpr $script_name (typecheck)"
    run_with_spinner "Verifying types" env VP_LOG=error vpr "$script_name"
    break
  fi
done

if ((! has_typecheck)); then
  if jq -e '.devDependencies.typescript // .dependencies.typescript' package.json >/dev/null 2>&1; then
    FAILED_STEP="vpx tsc --noEmit"
    run_with_spinner "Verifying types" vpx tsc --noEmit
  fi
fi

# Dead code check
run_first_matching_script "deadcode" "dead code" "check:deadcode" "knip"

# Lightweight unit tests
run_first_matching_script "unit-test" "unit tests" "agent:verify:unit" "agent:test:unit" "test:unit"

# 13. Build commit message
if [[ "$count" -eq 1 ]]; then
  commit_title="chore(deps): update dependency ${single_pkg_summary}"
  commit_msg="${commit_title}"
else
  commit_title="chore(deps): update dependencies (${count} packages)"
  commit_msg="${commit_title}"$'\n\n'"Upgrade details:${commit_body}"
fi

# 14. Commit on sandbox branch
FAILED_STEP="git commit"
git add -A
git commit -q -m "$commit_msg"

# 15. Fast-forward merge into main and push to remote
trap - EXIT INT TERM
git checkout -q main
git merge --ff-only -q "$TEMP_BRANCH"
git branch -D -q "$TEMP_BRANCH"

if git rev-parse --abbrev-ref @{u} &>/dev/null; then
  FAILED_STEP="git push"
  run_with_spinner "Pushing to remote" git push -q origin main
  echo "Pushed: $commit_title"
else
  echo "Committed and merged: $commit_title"
fi
