#!/usr/bin/env bash
# Build this collection locally, then run one Molecule scenario.
set -euo pipefail

ROLE="${1:-}"
if [[ -z "${ROLE}" ]]; then
	echo "usage: $0 ROLE" >&2
	echo "example: $0 docker" >&2
	exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

SCENARIO_DIR="molecule/${ROLE}"
if [[ ! -d "${SCENARIO_DIR}" ]]; then
	echo "ERROR: missing Molecule scenario directory: ${SCENARIO_DIR}" >&2
	exit 1
fi

mkdir -p .ansible/dist .ansible/collections
rm -f .ansible/dist/*.tar.gz

echo "################################################################################"
echo "# ansible-galaxy collection build"
echo "################################################################################"
ansible-galaxy collection build --force --output-path .ansible/dist

shopt -s nullglob
artifacts=(.ansible/dist/*.tar.gz)
shopt -u nullglob
if [[ ${#artifacts[@]} -ne 1 ]]; then
	echo "ERROR: expected exactly one collection artifact in .ansible/dist" >&2
	ls -la .ansible/dist >&2 || true
	exit 1
fi

echo "################################################################################"
echo "# ansible-galaxy collection install ${artifacts[0]}"
echo "################################################################################"
ansible-galaxy collection install --force -p .ansible/collections "${artifacts[0]}"

if [[ -f molecule/requirements.yml ]]; then
	echo "################################################################################"
	echo "# molecule collection requirements"
	echo "################################################################################"
	ansible-galaxy collection install -r molecule/requirements.yml -p .ansible/collections
fi

export ANSIBLE_HOME="${REPO_ROOT}/.ansible"
export ANSIBLE_COLLECTIONS_PATH="${REPO_ROOT}/.ansible/collections"
unset ANSIBLE_COLLECTIONS_PATHS

echo "################################################################################"
echo "# molecule test -s ${ROLE}"
echo "################################################################################"
molecule test -s "${ROLE}"
