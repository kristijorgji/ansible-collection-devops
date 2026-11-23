# kristijorgji.devops

Public Ansible collection of reusable **devops** helpers: Node builds, rsync transfer,
deploy skip/markers, GitHub SSH + clone, SOPS host-secret loading, SSM cache/fetch,
S3 prefix janitor, Docker CE + Compose, Certbot, GeoIP, AWS CLI, logrotate, and ops-notify.

Install the whole collection; call only the roles / `tasks_from` you need.

---

## Table of contents

- [Install](#install)
- [Lint / format / hooks](#lint--format--hooks)
- [Testing / CI](#testing--ci)
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
    version: v0.8.1
```

```shell
ansible-galaxy collection install -r collections/requirements.yml
```

---

## Lint / format / hooks

```shell
./scripts/init.sh          # git config core.hooksPath=./git_hooks
make lint                  # ansible-lint + markdownlint + role checks
make fix                   # prettier YAML/MD + markdownlint --fix
make verify-hooks
```

Requires Docker for ansible-lint / markdownlint / prettier. Role-doc and
`include_role` checks are local scripts (also run from pre-commit).

When the play uses `--tags`, put matching tags in `apply.tags` on consumer
`include_role`. Collection role tasks must use `include_tasks` (not nested
`include_role`) so those tags reach inner steps.

---

## Testing / CI

Requires Docker (for lint images and Molecule) plus a venv with
[`requirements-dev.txt`](requirements-dev.txt).

```shell
python3.13 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
make lint                  # ansible-lint, markdownlint, role checks, shellcheck
make test-role ROLE=docker # one Molecule scenario (amd64 and arm64 images)
make test                  # every molecule/*/ scenario
```

GitHub Actions (`.github/workflows/ci.yml`) runs `lint`, `build`, and Molecule on
`ubuntu-24.04` and `ubuntu-24.04-arm` with ansible-core 2.22.0 (Python 3.13), plus
Molecule on amd64 with ansible-core 2.19.10. The `ci-ok` job is the required status
check.

Dependabot PRs auto-squash-merge after `ci-ok` (see
`.github/workflows/dependabot-auto-merge.yml`). GitHub Actions updates are grouped
into one PR; pip minor/patch updates are grouped, majors stay solo. A major
ansible-core bump may need a matching Python bump (2.22 requires Python 3.13).
Keep repo **Allow auto-merge** and Actions workflow permissions **Read and write**
enabled so that workflow can request squash auto-merge.

Molecule platforms: Ubuntu 22.04/24.04/26.04 and Debian 12/13 (`geerlingguy` systemd
images), privileged, with anonymous `/var/lib/docker` and `/var/lib/containerd`
volumes.

Pushing a `v*` tag runs `.github/workflows/release.yml`: the tag (without `v`) must
equal `galaxy.yml` `version`, then a GitHub Release is created with the collection
tarball.

---

## Roles

| Role                                   | Purpose                                                              |
| -------------------------------------- | -------------------------------------------------------------------- |
| `kristijorgji.devops.nodejs`           | nvm/Docker builds; server `pnpm_server_install` / `nvm_server_exec`  |
| `kristijorgji.devops.transfer`         | Rsync one tree, path list, prune+rsync, bind-mount-safe wipe         |
| `kristijorgji.devops.deploy`           | Deploy skip gate (`check_needed`) and commit marker                  |
| `kristijorgji.devops.git`              | SSH prepare, multi-project build hosts, shallow clone + `commitHash` |
| `kristijorgji.devops.sops`             | Load host/group `*.sops.yml` from `environments/*/secrets/`          |
| `kristijorgji.devops.ssm`              | Optional `ssm_cache.yml` include + live Parameter Store fetch        |
| `kristijorgji.devops.s3`               | Keep-last-N janitor for versioned S3 key prefixes                    |
| `kristijorgji.devops.docker`           | Docker CE (amd64/arm64) + Compose plugin and/or standalone binary    |
| `kristijorgji.devops.compose_watchdog` | Cron `compose up -d` watchdog with optional hooks                    |
| `kristijorgji.devops.certbot`          | Certbot install, HTTP-01 issuance, renewal hooks                     |
| `kristijorgji.devops.geoip`            | GeoLite2 via geoipupdate or a one-shot URL                           |
| `kristijorgji.devops.awscli`           | AWS CLI v2 zip bundle (amd64/arm64)                                  |
| `kristijorgji.devops.logrotate`        | `/etc/logrotate.d` entries with overlapping-glob validation          |
| `kristijorgji.devops.ops_notify`       | Host cron notifier (SMTPS and/or SendGrid, webhooks, healthchecks)   |

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
      tags:
        - prepare-git
      delegate_to: "{{ delegate_build_to_host }}"
      become: "{{ become_in_build_machine if delegate_build_to_host != '127.0.0.1' else false }}"
  vars:
    ssh_config_template_path: "{{ environments_dir }}/common/templates/ssh_config.j2"
  tags:
    - prepare-git
```

### Load host/group SOPS secrets

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.sops
    tasks_from: load_secrets
    apply:
      tags: always
  tags: always
```

### SSM cache + live fetch

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.ssm
    tasks_from: include_cache
    apply:
      tags: always
  tags: always
- ansible.builtin.include_role:
    name: kristijorgji.devops.ssm
    tasks_from: read_from_definitions
```

Requires `amazon.aws` and controller `boto3`. On macOS export
`OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`.

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

### S3 prefix janitor

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.s3
    tasks_from: janitor_prefixes
    apply:
      delegate_to: 127.0.0.1
      become: false
  vars:
    s3_janitor_bucket: my-web-assets
    s3_janitor_prefix: web/
    s3_janitor_live_id: "{{ commitHash }}"
    s3_janitor_aws_access_key_id: "{{ deploy_access_key_id }}"
    s3_janitor_aws_secret_access_key: "{{ deploy_secret_access_key }}"
```

Requires controller `boto3`. See the role README for `history.json` bootstrap and keep/delete
policy.

### Install Docker engine

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.docker
    apply:
      tags: docker
  vars:
    docker_users:
      - "{{ ansible_user }}"
    docker_compose_install: both
  tags: docker
```

Or `roles: [kristijorgji.devops.docker]`. See the role README for version pins,
`docker_install_source: distro`, and `docker_skip`.

### Yarn install script (Mac/Ubuntu)

```shell
S_NODE_VERSION=22.16.0 bash \
  collections/ansible_collections/kristijorgji/devops/roles/nodejs/files/yarn_install.sh \
  linux/amd64
```

---

## Requirements

- Ansible Core ≥ 2.15 (2.19+ recommended; `sops` uses `vars-only` on 2.21+ only)
- For `transfer`: `ansible.posix`
- For `sops`: `community.sops`
- For `ssm`: `amazon.aws` + controller `boto3`
- For `s3` / `janitor_prefixes`: controller `boto3` on `ansible_playbook_python`
- For native Node builds: [nvm](https://github.com/nvm-sh/nvm) on the build host (Homebrew or `~/.nvm`)
- For `docker`: Debian-family target (Ubuntu 22.04/24.04/26.04, Debian 12/13), amd64 or arm64
- For `geoip`: Ubuntu universe or Debian contrib (`geoipupdate`)
- For `awscli`: `unzip` and `curl` (installed by the role when it downloads a bundle)
