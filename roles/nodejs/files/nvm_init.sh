#!/usr/bin/env bash
# Source nvm on macOS (Homebrew) or Linux (curl install).
# Usage: . /path/to/nvm_init.sh
set -euo pipefail

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
  echo "nvm.sh not found (tried Homebrew paths and \${HOME}/.nvm)" >&2
  exit 1
fi
