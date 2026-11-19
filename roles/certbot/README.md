# Role: `kristijorgji.devops.certbot`

Install Certbot from distro packages, optionally issue HTTP-01 certificates, and deploy
Let's Encrypt renewal hooks. The package's systemd timer is the default renew path;
an extra root cron is opt-in and installs the `cron` package.

`--staple-ocsp` is off by default (Let's Encrypt ended OCSP stapling in 2025).

---

## Table of contents

- [Task files](#task-files)
- [`install`](#install)
- [`certificates`](#certificates)

---

## Task files

| File           | Purpose                                            |
| -------------- | -------------------------------------------------- |
| `install`      | Apt packages and optional `certbot renew` cron     |
| `certificates` | Issue missing lineages, deploy renewal hooks, cron |

`main.yml` imports `install`. Call `tasks_from: certificates` from site roles.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `install`

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.certbot
    tasks_from: install
    apply:
      tags: certbot
  tags: certbot
```

| Variable                       | Default                                       | Meaning                        |
| ------------------------------ | --------------------------------------------- | ------------------------------ |
| `certbot_skip`                 | `false`                                       | Full no-op.                    |
| `certbot_packages`             | `[certbot]`                                   | Apt package list.              |
| `certbot_extra_packages`       | `[]`                                          | Extra apt names (DNS plugins). |
| `certbot_apt_cache_valid_time` | `3600`                                        | Apt cache seconds.             |
| `certbot_renew_cron`           | `false`                                       | Also write a daily root cron.  |
| `certbot_renew_cron_name`      | `Certbot renew attempt every day at midnight` | Cron unique name.              |

---

## `certificates`

Resolves domains from `certbot_domains`, or apex + optional www + extras. Stats
`certbot_live_dir/<domain>` and runs `create-certificates.sh` only when a lineage is
missing. Pre-hook runs once; post-hook always runs after issuance attempts.

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.certbot
    tasks_from: certificates
    apply:
      tags: certificates
  vars:
    certbot_admin_email: admin@example.com
    certbot_apex_domain: example.com
    certbot_www_domain: www.example.com
    certbot_include_www: true
    certbot_renewal_hooks_dir: "{{ _site_certbot_hooks_dir }}"
    certbot_renewal_hook_name: example
  tags: certificates
```

Set `_site_certbot_hooks_dir` with `set_fact` from the consumer `role_path` first.
Do not pass `{{ role_path }}` inside `import_role`/`include_role` vars.

| Variable                                 | Default      | Meaning                                          |
| ---------------------------------------- | ------------ | ------------------------------------------------ |
| `certbot_admin_email`                    | `""`         | Let's Encrypt account email (required to issue). |
| `certbot_domains`                        | `[]`         | Explicit hostnames. Overrides apex/www assembly. |
| `certbot_apex_domain`                    | `""`         | Used when `certbot_domains` is empty.            |
| `certbot_www_domain`                     | `""`         | www hostname.                                    |
| `certbot_include_www`                    | `false`      | Also request www (`'true'`/`'false'` accepted).  |
| `certbot_extra_domains`                  | `[]`         | Extra hostnames as their own certs.              |
| `certbot_issue`                          | `true`       | When false, still deploy hooks/cron.             |
| `certbot_challenge`                      | `standalone` | `standalone` or `webroot`.                       |
| `certbot_webroot_path`                   | `""`         | Required for webroot.                            |
| `certbot_staging`                        | `false`      | Let's Encrypt staging.                           |
| `certbot_server`                         | `""`         | Custom ACME directory URL.                       |
| `certbot_staple_ocsp`                    | `false`      | Pass `--staple-ocsp`.                            |
| `certbot_extra_args`                     | `[]`         | Extra CLI tokens.                                |
| `certbot_pre_hook` / `certbot_post_hook` | `""`         | Shell around first-time issuance.                |
| `certbot_renewal_hooks`                  | `[]`         | `{stage, dest_name, src\|content, template}`.    |
| `certbot_renewal_hooks_dir`              | `""`         | Convenience: `pre.sh`/`deploy.sh`/`post.sh`.     |
| `certbot_renewal_hook_name`              | `""`         | Destination basename without `.sh`.              |
| `certbot_renewal_hooks_template`         | `false`      | Render `*.sh.j2` from the convenience dir.       |
