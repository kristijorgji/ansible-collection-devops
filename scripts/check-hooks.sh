#!/usr/bin/env bash
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0

HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
if [ "$HOOKS_PATH" != "./git_hooks" ]; then
	echo "ERROR: Git hooks not configured!"
	echo "  Expected: git config core.hooksPath = ./git_hooks"
	echo "  Actual:   git config core.hooksPath = ${HOOKS_PATH:-<not set>}"
	echo ""
	echo "Run: ./scripts/init.sh"
	ERRORS=1
fi

if [ ! -f "git_hooks/pre-commit" ]; then
	echo "ERROR: pre-commit hook not found: git_hooks/pre-commit"
	ERRORS=1
fi

if [ -f "git_hooks/pre-commit" ] && [ ! -x "git_hooks/pre-commit" ]; then
	echo "ERROR: pre-commit hook is not executable: git_hooks/pre-commit"
	ERRORS=1
fi

if [ ! -d "git_hooks/pre-commit.d" ]; then
	echo "ERROR: pre-commit.d directory not found"
	ERRORS=1
fi

if [ $ERRORS -eq 0 ]; then
	echo "Git hooks are properly configured"
	exit 0
else
	exit 1
fi
