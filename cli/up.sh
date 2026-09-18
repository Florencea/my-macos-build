#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Description: Check and update Node.js package dependencies with clean spinner feedback
# Usage: up
# Example: up

# 1. Check required tools
for cmd in git npm npx jq; do
  command -v "$cmd" &>/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

# 2. Check project files
[[ -f "package.json" ]] || {
  echo "Error: File package.json does not exist" >&2
  exit 1
}
[[ -f "package-lock.json" ]] || {
  echo "Error: File package-lock.json does not exist" >&2
  exit 1
}

# 3. Check git status and branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "Error: Current branch is not 'main' ($CURRENT_BRANCH)" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working directory is not clean. Please commit or stash your changes first." >&2
  exit 1
fi

# 4. Sync repository
if git rev-parse --abbrev-ref @{u} &>/dev/null; then
  git pull --ff-only --quiet || {
    echo "Error: Cannot fast-forward with remote. Please sync your branch first." >&2
    exit 1
  }
fi

# 5. Spinner helper for time-consuming steps
run_with_spinner() {
  local msg="$1"
  shift
  local pid
  local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0

  # Run target command in background with all noisy output muted
  "$@" &>/dev/null &
  pid=$!

  # Show dynamic spinner while command is running
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  %s %s..." "${spin[i]}" "$msg"
    i=$(((i + 1) % ${#spin[@]}))
    sleep 0.08
  done

  # Clear line immediately upon completion
  printf "\r\033[K"

  wait "$pid"
}

# 6. Check minor updates
NCU_JSON="$(npx -y npm-check-updates@latest -p npm -t minor --install never --jsonUpgraded)"

if [[ -z "$NCU_JSON" || "$NCU_JSON" == "{}" ]]; then
  exit 0
fi

# 7. Parse updates safely
count=0
commit_body=""
single_pkg_summary=""

RAW_TARGETS="$(echo "$NCU_JSON" | jq -r 'to_entries | .[] | "\(.key)\t\(.value)"')"

while IFS=$'\t' read -r pkg new_ver; do
  [[ -z "$pkg" ]] && continue
  old_ver="$(jq -r ".dependencies[\"$pkg\"] // .devDependencies[\"$pkg\"] // .peerDependencies[\"$pkg\"] // .optionalDependencies[\"$pkg\"] // \"?\"" package.json)"

  printf "  %s  %s  ->  %s\n" "$pkg" "$old_ver" "$new_ver"
  commit_body+=$'\n'"- ${pkg}: ${old_ver} -> ${new_ver}"
  single_pkg_summary="${pkg} ${old_ver} -> ${new_ver}"
  count=$((count + 1))
done <<<"$RAW_TARGETS"

# 8. Create sandbox branch and register rollback trap
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
    npm ci --quiet &>/dev/null || true
  fi
  exit "$orig_exit"
}
trap cleanup EXIT INT TERM

# 9. Update package.json and lockfile
FAILED_STEP="npx npm-check-updates"
run_with_spinner "Updating packages" npx -y npm-check-updates -u -t minor --loglevel silent

FAILED_STEP="npm install (lockfile update)"
run_with_spinner "Writing lockfile" npm install --package-lock-only --ignore-scripts --loglevel error

# 10. Sync local dependencies
FAILED_STEP="npm ci"
run_with_spinner "Syncing dependencies (npm ci)" npm ci --quiet

# 11. Run project pre-checks
run_first_matching_script() {
  local category="$1"
  local display_name="$2"
  shift 2
  for script_name in "$@"; do
    if jq -e ".scripts[\"$script_name\"]" package.json >/dev/null 2>&1; then
      FAILED_STEP="npm run $script_name ($category)"
      run_with_spinner "Verifying $display_name" npm run --silent "$script_name"
      return 0
    fi
  done
  return 1
}

# Auto-format and format-check
run_first_matching_script "format" "format" "format" || true
run_first_matching_script "format-check" "formatting rules" "format:check" || true

# Typecheck
if ! run_first_matching_script "typecheck" "types" "agent:typecheck" "typecheck"; then
  if jq -e '.devDependencies.typescript // .dependencies.typescript' package.json >/dev/null 2>&1; then
    FAILED_STEP="npx tsc --noEmit"
    run_with_spinner "Verifying types" npx tsc --noEmit
  fi
fi

# Lint
run_first_matching_script "lint" "linter" "agent:lint" "lint" || true

# Dead code check
run_first_matching_script "deadcode" "dead code" "check:deadcode" "knip" || true

# Lightweight unit tests
run_first_matching_script "unit-test" "unit tests" "agent:test:unit" "test:unit" || true

# 12. Build commit message
if [[ "$count" -eq 1 ]]; then
  commit_title="chore(deps): update dependency ${single_pkg_summary}"
  commit_msg="${commit_title}"
else
  commit_title="chore(deps): update dependencies (${count} packages)"
  commit_msg="${commit_title}"$'\n\n'"Upgrade details:${commit_body}"
fi

# 13. Commit on sandbox branch
FAILED_STEP="git commit"
git add -A
git commit -q -m "$commit_msg"

# 14. Fast-forward merge into main and push
FAILED_STEP="git merge & push"
run_with_spinner "Pushing to remote" git push -q origin "$TEMP_BRANCH:main"

trap - EXIT INT TERM
git checkout -q main
git merge --ff-only -q "$TEMP_BRANCH"
git branch -D -q "$TEMP_BRANCH"

echo "Pushed: $commit_title"
