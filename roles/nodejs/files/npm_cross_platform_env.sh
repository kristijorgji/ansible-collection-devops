#!/usr/bin/env bash
# Emit shell exports so npm, yarn, and pnpm fetch optional native deps for the
# deploy target platform (e.g. linux x64 binaries when installing on macOS).
# Usage: eval "$(bash npm_cross_platform_env.sh linux/amd64)" before install/build.
set -euo pipefail

platform="${1:-}"
if [ -z "$platform" ]; then
  exit 0
fi

case "$platform" in
  linux/amd64)
    echo "export npm_config_arch=x64"
    echo "export npm_config_platform=linux"
    ;;
  linux/arm64)
    echo "export npm_config_arch=arm64"
    echo "export npm_config_platform=linux"
    ;;
  *)
    echo "unknown platform $platform" >&2
    exit 10
    ;;
esac
