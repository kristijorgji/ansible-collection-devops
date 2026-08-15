# kristijorgji.devops

Public Ansible collection of reusable **devops** helpers: Node builds, rsync transfer,
deploy skip/markers, GitHub SSH + clone, and SOPS host-secret loading.

Install the whole collection; call only the roles / `tasks_from` you need.

---

## Table of contents

- [Install](#install)
- [Lint / format / hooks](#lint--format--hooks)
- [Roles](#roles)
- [Quick examples](#quick-examples)
- [Requirements](#requirements)

---

## Install

```yaml
# collections/requirements.yml
collections:
  - name: https://github.com/kristijorgji/ansible-collection-devops.git
    type: git
    version: v0.3.0
```

```shell
ansible-galaxy collection install -r collections/requirements.yml
```

---

## Lint / format / hooks

```shell
./scripts/init.sh          # git config core.hooksPath=./git_hooks
make lint                  # ansible-lint + markdownlint
make fix                   # prettier YAML/MD + markdownlint --fix
make verify-hooks
```

Requires Docker for lint/fix targets and pre-commit hooks.

---

## Roles

| Role                           | Purpose                                                                      |
| ------------------------------ | ---------------------------------------------------------------------------- |
| `kristijorgji.devops.nodejs`   | nvm/Docker builds; server `pnpm_server_install` / `nvm_server_exec`          |
| `kristijorgji.devops.transfer` | Rsync one tree, path list, prune+rsync, bind-mount-safe wipe                 |
| `kristijorgji.devops.deploy`   | Deploy skip gate (`check_needed`) and commit marker                          |
| `kristijorgji.devops.git`      | SSH prepare, multi-project build hosts, shallow clone + `commitHash`         |
| `kristijorgji.devops.sops`     | Load host/group `*.sops.yml` from `environments/*/secrets/` (`vars-only`)    |

See each role’s `README.md` for full `tasks_from` tables and variables.

---

## Quick examples

### Preferred: `pnpm_build` (native or docker)

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: pnpm_build
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
  vars:
    projectName: my_app
    codePath: /path/to/app
    delegate_build_to_host: 127.0.0.1
    dockerBuilderImage: "pnpm-builder:22.16.0"
    node_build_executor: native
    node_command: "pnpm build"
```

Privilege escalation uses play/site `become_in_build_machine` (or optional
`node_become`) and is always off when `delegate_build_to_host` is `127.0.0.1`.
Do not reassign `become_in_build_machine` inside `include_role` vars.

### GitHub SSH on one build host

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.git
    tasks_from: prepare_ssh
    apply:
      delegate_to: "{{ delegate_build_to_host }}"
      become: "{{ become_in_build_machine if delegate_build_to_host != '127.0.0.1' else false }}"
  vars:
    ssh_config_template_path: "{{ environments_dir }}/common/templates/ssh_config.j2"
```

### GitHub SSH on every multi-project build host

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.git
    tasks_from: prepare_ssh_for_projects
# post_tasks:
- ansible.builtin.include_role:
    name: kristijorgji.devops.git
    tasks_from: cleanup_ssh_for_projects
```

### Load host/group SOPS secrets

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.sops
    tasks_from: load_secrets
  tags: always
```

Requires `environments_dir`, `env`, `sops_age_key_file`, `sops_config_path`. Uses
`return_method: vars-only` (real host vars). Not for project `vars/*.sops.yml`.

### Rsync build output to a server

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.transfer
    tasks_from: rsync_local_to_server
  vars:
    projectName: my_app
    codePath: /path/to/app
    serverCodePath: /var/www/app
    rsync_src: /path/to/app/build/
    rsync_dest_suffix: /build
```

### Yarn install script (Mac/Ubuntu)

```shell
S_NODE_VERSION=22.16.0 bash \
  collections/ansible_collections/kristijorgji/devops/roles/nodejs/files/yarn_install.sh \
  linux/amd64
```

---

## Requirements

- Ansible Core ≥ 2.15 (2.19+ recommended; `sops` `vars-only` targets 2.19 / 2.21+)
- For `transfer`: `ansible.posix`
- For `sops`: `community.sops`
- For native Node builds: [nvm](https://github.com/nvm-sh/nvm) on the build host (Homebrew or `~/.nvm`)
