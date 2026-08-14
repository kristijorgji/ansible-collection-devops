# kristijorgji.devops

Public Ansible collection of reusable **devops build and transfer** helpers.
Install the whole collection; call only the roles you need.

## Install

```yaml
# collections/requirements.yml
collections:
  - name: https://github.com/kristijorgji/ansible-collection-devops.git
    type: git
    version: v0.1.2
```

```shell
ansible-galaxy collection install -r collections/requirements.yml
```

## Lint / format / hooks

```shell
./scripts/init.sh          # git config core.hooksPath=./git_hooks
make lint                  # ansible-lint + markdownlint
make fix                   # prettier YAML/MD + markdownlint --fix
make verify-hooks
```

Requires Docker for lint/fix targets and pre-commit hooks.

## Roles

| Role                           | Purpose                                                       |
| ------------------------------ | ------------------------------------------------------------- |
| `kristijorgji.devops.nodejs`   | nvm/Docker builds for pnpm/yarn/npm; `pnpm_build` convenience |
| `kristijorgji.devops.transfer` | Rsync a local tree to a remote server path                    |

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

### Generic yarn (native)

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.nodejs
    tasks_from: nvm_exec
  vars:
    node_package_manager: yarn
    node_command: "yarn build"
    # ... projectName, codePath, delegate_build_to_host, node_version
```

### Yarn install script (Mac/Ubuntu)

```shell
S_NODE_VERSION=22.16.0 bash \
  collections/ansible_collections/kristijorgji/devops/roles/nodejs/files/yarn_install.sh \
  linux/amd64
```

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

See each role’s `README.md` for variables.

## Requirements

- Ansible Core ≥ 2.15
- For `transfer`: `ansible.posix` collection
- For native Node builds: [nvm](https://github.com/nvm-sh/nvm) on the build host (Homebrew or `~/.nvm`)
