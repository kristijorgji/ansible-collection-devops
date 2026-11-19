# Role: `kristijorgji.devops.awscli`

Install the AWS CLI v2 zip bundle for amd64 or arm64. Empty `awscli_version`
installs the current bundle only when `aws --version` does not succeed (missing,
non-executable, or wrong architecture). A pinned version upgrades or downgrades
to that release.

Requires `unzip` and `curl` (installed by the role when an install runs).

---

## Table of contents

- [Task files](#task-files)
- [`install`](#install)

---

## Task files

| File      | Purpose                           |
| --------- | --------------------------------- |
| `install` | Detect, download, install, assert |

`main.yml` imports `install`.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `install`

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.awscli
    tasks_from: install
    apply:
      tags: common
  tags: common
```

Pin a version:

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.awscli
    tasks_from: install
  vars:
    awscli_version: "2.17.0"
```

| Variable             | Default              | Meaning                                                       |
| -------------------- | -------------------- | ------------------------------------------------------------- |
| `awscli_skip`        | `false`              | Full no-op.                                                   |
| `awscli_version`     | `""`                 | Empty = latest if `aws --version` fails. Pin to enforce.      |
| `awscli_install_dir` | `/usr/local/aws-cli` | `-i` install prefix.                                          |
| `awscli_bin_dir`     | `/usr/local/bin`     | `-b` symlink directory.                                       |
