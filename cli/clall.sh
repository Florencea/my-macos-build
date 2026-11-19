#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
clall: Clone all GitHub repositories for the authenticated user
Usage: clall [GITHUB_ACCESS_TOKEN]
       GITHUB_TOKEN=... clall
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

TOKEN="${1:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
if [[ -z "$TOKEN" ]]; then
  usage >&2
  exit 1
fi

if printf '%s' "$TOKEN" | grep -iq '^op://'; then
  echo "Error: Unresolved 1Password reference; run via 'op run'" >&2
  exit 1
fi

REPOS=()
PAGE=1
while :; do
  RESP="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user/repos?type=owner&per_page=100&page=$PAGE")"

  PAGE_COUNT=0
  while IFS= read -r URL; do
    if [[ -n "$URL" ]]; then
      REPOS+=("$URL")
    fi
    PAGE_COUNT=$((PAGE_COUNT + 1))
  done < <(printf '%s\n' "$RESP" | jq -r '.[] | select(.ssh_url != null and .ssh_url != "") | .ssh_url')

  if ((PAGE_COUNT < 100)); then
    break
  fi
  PAGE=$((PAGE + 1))
done

TOTAL=${#REPOS[@]}
if ((TOTAL == 0)); then
  exit 0
fi

TMPDIR_COUNT="$(mktemp -d -t clall.XXXXXX)"
trap 'rm -rf "${TMPDIR_COUNT:-}"' EXIT

for REPO in "${REPOS[@]}"; do
  REPO_NAME="$(basename "$REPO" .git)"
  if [[ -d "$REPO_NAME" ]]; then
    printf "Skip %s (already exists)\n" "$REPO_NAME"
    continue
  fi
  (
    if GIT_TERMINAL_PROMPT=0 git clone --quiet "$REPO"; then
      touch "$TMPDIR_COUNT/$REPO_NAME"
      FINISHED="$(find "$TMPDIR_COUNT" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
      printf "Clone [%s/%s] %s ok\n" "$FINISHED" "$TOTAL" "$REPO_NAME"
    fi
  ) &
done
wait
