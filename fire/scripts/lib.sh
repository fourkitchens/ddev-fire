#!/usr/bin/env bash
#ddev-generated

set -euo pipefail

fire::app_root() {
  printf '%s\n' "${DDEV_APPROOT:?DDEV_APPROOT is required}"
}

fire::config_file() {
  printf '%s/.ddev/fire/config.env\n' "$(fire::app_root)"
}

fire::load_config() {
  local config_file
  config_file="$(fire::config_file)"
  if [[ -f "${config_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${config_file}"
    set +a
  fi
}

fire::fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

fire::info() {
  printf '%s\n' "$*"
}

fire::print_command() {
  local quoted=()
  local arg
  for arg in "$@"; do
    quoted+=("$(printf '%q' "${arg}")")
  done
  printf '+ %s\n' "${quoted[*]}"
}

fire::run() {
  fire::print_command "$@"
  if [[ "${FIRE_DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi
  "$@"
}

fire::run_in_dir() {
  local dir="$1"
  shift
  fire::print_command bash -lc "cd $(printf '%q' "${dir}") && ${*}"
  if [[ "${FIRE_DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi
  (
    cd "${dir}"
    "$@"
  )
}

fire::container_app_root() {
  printf '%s\n' "/var/www/html"
}

fire::container_path() {
  local host_path="$1"
  local app_root relative_path
  app_root="$(fire::app_root)"

  case "${host_path}" in
    "${app_root}")
      fire::container_app_root
      ;;
    "${app_root}"/*)
      relative_path="${host_path#${app_root}/}"
      printf '%s/%s\n' "$(fire::container_app_root)" "${relative_path}"
      ;;
    *)
      fire::fail "Path is outside the project root and cannot be mapped into the DDEV container: ${host_path}"
      ;;
  esac
}

fire::run_in_container_dir() {
  local dir="$1"
  local command="$2"
  local container_dir
  container_dir="$(fire::container_path "${dir}")"
  fire::run ddev exec bash -lc "cd $(printf '%q' "${container_dir}") && ${command}"
}

fire::require_command() {
  command -v "$1" >/dev/null 2>&1 || fire::fail "Required command not found: $1"
}

fire::drupal_root() {
  local app_root candidate
  app_root="$(fire::app_root)"
  if [[ -n "${DDEV_DOCROOT:-}" && -d "${app_root}/${DDEV_DOCROOT}" ]]; then
    printf '%s\n' "${app_root}/${DDEV_DOCROOT}"
    return
  fi
  for candidate in web docroot; do
    if [[ -d "${app_root}/${candidate}" ]]; then
      printf '%s\n' "${app_root}/${candidate}"
      return
    fi
  done
  printf '%s\n' "${app_root}"
}

fire::reference_dir() {
  printf '%s/reference\n' "$(fire::app_root)"
}

fire::ensure_reference_dir() {
  local reference_dir
  reference_dir="$(fire::reference_dir)"
  if [[ "${FIRE_DRY_RUN:-0}" == "1" ]]; then
    fire::print_command mkdir -p "${reference_dir}"
    return
  fi
  mkdir -p "${reference_dir}"
}

fire::theme_path() {
  local docroot theme_base theme_count first_theme
  docroot="$(fire::drupal_root)"
  theme_base="${docroot}/themes/custom"
  [[ -d "${theme_base}" ]] || fire::fail "Theme directory not found at ${theme_base}"

  if [[ -n "${FIRE_THEME_NAME:-}" ]]; then
    [[ -d "${theme_base}/${FIRE_THEME_NAME}" ]] || fire::fail "Configured theme not found: ${theme_base}/${FIRE_THEME_NAME}"
    printf '%s\n' "${theme_base}/${FIRE_THEME_NAME}"
    return
  fi

  theme_count=0
  first_theme=""
  while IFS= read -r theme_dir; do
    theme_count=$((theme_count + 1))
    first_theme="${theme_dir}"
  done < <(find "${theme_base}" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | sort)

  if [[ "${theme_count}" -eq 1 ]]; then
    printf '%s\n' "${first_theme}"
    return
  fi

  fire::fail "Unable to auto-detect a single custom theme. Set FIRE_THEME_NAME in .ddev/fire/config.env."
}

fire::npm_command() {
  local dir="$1"
  local command="$2"

  if [[ -f "${dir}/.nvmrc" ]]; then
    fire::run_in_container_dir "${dir}" "if command -v nvm >/dev/null 2>&1; then nvm install && ${command}; else printf 'Error: nvm is required in the DDEV web container for %s because .nvmrc is present. Install ddev/ddev-nvm or configure nodejs_version.\\n' $(printf '%q' "${dir}") >&2; exit 1; fi"
    return
  fi

  fire::run_in_container_dir "${dir}" "${command}"
}

fire::npm_ci() {
  local dir="$1"
  fire::npm_command "${dir}" "npm ci"
}

fire::npm_script() {
  local dir="$1"
  local script="$2"
  fire::npm_command "${dir}" "npm ci && npm run $(printf '%q' "${script}")"
}

fire::frontend_install() {
  local app_root
  app_root="$(fire::app_root)"
  if [[ ! -f "${app_root}/package.json" ]]; then
    fire::info "No package.json found at ${app_root}; skipping frontend install."
    return
  fi
  fire::npm_ci "${app_root}"
}

fire::theme_build() {
  local theme_path
  [[ -n "${FIRE_THEME_BUILD_SCRIPT:-}" ]] || fire::fail "FIRE_THEME_BUILD_SCRIPT is not configured in .ddev/fire/config.env."
  theme_path="$(fire::theme_path)"
  fire::npm_script "${theme_path}" "${FIRE_THEME_BUILD_SCRIPT}"
}

fire::theme_watch() {
  local theme_path
  [[ -n "${FIRE_THEME_WATCH_SCRIPT:-}" ]] || fire::fail "FIRE_THEME_WATCH_SCRIPT is not configured in .ddev/fire/config.env."
  theme_path="$(fire::theme_path)"
  fire::npm_script "${theme_path}" "${FIRE_THEME_WATCH_SCRIPT}"
}

fire::require_remote_config() {
  [[ -n "${FIRE_REMOTE_PLATFORM:-}" ]] || fire::fail "FIRE_REMOTE_PLATFORM is not configured."
  [[ -n "${FIRE_REMOTE_SITE_NAME:-}" ]] || fire::fail "FIRE_REMOTE_SITE_NAME is not configured."
  [[ -n "${FIRE_REMOTE_CANONICAL_ENV:-}" ]] || fire::fail "FIRE_REMOTE_CANONICAL_ENV is not configured."
}

fire::python_bin() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3"
    return
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' "python"
    return
  fi
  return 1
}

fire::json_value() {
  local expression="$1"
  local python_bin
  python_bin="$(fire::python_bin)" || fire::fail "Python is required to parse CLI JSON output."
  "${python_bin}" - "${expression}" <<'PY'
import json
import sys

expression = sys.argv[1]
data = json.load(sys.stdin)

if expression == "first_id":
    if isinstance(data, list) and data and isinstance(data[0], dict) and "id" in data[0]:
        print(data[0]["id"])
    sys.exit(0)

if expression.startswith("key:"):
    key = expression.split(":", 1)[1]
    if isinstance(data, dict) and key in data:
        print(data[key])
    sys.exit(0)
PY
}

fire::import_reference_db() {
  local dump
  dump="$(fire::reference_dir)/site-db.sql.gz"
  [[ -f "${dump}" ]] || fire::fail "Database dump not found at ${dump}"

  if [[ "${FIRE_DRY_RUN:-0}" == "1" ]]; then
    fire::print_command gzip -dc "${dump}"
    fire::print_command ddev mysql
    fire::print_command ddev drush cr
    return
  fi

  case "${dump}" in
    *.sql.gz|*.gz) gzip -dc "${dump}" | ddev mysql ;;
    *.sql.bz2|*.bz2) bzip2 -dc "${dump}" | ddev mysql ;;
    *.sql.xz|*.xz) xz -dc "${dump}" | ddev mysql ;;
    *) cat "${dump}" | ddev mysql ;;
  esac
  fire::run ddev drush cr
}

fire::pull_db() {
  local download_only="$1"
  local reference_dir dump_file backup_id download_url backups_json download_json
  fire::require_remote_config
  fire::ensure_reference_dir
  reference_dir="$(fire::reference_dir)"
  dump_file="${reference_dir}/site-db.sql.gz"

  if [[ -f "${dump_file}" ]]; then
    fire::run rm -f "${dump_file}"
  fi

  case "${FIRE_REMOTE_PLATFORM}" in
    pantheon)
      fire::require_command terminus
      fire::run terminus backup:get "${FIRE_REMOTE_SITE_NAME}.${FIRE_REMOTE_CANONICAL_ENV}" --element=db "--to=${dump_file}"
      ;;
    acquia)
      fire::require_command acli
      fire::print_command acli api:environments:database-backup-list "${FIRE_REMOTE_SITE_NAME}.${FIRE_REMOTE_CANONICAL_ENV}" "${FIRE_REMOTE_SITE_NAME}" --format=json
      if [[ "${FIRE_DRY_RUN:-0}" == "1" ]]; then
        fire::print_command acli api:environments:database-backup-download "${FIRE_REMOTE_SITE_NAME}.${FIRE_REMOTE_CANONICAL_ENV}" "${FIRE_REMOTE_SITE_NAME}" "<backup-id>" --format=json
        fire::print_command curl --location "<download-url>" --output "${dump_file}"
      else
        backups_json="$(acli api:environments:database-backup-list "${FIRE_REMOTE_SITE_NAME}.${FIRE_REMOTE_CANONICAL_ENV}" "${FIRE_REMOTE_SITE_NAME}" --format=json)"
        backup_id="$(printf '%s' "${backups_json}" | fire::json_value first_id)"
        [[ -n "${backup_id}" ]] || fire::fail "No Acquia database backups were returned."
        fire::print_command acli api:environments:database-backup-download "${FIRE_REMOTE_SITE_NAME}.${FIRE_REMOTE_CANONICAL_ENV}" "${FIRE_REMOTE_SITE_NAME}" "${backup_id}" --format=json
        download_json="$(acli api:environments:database-backup-download "${FIRE_REMOTE_SITE_NAME}.${FIRE_REMOTE_CANONICAL_ENV}" "${FIRE_REMOTE_SITE_NAME}" "${backup_id}" --format=json)"
        download_url="$(printf '%s' "${download_json}" | fire::json_value key:url)"
        [[ -n "${download_url}" ]] || fire::fail "Unable to determine Acquia download URL."
        fire::run curl --location "${download_url}" --output "${dump_file}"
      fi
      ;;
    *)
      fire::fail "Unsupported remote platform: ${FIRE_REMOTE_PLATFORM}"
      ;;
  esac

  if [[ "${download_only}" == "1" ]]; then
    return
  fi
  fire::import_reference_db
}

fire::pull_files() {
  local reuse_archive="$1"
  local reference_dir drupal_root destination archive extract_dir
  fire::require_remote_config
  fire::ensure_reference_dir
  reference_dir="$(fire::reference_dir)"
  drupal_root="$(fire::drupal_root)"
  destination="${drupal_root}/sites/default/files"
  archive="${reference_dir}/site-files.tar.gz"
  extract_dir="${reference_dir}/files_${FIRE_REMOTE_CANONICAL_ENV}"

  case "${FIRE_REMOTE_PLATFORM}" in
    pantheon)
      fire::require_command terminus
      if [[ "${reuse_archive}" != "1" ]]; then
        fire::run terminus backup:get "${FIRE_REMOTE_SITE_NAME}.${FIRE_REMOTE_CANONICAL_ENV}" --element=files "--to=${archive}"
      fi
      if [[ "${FIRE_DRY_RUN:-0}" == "1" ]]; then
        fire::print_command rm -rf "${extract_dir}"
        fire::print_command mkdir -p "${destination}"
        fire::print_command tar -xzf "${archive}" -C "${reference_dir}"
        fire::print_command rsync -a --delete "${extract_dir}/" "${destination}/"
        fire::print_command rm -rf "${extract_dir}"
        return
      fi
      rm -rf "${extract_dir}"
      mkdir -p "${destination}"
      tar -xzf "${archive}" -C "${reference_dir}"
      rsync -a --delete "${extract_dir}/" "${destination}/"
      rm -rf "${extract_dir}"
      ;;
    acquia)
      fire::require_command acli
      fire::run_in_dir "$(fire::app_root)" acli pull:files "${FIRE_REMOTE_SITE_NAME}.${FIRE_REMOTE_CANONICAL_ENV}" default
      ;;
    *)
      fire::fail "Unsupported remote platform: ${FIRE_REMOTE_PLATFORM}"
      ;;
  esac
}

fire::remote_uli() {
  local remote_env="$1"
  local -a command
  [[ -n "${remote_env}" ]] || fire::fail "Usage: ddev remote-uli <env>"
  [[ -n "${FIRE_REMOTE_PLATFORM:-}" ]] || fire::fail "FIRE_REMOTE_PLATFORM is not configured."
  [[ -n "${FIRE_REMOTE_SITE_NAME:-}" ]] || fire::fail "FIRE_REMOTE_SITE_NAME is not configured."

  case "${FIRE_REMOTE_PLATFORM}" in
    pantheon)
      fire::require_command terminus
      command=(terminus drush "${FIRE_REMOTE_SITE_NAME}.${remote_env}" -- uli)
      ;;
    acquia)
      fire::require_command acli
      command=(acli drush "${FIRE_REMOTE_SITE_NAME}.${remote_env}" -- uli)
      ;;
    platformsh)
      fire::require_command platform
      command=(platform ssh "--site=${FIRE_REMOTE_SITE_NAME}" "--env=${remote_env}" drush uli)
      ;;
    *)
      fire::fail "Unsupported remote platform: ${FIRE_REMOTE_PLATFORM}"
      ;;
  esac

  fire::run "${command[@]}"
}

fire::site_build() {
  local skip_db_import="$1"
  local skip_db_download="$2"
  local with_files="$3"

  fire::run ddev composer install
  fire::frontend_install

  if [[ "${skip_db_import}" != "1" ]]; then
    if [[ "${skip_db_download}" != "1" ]]; then
      fire::pull_db 1
    fi
    fire::import_reference_db
  fi

  if [[ "${with_files}" == "1" ]]; then
    fire::pull_files 0
  fi

  fire::run ddev drush cr
  fire::run ddev drush updb -y
  fire::run ddev drush cim -y
  fire::run ddev drush cr
  fire::run ddev drush deploy:hook -y
  fire::theme_build
}

fire::write_phpcs_xml() {
  local target
  target="$(fire::app_root)/phpcs.xml"
  cat > "${target}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<ruleset name="Standard Drupal Project">
  <description>PHP CodeSniffer configuration for Drupal development.</description>
  <file>web/modules/custom</file>
  <file>web/themes/custom</file>
  <exclude-pattern>vendor</exclude-pattern>
  <exclude-pattern>contrib</exclude-pattern>
  <exclude-pattern>tests</exclude-pattern>
  <exclude-pattern>pattern-lab</exclude-pattern>
  <exclude-pattern>patternlab</exclude-pattern>
  <exclude-pattern>node_modules</exclude-pattern>
  <exclude-pattern>*components/_twig-components*</exclude-pattern>
  <exclude-pattern>*/themes/custom/**/dist/*</exclude-pattern>
  <config name="drupal_core_version" value="8"/>
  <arg name="extensions" value="php,module,inc,install,test,profile,theme,info"/>
  <rule ref="Drupal"/>
  <rule ref="DrupalPractice"/>
</ruleset>
EOF
}

fire::phpcs() {
  local bootstrap="$1"
  local app_root composer_json phpcs_bin
  app_root="$(fire::app_root)"
  composer_json="${app_root}/composer.json"
  phpcs_bin="${app_root}/vendor/bin/phpcs"

  [[ -f "${composer_json}" ]] || fire::fail "composer.json not found at ${composer_json}"

  if [[ "${bootstrap}" == "1" ]] && ! grep -q '"drupal/coder"' "${composer_json}"; then
    fire::run ddev composer require drupal/coder --dev --ignore-platform-reqs
  fi

  if [[ "${bootstrap}" == "1" ]] && [[ ! -f "${app_root}/phpcs.xml" ]]; then
    if [[ "${FIRE_DRY_RUN:-0}" == "1" ]]; then
      fire::print_command write phpcs.xml "${app_root}/phpcs.xml"
    else
      fire::write_phpcs_xml
    fi
  fi

  grep -q '"drupal/coder"' "${composer_json}" || fire::fail "drupal/coder is missing. Run: ddev phpcs --bootstrap"
  [[ -f "${app_root}/phpcs.xml" ]] || fire::fail "phpcs.xml is missing. Run: ddev phpcs --bootstrap"
  [[ -x "${phpcs_bin}" ]] || fire::fail "vendor/bin/phpcs is missing. Run: ddev composer install"

  fire::run_in_dir "${app_root}" "${phpcs_bin}" -d memory_limit=-1
}

fire::write_vscode_launch() {
  local target
  target="$(fire::app_root)/.vscode/launch.json"
  mkdir -p "$(dirname "${target}")"
  cat > "${target}" <<'EOF'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Listen for Xdebug",
      "type": "php",
      "request": "launch",
      "hostname": "0.0.0.0",
      "port": 9003,
      "pathMappings": {
        "/var/www/html": "${workspaceFolder}"
      }
    }
  ]
}
EOF
}

fire::vscode_xdebug() {
  local force="$1"
  local target
  target="$(fire::app_root)/.vscode/launch.json"

  if [[ -f "${target}" && "${force}" != "1" ]]; then
    fire::info "Keeping existing ${target}. Use --force to overwrite it."
  else
    if [[ "${FIRE_DRY_RUN:-0}" == "1" ]]; then
      fire::print_command write vscode launch config "${target}"
    else
      fire::write_vscode_launch
    fi
  fi

  fire::run ddev xdebug on
}
