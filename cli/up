#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Description: Check and update Node.js package dependencies with multi-commit workflow
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

# 3. Check working directory status
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working directory is not clean. Please commit or stash your changes first." >&2
  exit 1
fi

# 4. Check minor updates
NCU_JSON="$(npx -y npm-check-updates@latest -p npm -t minor --install never --jsonUpgraded)"

if [[ -z "$NCU_JSON" || "$NCU_JSON" == "{}" ]]; then
  exit 0
fi

# 5. Sync repository
if git rev-parse --abbrev-ref @{u} &>/dev/null; then
  git pull --ff-only --quiet || {
    echo "Error: Cannot fast-forward with remote. Please sync your branch first." >&2
    exit 1
  }
fi

# Store upgrades
declare -A upgrades

# Read upgrades into associative array
while IFS=$'\t' read -r pkg ver; do
  [[ -z "$pkg" ]] && continue
  upgrades["$pkg"]="$ver"
done < <(echo "$NCU_JSON" | jq -r 'to_entries | .[] | "\(.key)\t\(.value)"')

# Define grouping rules
get_group_key() {
  local pkg="${1:-}"
  if [[ "$pkg" == vitest* || "$pkg" == @vitest/* ]]; then
    echo "vitest"
  elif [[ "$pkg" == "react" || "$pkg" == "react-dom" || "$pkg" == @types/react || "$pkg" == @types/react-dom ]]; then
    echo "react"
  elif [[ "$pkg" == eslint* || "$pkg" == @eslint/* || "$pkg" == typescript-eslint || "$pkg" == @typescript-eslint/* ]]; then
    echo "eslint"
  elif [[ "$pkg" == "playwright" || "$pkg" == @playwright/* ]]; then
    echo "playwright"
  elif [[ "$pkg" == @tanstack/* ]]; then
    echo "tanstack"
  elif [[ "$pkg" == "tailwindcss" || "$pkg" == @tailwindcss/* ]]; then
    echo "tailwind"
  elif [[ "$pkg" == "prettier" || "$pkg" == prettier-plugin-* || "$pkg" == @prettier/* ]]; then
    echo "prettier"
  elif [[ "$pkg" == "drizzle" || "$pkg" == drizzle-* || "$pkg" == @drizzle/* ]]; then
    echo "drizzle"
  elif [[ "$pkg" == "hono" || "$pkg" == @hono/* ]]; then
    echo "hono"
  elif [[ "$pkg" == "antd" || "$pkg" == @ant-design/* ]]; then
    echo "antd"
  elif [[ "$pkg" == i18next* || "$pkg" == "react-i18next" ]]; then
    echo "i18next"
  elif [[ "$pkg" == "electron" || "$pkg" == electron-* || "$pkg" == @electron/* ]]; then
    echo "electron"
  elif [[ "$pkg" == vite || "$pkg" == @vitejs/* || "$pkg" == vite-plugin-* ]]; then
    echo "vite"
  else
    echo "indiv-$pkg"
  fi
}

# Group packages to resolve conflicts
declare -A groups
for pkg in "${!upgrades[@]}"; do
  grp="$(get_group_key "$pkg")"
  ver="${upgrades[$pkg]}"
  if [[ -z "${groups[$grp]:-}" ]]; then
    groups["$grp"]="$pkg@$ver"
  else
    groups["$grp"]="${groups[$grp]} $pkg@$ver"
  fi
done

# Sort group keys for deterministic commit ordering
readarray -t sorted_groups < <(printf '%s\n' "${!groups[@]}" | sort)

# Install and commit groups
for grp in "${sorted_groups[@]}"; do
  pkgs_in_group="${groups[$grp]}"

  # Process upgrades: print transitions and build commit message
  commit_msg_parts=""
  for item in $pkgs_in_group; do
    name="${item%@*}"
    new_ver="${item##*@}"
    old_ver="$(jq -r ".dependencies[\"$name\"] // .devDependencies[\"$name\"] // .peerDependencies[\"$name\"] // .optionalDependencies[\"$name\"] // \"?\"" package.json)"

    # Print transition log
    printf "  %s  %s  ->  %s\n" "$name" "$old_ver" "$new_ver"

    # Build plaintext commit message parts
    part="$name $old_ver → $new_ver"
    if [[ -z "$commit_msg_parts" ]]; then
      commit_msg_parts="$part"
    else
      commit_msg_parts="$commit_msg_parts, $part"
    fi
  done

  # Install group and write lockfile
  if npm install $pkgs_in_group --package-lock-only --ignore-scripts --loglevel error >/dev/null; then
    git add package.json package-lock.json
    git commit -q -m "chore(deps): update dependency $commit_msg_parts"
    git push -q
  else
    echo "Warning: Failed to install group [$grp] ($pkgs_in_group). Skipping..." >&2
    # Rollback modifications on failure
    git checkout -- package.json package-lock.json
  fi
done

# 6. Sync lockfile
# Ensure lockfile integrity
npm install --package-lock-only --ignore-scripts --loglevel error >/dev/null

if [[ -n "$(git status --short package-lock.json)" ]]; then
  git add package-lock.json
  git commit -q -m "chore(deps): sync and clean lockfile"
  git push -q
fi

# 7. Reinstall node_modules
npm ci
