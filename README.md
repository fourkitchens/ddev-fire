[![tests](https://github.com/ddev/ddev-fire/actions/workflows/tests.yml/badge.svg)](https://github.com/ddev/ddev-fire/actions/workflows/tests.yml)

# ddev-fire

`ddev-fire` migrates the useful FIRE Drupal workflows into a DDEV add-on.

It is intentionally DDEV-only. There is no Lando support in this add-on.

## Install

```bash
ddev add-on get fourkitchens/ddev-fire
ddev restart
```

For local development of the add-on itself:

```bash
ddev add-on get /path/to/ddev-fire
ddev restart
```

## Configuration

The add-on stores project settings in `.ddev/fire/config.env`.

Supported keys:

```dotenv
FIRE_THEME_NAME=""
FIRE_THEME_BUILD_SCRIPT="build"
FIRE_THEME_WATCH_SCRIPT="watch"
FIRE_REMOTE_PLATFORM="pantheon"
FIRE_REMOTE_SITE_NAME=""
FIRE_REMOTE_CANONICAL_ENV="live"
```

`FIRE_THEME_NAME` is optional. If it is unset, `ddev-fire` auto-detects a theme from `web/themes/custom`: it uses the only theme when one exists, or the first sorted theme when multiple exist.

On first install:

- If `fire.yml` or `fire.local.yml` exists, supported values are imported into `.ddev/fire/config.env`.
- If no FIRE config exists, a commented stub is created.
- If `.ddev/fire/config.env` already exists, it is left alone.

## Commands

- `ddev site-build [--skip-db-import] [--skip-db-download] [--with-files]`
- `ddev site-reset [--yes] [--skip-db-import] [--skip-db-download] [--with-files]`
- `ddev frontend-install`
- `ddev theme-build`
- `ddev theme-watch`
- `ddev pull-db [--download-only] [--dry-run]`
- `ddev import-db-reference`
- `ddev pull-files [--reuse-archive] [--dry-run]`
- `ddev remote-uli <env> [--dry-run]`
- `ddev phpcs [--bootstrap]`
- `ddev vscode-xdebug [--force]`

## Command Mapping

| FIRE | DDEV add-on |
| --- | --- |
| `fire build` | `ddev site-build` |
| `fire setup` | `ddev site-reset` |
| `fire build-js` | `ddev frontend-install` |
| `fire build-theme` | `ddev theme-build` |
| `fire theme-watch` | `ddev theme-watch` |
| `fire get-db` | `ddev pull-db` |
| `fire import-db` | `ddev import-db-reference` |
| `fire get-files` | `ddev pull-files` |
| `fire platform:uli <env>` | `ddev remote-uli <env>` |
| `fire phpcs` | `ddev phpcs` |
| `fire xdebug:enable` | `ddev vscode-xdebug` |

## Not Migrated

These FIRE commands are intentionally not part of v1:

- `init`
- `command:add`
- `command:overwrite`
- `env:start`, `env:stop`, `env:poweroff`, `env:switch`
- `local:composer`, `local:drush`
- `local:configure:export`, `local:configure:import`
- all `vrt:*`

Use built-in DDEV commands directly where they already exist, for example:

- `ddev composer`
- `ddev drush`
- `ddev start`
- `ddev stop`
- `ddev poweroff`

`ddev import-db` is intentionally not overridden because DDEV reserves that command name. The add-on provides `ddev import-db-reference` for the FIRE-style "import from reference/site-db.sql.gz with no prompt" behavior.

## Testing

Run the Bats suite locally:

```bash
bats tests/test.bats
```
