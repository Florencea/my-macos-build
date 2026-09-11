#!/usr/bin/env bash

# Block commits initiated by AI agents
if [ "${ANTIGRAVITY_AGENT:-}" = "1" ]; then
  echo -e "\n\033[1;31m[ERROR] Commit rejected: AI agents are not permitted to commit directly.\033[0m"
  echo -e "Please stage changes with 'git add' and output the commit command for manual execution.\n"
  exit 1
fi
