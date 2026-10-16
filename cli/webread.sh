#!/bin/zsh
emulate -L zsh
set -euo pipefail

# Description: Fetch and extract clean, LLM-friendly Markdown or structured HTML from any webpage
# Usage: webread [options] <url>
# Example: webread https://react.dev/learn/you-might-not-need-an-effect
#          webread -s 'article' https://developer.mozilla.org
#          webread --llms https://viteplus.dev

show_help() {
  cat <<'EOF'
webread: Clean, token-efficient webpage and documentation reader for agents and humans.

Usage:
  webread [options] <url>

Options:
  -s, --selector <sel>  Extract specific DOM element using htmlq CSS selector
  -l, --llms            Probe and fetch /llms-full.txt or /llms.txt from site domain
  -r, --raw             Fetch raw HTML without Jina Reader markdown conversion
  -o, --output <file>   Save output directly to a file
  -h, --help            Show this help message and exit

Examples:
  webread https://react.dev/learn/you-might-not-need-an-effect
  webread -s 'article' https://oxc.rs
  webread --llms https://viteplus.dev
  webread https://github.com/voidzero-dev/vite-plus | rg -i 'install'
EOF
}

# 1. Parse CLI arguments
local selector=""
local mode="jina" # jina | llms | raw
local output_file=""
local target_url=""

while (($# > 0)); do
  case "$1" in
    -h | --help)
      show_help
      exit 0
      ;;
    -s | --selector)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --selector requires a CSS selector argument" >&2
        exit 1
      fi
      selector="$2"
      shift 2
      ;;
    -l | --llms)
      mode="llms"
      shift
      ;;
    -r | --raw)
      mode="raw"
      shift
      ;;
    -o | --output)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --output requires a file path argument" >&2
        exit 1
      fi
      output_file="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      show_help
      exit 1
      ;;
    *)
      if [[ -z "$target_url" ]]; then
        target_url="$1"
      else
        echo "Error: Unexpected argument $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$target_url" ]]; then
  echo "Error: URL is required" >&2
  show_help
  exit 1
fi

# Ensure URL has a scheme
if [[ "$target_url" != http://* && "$target_url" != https://* ]]; then
  target_url="https://$target_url"
fi

# 2. Dependency checks
if ! (($+commands[curl])); then
  echo "Error: curl is required but not installed." >&2
  exit 1
fi

if [[ -n "$selector" ]] && ! (($+commands[htmlq])); then
  echo "Error: htmlq is required for CSS selectors. Run: brew install htmlq" >&2
  exit 1
fi

# 3. Processing logic
fetch_content() {
  local url="$1"
  local user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  if [[ "$mode" == "llms" ]]; then
    # Extract domain root: e.g. https://viteplus.dev/foo -> https://viteplus.dev
    local origin="$(echo "$url" | awk -F/ '{print $1 "//" $3}')"
    local full_txt="$origin/llms-full.txt"
    local standard_txt="$origin/llms.txt"

    # Try /llms-full.txt first
    local http_code
    http_code=$(curl -sL -w "%{http_code}" -o /dev/null "$full_txt" || true)
    if [[ "$http_code" == "200" ]]; then
      curl -sL -A "$user_agent" "$full_txt"
      return 0
    fi

    # Try /llms.txt
    http_code=$(curl -sL -w "%{http_code}" -o /dev/null "$standard_txt" || true)
    if [[ "$http_code" == "200" ]]; then
      curl -sL -A "$user_agent" "$standard_txt"
      return 0
    fi

    echo "Notice: Neither /llms-full.txt nor /llms.txt found on $origin, falling back to Reader..." >&2
    mode="jina"
  fi

  if [[ -n "$selector" ]]; then
    # When selector is specified, fetch raw HTML and pipe through htmlq
    curl -sL -A "$user_agent" "$url" | htmlq "$selector"
    return 0
  fi

  if [[ "$mode" == "raw" ]]; then
    curl -sL -A "$user_agent" "$url"
    return 0
  fi

  # Default: Jina Reader for clean, clutter-free markdown
  local jina_url="https://r.jina.ai/$url"
  local result
  if result=$(curl -sL --max-time 15 -H "X-No-Cache: true" "$jina_url" 2>/dev/null) && [[ -n "$result" && "$result" != *"Request failed with status code"* ]]; then
    echo "$result"
  else
    # Fallback to local curl if Jina fails or times out
    echo "Notice: Jina Reader unavailable, falling back to direct fetch..." >&2
    if (($+commands[htmlq])); then
      curl -sL -A "$user_agent" "$url" | htmlq 'body'
    else
      curl -sL -A "$user_agent" "$url"
    fi
  fi
}

# 4. Output handling
if [[ -n "$output_file" ]]; then
  fetch_content "$target_url" >"$output_file"
  echo "Content saved to $output_file"
else
  fetch_content "$target_url"
fi
