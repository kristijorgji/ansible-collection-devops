# Role: `kristijorgji.devops.geoip`

Install MaxMind GeoLite2 databases. Credentials use `geoipupdate` plus a weekly cron.
A download URL is a one-shot alternative. Enabled with neither only verifies files
already on disk.

Needs Ubuntu universe or Debian contrib for the `geoipupdate` package.

---

## Table of contents

- [Task files](#task-files)
- [`install`](#install)

---

## Task files

| File      | Purpose                                     |
| --------- | ------------------------------------------- |
| `install` | Directory, geoipupdate or URL, cron, verify |

`main.yml` imports `install`.

When the play uses `--tags`, put matching tags in `apply.tags` on `include_role`.

---

## `install`

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.geoip
    tasks_from: install
    apply:
      tags: geoip
  vars:
    geoip_maxmind_account_id: "{{ vault_geoip_account_id }}"
    geoip_maxmind_license_key: "{{ vault_geoip_license_key }}"
  tags: geoip
```

One-shot URL (no credentials):

```yaml
- ansible.builtin.include_role:
    name: kristijorgji.devops.geoip
    tasks_from: install
  vars:
    geoip_db_download_url: "https://example.invalid/GeoLite2-Country.mmdb"
    geoip_edition_ids:
      - GeoLite2-Country
```

| Variable                     | Default                             | Meaning                                          |
| ---------------------------- | ----------------------------------- | ------------------------------------------------ |
| `geoip_enabled`              | `true`                              | Master switch.                                   |
| `geoip_maxmind_account_id`   | `""`                                | MaxMind account id.                              |
| `geoip_maxmind_license_key`  | `""`                                | MaxMind license key.                             |
| `geoip_edition_ids`          | `GeoLite2-Country`, `GeoLite2-City` | Editions written by geoipupdate.                 |
| `geoip_db_dir`               | `/usr/share/GeoIP`                  | Database directory.                              |
| `geoip_conf_path`            | `/etc/GeoIP.conf`                   | geoipupdate config path.                         |
| `geoip_db_download_url`      | `""`                                | One-shot `.mmdb` URL when credentials are empty. |
| `geoip_db_download_filename` | first edition + `.mmdb`             | Destination filename for the URL.                |
| `geoip_initial_update`       | `missing`                           | `missing` / `always` / `never`.                  |
| `geoip_cron_enabled`         | `true`                              | Weekly geoipupdate cron.                         |
| `geoip_cron_name`            | `geoipupdate {{ editions }}`        | Cron unique name.                                |

Facts: `geoip_configured`, `geoip_use_geoipupdate`, `geoip_use_download_url`,
`geoip_databases_present` (edition → bool).
