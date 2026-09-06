#!/usr/bin/env bash
set -euo pipefail

readonly github_host=github.com
readonly upstream_repository=gcomfident-crypto/stratadiff
readonly upstream_installer_path=scripts/install-release.sh

die() {
  printf 'promote-upstream-release: %s\n' "$*" >&2
  exit 1
}

if [[ $# -ne 3 ]]; then
  printf 'usage: scripts/promote-upstream-release.sh vMAJOR.MINOR.PATCH OUTPUT_DIRECTORY EXTENSION_ASSET\n' >&2
  exit 2
fi

script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
release_tag=$1
output_directory=$2
extension_asset=$3

[[ "${release_tag}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || \
  die 'release tag must be a stable vMAJOR.MINOR.PATCH tag'
[[ -n "${output_directory}" && "${output_directory}" == /* ]] || \
  die 'output directory must be an absolute path'
[[ "${output_directory}" != / && "${output_directory}" != */ && \
   "${output_directory}" != *//* ]] || die 'output directory must be normalized and must not be /'
[[ "/${output_directory#/}/" != *'/./'* && "/${output_directory#/}/" != *'/../'* ]] || \
  die 'output directory must not contain . or .. components'
[[ "${output_directory}" != *$'\n'* && "${output_directory}" != *$'\r'* ]] || \
  die 'output directory must be a single line'

IFS=/ read -r -a output_components <<< "${output_directory#/}"
output_component_path=
for output_component in "${output_components[@]}"; do
  [[ -n "${output_component}" ]] || die 'output directory contains an empty component'
  output_component_path=${output_component_path}/${output_component}
  [[ ! -L "${output_component_path}" ]] || \
    die "output directory traverses symbolic link: ${output_component_path}"
  [[ ! -e "${output_component_path}" || -d "${output_component_path}" ]] || \
    die "output directory component is not a directory: ${output_component_path}"
done

for required_command in gh uname mktemp bash chmod install mkdir mv rm wc; do
  command -v "${required_command}" >/dev/null 2>&1 || die "required command is not available: ${required_command}"
done

kernel="$(uname -s)"
machine="$(uname -m)"
case "${kernel}:${machine}" in
  Linux:x86_64) expected_asset=gh-stratadiff-linux-amd64 ;;
  Linux:aarch64|Linux:arm64) expected_asset=gh-stratadiff-linux-arm64 ;;
  Darwin:x86_64) expected_asset=gh-stratadiff-darwin-amd64 ;;
  Darwin:arm64|Darwin:aarch64) expected_asset=gh-stratadiff-darwin-arm64 ;;
  *) die "unsupported release platform: ${kernel} ${machine}" ;;
esac
[[ "${extension_asset}" == "${expected_asset}" ]] || \
  die "asset ${extension_asset} does not match ${kernel} ${machine}; expected ${expected_asset}"

release_state="$(
  gh release view "${release_tag}" \
    --repo "${github_host}/${upstream_repository}" \
    --json tagName,isDraft,isPrerelease,isImmutable \
    --jq '.tagName + "\t" + (.isDraft | tostring) + "\t" + (.isPrerelease | tostring) + "\t" + (.isImmutable | tostring)'
)"
[[ "${release_state}" == "${release_tag}"$'\tfalse\tfalse\ttrue' ]] || \
  die "upstream ${release_tag} is not a published immutable stable release"

source_commit="$("${script_directory}/resolve-tag.sh" "${upstream_repository}" "${release_tag}")"

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/gh-stratadiff-promote-XXXXXX")"
staged_output=
cleanup() {
  if [[ -n "${staged_output}" ]]; then
    rm -f -- "${staged_output}"
  fi
  rm -r -- "${temporary_directory}"
}
trap cleanup EXIT

installer=${temporary_directory}/install-release.sh
gh api --hostname "${github_host}" \
  -H 'Accept: application/vnd.github.raw+json' \
  "repos/${upstream_repository}/contents/${upstream_installer_path}?ref=${source_commit}" \
  > "${installer}"
[[ -f "${installer}" && ! -L "${installer}" && -s "${installer}" ]] || \
  die 'upstream installer is not a nonempty regular file'
installer_size="$(wc -c < "${installer}")"
[[ "${installer_size}" =~ ^[0-9]+$ && "${installer_size}" -le 1048576 ]] || \
  die 'upstream installer exceeds the 1 MiB safety limit'
bash -n "${installer}" || die 'upstream installer is not valid Bash'

upstream_install_directory=${temporary_directory}/verified-upstream
bash "${installer}" "${release_tag}" "${upstream_install_directory}"
upstream_binary=${upstream_install_directory}/stratadiff
[[ -f "${upstream_binary}" && ! -L "${upstream_binary}" && -s "${upstream_binary}" ]] || \
  die 'upstream installer did not produce one nonempty regular stratadiff binary'

expected_version=${release_tag#v}
reported_version="$("${upstream_binary}" --version)"
[[ "${reported_version}" == "stratadiff ${expected_version}" ]] || \
  die "upstream binary reports ${reported_version}, expected stratadiff ${expected_version}"
"${upstream_binary}" inbox --help >/dev/null || \
  die "upstream ${release_tag} does not provide the inbox command"
"${upstream_binary}" resume --help >/dev/null || \
  die "upstream ${release_tag} does not provide the resume command"

final_source_commit="$("${script_directory}/resolve-tag.sh" "${upstream_repository}" "${release_tag}")"
[[ "${final_source_commit}" == "${source_commit}" ]] || \
  die "upstream tag moved from ${source_commit} to ${final_source_commit}"
final_release_state="$(
  gh release view "${release_tag}" \
    --repo "${github_host}/${upstream_repository}" \
    --json tagName,isDraft,isPrerelease,isImmutable \
    --jq '.tagName + "\t" + (.isDraft | tostring) + "\t" + (.isPrerelease | tostring) + "\t" + (.isImmutable | tostring)'
)"
[[ "${final_release_state}" == "${release_state}" ]] || \
  die "upstream release state changed while promoting ${release_tag}"

mkdir -p -- "${output_directory}"
canonical_output_directory="$(cd -- "${output_directory}" && pwd -P)"
[[ "${canonical_output_directory}" == "${output_directory}" ]] || \
  die "output directory does not resolve to itself: ${output_directory}"
destination=${output_directory}/${extension_asset}
checksum=${destination}.sha256
[[ ! -e "${destination}" && ! -L "${destination}" && \
   ! -e "${checksum}" && ! -L "${checksum}" ]] || \
  die "refusing to replace existing release output for ${extension_asset}"

staged_output="$(mktemp "${output_directory}/.gh-stratadiff-promote-XXXXXX")"
chmod 0755 "${upstream_binary}"
install -m 0755 "${upstream_binary}" "${staged_output}"
mv -- "${staged_output}" "${destination}"
staged_output=

if command -v sha256sum >/dev/null 2>&1; then
  digest="$(sha256sum "${destination}")"
  digest=${digest%% *}
elif command -v shasum >/dev/null 2>&1; then
  digest="$(shasum -a 256 "${destination}")"
  digest=${digest%% *}
else
  die 'sha256sum or shasum is required'
fi
printf '%s  %s\n' "${digest}" "${extension_asset}" > "${checksum}"
printf 'Promoted verified %s@%s as %s (%s)\n' \
  "${upstream_repository}" "${source_commit}" "${extension_asset}" "${digest}"
