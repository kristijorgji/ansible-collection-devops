#!/usr/bin/env bash
# Fail if collection role tasks use include_role (nested include_role drops --tags).
# Compose with include_tasks instead. README examples may still show include_role.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hits="$(
	grep -RIn --include='*.yml' --include='*.yaml' \
		-E 'ansible\.builtin\.include_role|^\s+include_role:' \
		"${repo_root}/roles"/*/tasks || true
)"

if [[ -n "${hits}" ]]; then
	echo "ERROR: nested include_role in collection role tasks (use include_tasks):" >&2
	echo "${hits}" >&2
	exit 1
fi

echo "OK: no include_role under roles/*/tasks/"
