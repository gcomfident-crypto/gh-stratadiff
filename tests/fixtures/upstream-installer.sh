#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

release_tag=$1
install_directory=$2
printf 'installer-tag=%s\ninstaller-directory=%s\n' \
  "${release_tag}" "${install_directory}" >> "${GH_STRATADIFF_TEST_LOG}"

if [[ "${GH_STRATADIFF_TEST_SCENARIO}" == installer-failure ]]; then
  printf 'fixture installer failed\n' >&2
  exit 1
fi

mkdir -p -- "${install_directory}"
reported_version=${GH_STRATADIFF_TEST_VERSION}
if [[ "${GH_STRATADIFF_TEST_SCENARIO}" == version-mismatch ]]; then
  reported_version=9.9.9
fi

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf 'reported_version=%q\n' "${reported_version}"
  printf 'scenario=%q\n' "${GH_STRATADIFF_TEST_SCENARIO}"
  printf '%s\n' 'case "${1:-}" in'
  printf '%s\n' '  --version) printf "stratadiff %s\\n" "${reported_version}" ;;'
  printf '%s\n' '  inbox)'
  printf '%s\n' '    [[ "${scenario}" != missing-inbox ]] || exit 2'
  printf '%s\n' '    [[ "${2:-}" == --help ]] && printf "Inbox help\\n"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  resume) [[ "${2:-}" == --help ]] && printf "Resume help\\n" ;;'
  printf '%s\n' '  *) exit 2 ;;'
  printf '%s\n' 'esac'
} > "${install_directory}/stratadiff"
chmod 0755 "${install_directory}/stratadiff"
