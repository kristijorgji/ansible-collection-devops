# Role: `kristijorgji.devops.sops`

Load host/group SOPS secrets from `environments/*/secrets/` into play vars.

---

## Table of contents

- [Task files](#task-files)
- [`load_secrets`](#load_secrets)

---

## Task files

| File           | Purpose                                              |
| -------------- | ---------------------------------------------------- |
| `load_secrets` | Find and decrypt matching `*.sops.yml` for this host |

Requires the `community.sops` collection. On ansible-core 2.21+ sets
`return_method: vars-only`. Older cores omit it.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `load_secrets`

Required: `environments_dir`, `env`, `sops_age_key_file`, `sops_config_path`.

Scans `environments/common/secrets/` and `environments/<env>/secrets/` for `*.sops.yml`.
Loads a file when the path contains `/secrets/<group>/` for a non-`all` group in
`group_names`, or is a direct child of `secrets/all/`.

Not for project `vars/*.sops.yml`. Never place `*.sops.yml` under `group_vars/` or
`host_vars/`. `stat` / `find` run on localhost with `become: false`.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.sops
    tasks_from: load_secrets
    apply:
      tags: always
  tags: always
```
