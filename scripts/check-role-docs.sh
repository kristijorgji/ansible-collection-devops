#!/usr/bin/env bash
# Require a uniform role README for every standalone tasks_from file.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

for role_dir in "${repo_root}/roles"/*; do
	[[ -d "${role_dir}/tasks" ]] || continue
	role="$(basename "${role_dir}")"
	readme="${role_dir}/README.md"
	if [[ ! -f "${readme}" ]]; then
		echo "ERROR: missing ${readme}" >&2
		failed=1
		continue
	fi
	if ! grep -qF "# Role: \`kristijorgji.devops.${role}\`" "${readme}"; then
		echo "ERROR: ${readme} missing title # Role: \`kristijorgji.devops.${role}\`" >&2
		failed=1
	fi
	if ! grep -qF "## Table of contents" "${readme}"; then
		echo "ERROR: ${readme} missing ## Table of contents" >&2
		failed=1
	fi
	if ! grep -qE '^## Task files' "${readme}"; then
		echo "ERROR: ${readme} missing ## Task files" >&2
		failed=1
	fi

	for task_file in "${role_dir}/tasks"/*.yml; do
		task="$(basename "${task_file}" .yml)"
		[[ "${task}" == "main" ]] && continue
		if ! grep -qE "\\[\`${task}\`\\]\\(#${task}\\)" "${readme}"; then
			echo "ERROR: ${readme} missing TOC link for \`${task}\`" >&2
			failed=1
		fi
		if ! grep -qE "\\| \`${task}\` " "${readme}"; then
			echo "ERROR: ${readme} missing Task files table row for \`${task}\`" >&2
			failed=1
		fi
		if ! grep -qE "^## \`${task}\`" "${readme}"; then
			echo "ERROR: ${readme} missing ## \`${task}\` heading" >&2
			failed=1
		fi
		if ! grep -qE "tasks_from: ${task}" "${readme}"; then
			echo "ERROR: ${readme} missing include_role example tasks_from: ${task}" >&2
			failed=1
		fi
	done
done

if [[ "${failed}" -ne 0 ]]; then
	exit 1
fi
echo "OK: role READMEs document every standalone task"
