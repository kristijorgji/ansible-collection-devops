#!/usr/bin/env bash
# Install yarn deps via nvm for an optional target platform (Mac/Ubuntu/Linux).
# Example: S_NODE_VERSION=22.16.0 bash yarn_install.sh linux/amd64 prod
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${S_NODE_VERSION:-}" ]; then
  echo "Missing required environment variable S_NODE_VERSION" >&2
  exit 1
fi

uname_s="$(uname -s 2>/dev/null || true)"
case "$uname_s" in
  MINGW*|MSYS*|CYGWIN*)
    echo "yarn_install.sh: native Windows shells are unsupported; use WSL or Docker builder" >&2
    exit 1
    ;;
esac

platform=""
prod=""
if [ $# -eq 0 ]; then
  echo "No platform supplied. Will install for the current platform."
elif [ $# -eq 1 ]; then
  platform=$1
elif [ $# -ge 2 ]; then
  platform=$1
  prod="1"
fi

if [ -n "$platform" ]; then
  echo "Platform is set as $platform"
  # shellcheck disable=SC1090
  eval "$(bash "${SCRIPT_DIR}/npm_cross_platform_env.sh" "$platform")"
fi

yarn_flags=()
if [ "$prod" = "1" ]; then
  yarn_flags+=(--production)
fi

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/nvm_init.sh"

echo "nvm install $S_NODE_VERSION (no-op if already present)"
nvm install "$S_NODE_VERSION"
echo "nvm use $S_NODE_VERSION"
nvm use "$S_NODE_VERSION"
command -v yarn >/dev/null || {
  echo "yarn not found for Node $S_NODE_VERSION; install with: nvm use $S_NODE_VERSION && npm install -g yarn" >&2
  exit 1
}

echo "yarn install ${yarn_flags[*]:-}"
yarn install "${yarn_flags[@]}"
