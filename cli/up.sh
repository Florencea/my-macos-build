#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Description: Check and update Node.js package dependencies with pre-checks and rollback
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

# 5. Check minor updates
NCU_JSON="$(npx -y npm-check-updates@latest -p npm -t minor --install never --jsonUpgraded)"

if [[ -z "$NCU_JSON" || "$NCU_JSON" == "{}" ]]; then
  exit 0
fi

# 6. Collect update metadata
count=0
commit_body=""
single_pkg_summary=""

while IFS=$'\t' read -r pkg new_ver; do
  [[ -z "$pkg" ]] && continue
  old_ver="$(jq -r ".dependencies[\"$pkg\"] // .devDependencies[\"$pkg\"] // .peerDependencies[\"$pkg\"] // .optionalDependencies[\"$pkg\"] // \"?\"" package.json)"

  printf "  %s  %s  ->  %s\n" "$pkg" "$old_ver" "$new_ver"
  commit_body+=$'\n'"- ${pkg}: ${old_ver} -> ${new_ver}"
  single_pkg_summary="${pkg} ${old_ver} -> ${new_ver}"
  ((count++))
done < <(echo "$NCU_JSON" | jq -r 'to_entries | .[] | "\(.key)\t\(.value)"')

# 7. Create sandbox branch and register rollback trap
TEMP_BRANCH="chore/deps-upgrade-$(date +%s)"
git checkout -q -b "$TEMP_BRANCH"

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "Error: Pre-checks failed. Rolling back changes to 'main'..." >&2
    git checkout -q main
    git branch -D "$TEMP_BRANCH" >/dev/null 2>&1 || true
    npm ci --quiet >/dev/null 2>&1 || true
  fi
  exit $exit_code
}
trap cleanup EXIT INT TERM

# 8. Update package.json and lockfile
npx -y npm-check-updates -u -t minor >/dev/null
npm install --package-lock-only --ignore-scripts --loglevel error >/dev/null

# 9. Sync local dependencies for verification
npm ci --quiet

# 10. Run project pre-checks
run_first_matching_script() {
  for script_name in "$@"; do
    if jq -e ".scripts[\"$script_name\"]" package.json >/dev/null 2>&1; then
      npm run --silent "$script_name"
      return 0
    fi
  done
  return 1
}

# Auto-format and check formatting
run_first_matching_script "format" || true
run_first_matching_script "format:check" || true

# Typecheck
if ! run_first_matching_script "agent:typecheck" "typecheck"; then
  if jq -e '.devDependencies.typescript // .dependencies.typescript' package.json >/dev/null 2>&1; then
    npx tsc --noEmit
  fi
fi

# Lint
run_first_matching_script "agent:lint" "lint" || true

# Dead code check
run_first_matching_script "check:deadcode" "knip" || true

# Lightweight unit tests
run_first_matching_script "agent:test:unit" "test:unit" || true

# 11. Build commit message
if [[ "$count" -eq 1 ]]; then
  commit_title="chore(deps): update dependency ${single_pkg_summary}"
  commit_msg="${commit_title}"
else
  commit_title="chore(deps): update dependencies (${count} packages)"
  commit_msg="${commit_title}"$'\n\n'"Upgrade details:${commit_body}"
fi

# 12. Commit on sandbox branch
git add -A
git commit -q -m "$commit_msg"

# 13. Fast-forward merge into main and push
trap - EXIT INT TERM
git checkout -q main
git merge --ff-only -q "$TEMP_BRANCH"
git branch -D -q "$TEMP_BRANCH"
git push -q origin main
