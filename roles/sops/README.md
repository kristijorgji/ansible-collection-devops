# Role: `kristijorgji.devops.sops`

Load host/group SOPS secrets from `environments/*/secrets/` into play vars.

---

## Table of contents

- [Task files](#task-files-tasks_from)
- [Variables](#variables)
- [Path matching](#path-matching)
- [Example](#example)

---

## Task files (`tasks_from`)

| File           | Purpose                                              |
| -------------- | ---------------------------------------------------- |
| `load_secrets` | Find and decrypt matching `*.sops.yml` for this host |

Requires the `community.sops` collection. Uses `return_method: vars-only` so values are
real host vars (not only `ansible_facts`).

---

## Variables

| Variable             | Required | Description                                      |
| -------------------- | -------- | ------------------------------------------------ |
| `environments_dir`   | yes      | Path to the consumer `environments/` tree        |
| `env`                | yes      | Environment name (e.g. `production`)             |
| `sops_age_key_file`  | yes      | Path to age private key for decryption           |
| `sops_config_path`   | yes      | Path to `.sops.yaml` (via `SOPS_CONFIG_PATH`)    |

---

## Path matching

Scans `environments/common/secrets/` and `environments/<env>/secrets/` recursively for
`*.sops.yml`, then loads a file when:

- the path contains `/secrets/<group>/` for a non-`all` group in `group_names`, or
- the path is a direct child of `secrets/all/` (every host is in `all`)

Not for project secrets under `projects/*/vars/` — use the consumer’s project-vars loader.
Never place `*.sops.yml` under `group_vars/` or `host_vars/` (Ansible would load ciphertext).

`stat` / `find` always run on localhost with `become: false`.

---

## Example

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.sops
    tasks_from: load_secrets
  tags: always
```
