setup() {
  set -eu -o pipefail
  export DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." >/dev/null 2>&1 && pwd)"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/ddev-fire.${BATS_TEST_NUMBER}.XXXXXX")"
  export PROJNAME="ddev-fire-${BATS_TEST_NUMBER}"
  export DDEV_NON_INTERACTIVE=true

  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  mkdir -p "${TESTDIR}/web/sites/default/files" "${TESTDIR}/.vscode"
  cd "${TESTDIR}"

  cat > composer.json <<'EOF'
{
  "name": "acme/ddev-fire-test",
  "require": {},
  "require-dev": {}
}
EOF

  cat > .gitignore <<'EOF'
/vendor
/node_modules
EOF

  ddev config --project-name="${PROJNAME}" --project-type=drupal --docroot=web >/dev/null
  ddev start -y >/dev/null
}

teardown() {
  set -eu -o pipefail
  if [[ -d "${TESTDIR}" ]]; then
    cd "${TESTDIR}" || exit 1
    ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TESTDIR}"
}

run_host_command() {
  local command_name="$1"
  shift
  DDEV_APPROOT="${TESTDIR}" \
  DDEV_DOCROOT="web" \
  DDEV_PROJECT_TYPE="drupal" \
  PATH="${TESTDIR}/bin:${PATH}" \
  "${TESTDIR}/.ddev/commands/host/${command_name}" "$@"
}

make_fake_bin() {
  mkdir -p "${TESTDIR}/bin"
  cat > "${TESTDIR}/bin/$1" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$0 \$*" >> "${TESTDIR}/fake.log"
EOF
  chmod +x "${TESTDIR}/bin/$1"
}

make_fake_ddev() {
  mkdir -p "${TESTDIR}/bin"
  cat > "${TESTDIR}/bin/ddev" <<EOF
#!/usr/bin/env bash
printf '%s\n' "ddev \$*" >> "${TESTDIR}/fake.log"
if [[ "\$1" == "xdebug" && "\${2:-}" == "on" ]]; then
  exit 0
fi
if [[ "\$1" == "drush" && "\${2:-}" == "cr" ]]; then
  exit 0
fi
if [[ "\$1" == "mysql" ]]; then
  cat >/dev/null
  exit 0
fi
exit 0
EOF
  chmod +x "${TESTDIR}/bin/ddev"
}

@test "install from directory and generate expected files" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null

  [ -f "${TESTDIR}/.ddev/fire/config.env" ]
  [ -f "${TESTDIR}/.ddev/fire/scripts/lib.sh" ]
  [ -f "${TESTDIR}/.ddev/commands/host/site-build" ]
}

@test "migrate fire.yml and fire.local.yml into config.env" {
  cd "${TESTDIR}"
  cat > fire.yml <<'EOF'
local_theme_build_script: build-prod
remote_platform: pantheon
remote_sitename: base-site
EOF
  cat > fire.local.yml <<'EOF'
remote_sitename: override-site
remote_canonical_env: test
local_fe_theme_name: mytheme
EOF

  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null

  run grep 'FIRE_THEME_NAME="mytheme"' .ddev/fire/config.env
  run grep 'FIRE_THEME_BUILD_SCRIPT="build-prod"' .ddev/fire/config.env
  run grep 'FIRE_REMOTE_SITE_NAME="override-site"' .ddev/fire/config.env
  run grep 'FIRE_REMOTE_CANONICAL_ENV="test"' .ddev/fire/config.env
  [ "$status" -eq 0 ]
}

@test "create stub config when no FIRE YAML exists" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null

  run grep '^# FIRE_REMOTE_PLATFORM="pantheon"' .ddev/fire/config.env
  [ "$status" -eq 0 ]
}

@test "register help for public commands" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null

  run ddev help site-build
  [[ "$output" == *"Build the local Drupal site using DDEV workflows"* ]]

  run ddev help import-db-reference
  [[ "$output" == *"import-db-reference"* ]]
}

@test "pull-db dry-run prints pantheon command" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null
  cat > .ddev/fire/config.env <<'EOF'
FIRE_REMOTE_PLATFORM="pantheon"
FIRE_REMOTE_SITE_NAME="example-site"
FIRE_REMOTE_CANONICAL_ENV="live"
EOF

  run run_host_command pull-db --dry-run
  [[ "$output" == *"terminus backup:get example-site.live --element=db"* ]]
  [[ "$output" == *"reference/site-db.sql.gz"* ]]
}

@test "pull-files dry-run prints pantheon file sync commands" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null
  cat > .ddev/fire/config.env <<'EOF'
FIRE_REMOTE_PLATFORM="pantheon"
FIRE_REMOTE_SITE_NAME="example-site"
FIRE_REMOTE_CANONICAL_ENV="live"
EOF

  run run_host_command pull-files --dry-run
  [[ "$output" == *"terminus backup:get example-site.live --element=files"* ]]
  [[ "$output" == *"rsync -a --delete"* ]]
}

@test "remote-uli dry-run prints platform-specific command" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null
  cat > .ddev/fire/config.env <<'EOF'
FIRE_REMOTE_PLATFORM="platformsh"
FIRE_REMOTE_SITE_NAME="example-site"
EOF

  run run_host_command remote-uli pr-123 --dry-run
  [[ "$output" == *"platform ssh --site=example-site --env=pr-123 drush uli"* ]]
}

@test "site-build skip-db-import avoids database steps" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null
  mkdir -p web/themes/custom/mytheme
  cat > web/themes/custom/mytheme/package.json <<'EOF'
{"name":"theme","scripts":{"build":"echo build","watch":"echo watch"}}
EOF
  cat > .ddev/fire/config.env <<'EOF'
FIRE_THEME_NAME="mytheme"
FIRE_THEME_BUILD_SCRIPT="build"
FIRE_THEME_WATCH_SCRIPT="watch"
EOF
  make_fake_ddev
  cat > "${TESTDIR}/bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${TESTDIR}/bin/npm"

  run run_host_command site-build --skip-db-import
  [ "$status" -eq 0 ]
  run grep -q 'pull-db' "${TESTDIR}/fake.log"
  [ "$status" -ne 0 ]
  run grep -q 'ddev mysql' "${TESTDIR}/fake.log"
  [ "$status" -ne 0 ]
}

@test "site-build skip-db-download reuses reference dump" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null
  mkdir -p web/themes/custom/mytheme reference
  printf 'test' | gzip > reference/site-db.sql.gz
  cat > web/themes/custom/mytheme/package.json <<'EOF'
{"name":"theme","scripts":{"build":"echo build","watch":"echo watch"}}
EOF
  cat > .ddev/fire/config.env <<'EOF'
FIRE_THEME_NAME="mytheme"
FIRE_THEME_BUILD_SCRIPT="build"
FIRE_THEME_WATCH_SCRIPT="watch"
EOF
  make_fake_ddev
  cat > "${TESTDIR}/bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${TESTDIR}/bin/npm"

  run run_host_command site-build --skip-db-download
  [ "$status" -eq 0 ]
  run grep -q 'terminus backup:get' "${TESTDIR}/fake.log"
  [ "$status" -ne 0 ]
  run grep -q 'ddev mysql' "${TESTDIR}/fake.log"
  [ "$status" -eq 0 ]
}

@test "vscode-xdebug force writes launch config" {
  cd "${TESTDIR}"
  ddev add-on get "${DIR}" >/dev/null
  ddev restart >/dev/null
  make_fake_ddev

  run run_host_command vscode-xdebug --force
  [ "$status" -eq 0 ]
  [ -f "${TESTDIR}/.vscode/launch.json" ]
  run grep '"Listen for Xdebug"' "${TESTDIR}/.vscode/launch.json"
  [ "$status" -eq 0 ]
}
