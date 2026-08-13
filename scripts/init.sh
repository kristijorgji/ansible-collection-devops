#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
echo "Registering git hooks (core.hooksPath=./git_hooks)"
git config core.hooksPath ./git_hooks
chmod +x git_hooks/pre-commit git_hooks/pre-commit.d/* 2>/dev/null || true
echo "Done. Run: make verify-hooks"
