#!/usr/bin/env bash
# Source nvm on macOS (Homebrew) or Linux/Ubuntu (curl install / NVM_DIR).
# Usage: . /path/to/nvm_init.sh
# Native Windows (Git Bash/MSYS) is not supported — use WSL or a Docker builder.
set -euo pipefail

uname_s="$(uname -s 2>/dev/null || true)"
case "$uname_s" in
  MINGW*|MSYS*|CYGWIN*)
    echo "nvm_init.sh: native Windows shells are unsupported; use WSL or Docker builder" >&2
    exit 1
    ;;
esac

if [ -f /opt/homebrew/opt/nvm/nvm.sh ]; then
  # shellcheck source=/dev/null
  . /opt/homebrew/opt/nvm/nvm.sh
elif [ -f /usr/local/opt/nvm/nvm.sh ]; then
  # shellcheck source=/dev/null
  . /usr/local/opt/nvm/nvm.sh
elif [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
  # shellcheck source=/dev/null
  . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
else
  echo "nvm.sh not found (tried Homebrew paths and \${HOME}/.nvm / \$NVM_DIR)" >&2
  exit 1
fi
