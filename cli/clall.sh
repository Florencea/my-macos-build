#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Description: Clone all GitHub Repositories
# Usage: clall [GITHUB_ACCESS_TOKEN]
# Example: clall ghp_000000000000000000000000000000000000

# 1. Check arguments
TOKEN="${1:-}"
if [[ -z "$TOKEN" ]]; then
  echo "clall: Clone all GitHub Repositories" >&2
  echo "Usage: clall [GITHUB_ACCESS_TOKEN]" >&2
  echo "       clall ghp_000000000000000000000000000000000000" >&2
  exit 1
fi

# 2. Check required tools
for cmd in curl jq git; do
  command -v "$cmd" &>/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

# 3. Fetch user repositories
readarray -t REPOS < <(curl -s \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/user/repos?type=owner&per_page=100" | jq -r '.[].ssh_url')

REPO_LIST_LEN=${#REPOS[@]}
if [[ $REPO_LIST_LEN -eq 0 ]]; then
  exit 0
fi

# 4. Clone repositories in parallel
TMPDIR="$(mktemp -d -t "$(basename "$0")")"
trap 'rm -rf "$TMPDIR"' EXIT

for REPO in "${REPOS[@]}"; do
  REPO_NAME="$(basename "$REPO" .git)"
  (
    if git clone --quiet "$REPO"; then
      touch "$TMPDIR/$REPO_NAME"
      FINISHED=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
      printf "Clone [%s/%s] %s ok\n" "$FINISHED" "$REPO_LIST_LEN" "$REPO_NAME"
    fi
  ) &
done
wait
