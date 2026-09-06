#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary_directory="$(cd -- "$(mktemp -d "${TMPDIR:-/tmp}/gh-stratadiff-tests-XXXXXX")" && pwd -P)"
trap 'rm -r -- "${temporary_directory}"' EXIT

export PATH=${repository_root}/tests/stubs:${PATH}
export GH_STRATADIFF_TEST_INSTALLER=${repository_root}/tests/fixtures/upstream-installer.sh
export GH_STRATADIFF_TEST_LOG=${temporary_directory}/gh.log
export GH_STRATADIFF_TEST_STATE=${temporary_directory}/tag-state
export GH_STRATADIFF_TEST_VERSION=0.4.0

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

reset_scenario() {
  export GH_STRATADIFF_TEST_SCENARIO=$1
  export GH_STRATADIFF_TEST_KERNEL=$2
  export GH_STRATADIFF_TEST_MACHINE=$3
  : > "${GH_STRATADIFF_TEST_LOG}"
  rm -f -- "${GH_STRATADIFF_TEST_STATE}"
}

expect_failure() {
  local label=$1
  shift
  if "$@" > "${temporary_directory}/${label}.out" 2>&1; then
    fail "expected failure: ${label}"
  fi
}

run_release_check_in_directory() {
  local directory=$1
  local check_script=$2
  local expected_commit=$3
  (
    cd -- "${directory}"
    "${check_script}" v0.4.0 "${expected_commit}"
  )
}

run_platform_case() {
  local kernel=$1
  local machine=$2
  local asset=$3
  local output=${temporary_directory}/success-${kernel}-${machine}
  reset_scenario success "${kernel}" "${machine}"
  "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 "${output}" "${asset}" >/dev/null
  [[ -x "${output}/${asset}" ]] || fail "${asset} was not executable"
  [[ "$("${output}/${asset}" --version)" == 'stratadiff 0.4.0' ]] || \
    fail "${asset} reports the wrong version"
  "${output}/${asset}" inbox --help >/dev/null || fail "${asset} lacks inbox"
  "${output}/${asset}" resume --help >/dev/null || fail "${asset} lacks resume"
  checksum_line="$(< "${output}/${asset}.sha256")"
  [[ "${checksum_line}" =~ ^[0-9a-f]{64}[[:space:]][[:space:]]${asset}$ ]] || \
    fail "${asset} checksum record is invalid"
  grep -F 'repos/gcomfident-crypto/stratadiff/contents/scripts/install-release.sh' \
    "${GH_STRATADIFF_TEST_LOG}" >/dev/null || fail 'installer was not fetched by immutable commit'
  grep -F 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
    "${GH_STRATADIFF_TEST_LOG}" >/dev/null || fail 'installer fetch was not pinned to the resolved commit'
  [[ "$(grep -c '^installer-tag=v0.4.0$' "${GH_STRATADIFF_TEST_LOG}")" -eq 1 ]] || \
    fail 'installer did not receive the exact release tag'
}

run_platform_case Linux x86_64 gh-stratadiff-linux-amd64
run_platform_case Linux aarch64 gh-stratadiff-linux-arm64
run_platform_case Darwin x86_64 gh-stratadiff-darwin-amd64
run_platform_case Darwin arm64 gh-stratadiff-darwin-arm64

trailing_tmp_parent=${temporary_directory}/trailing-tmp
mkdir "${trailing_tmp_parent}"
reset_scenario success Darwin arm64
TMPDIR="${trailing_tmp_parent}/" \
  "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 \
  "${temporary_directory}/trailing-tmp-output" gh-stratadiff-darwin-arm64 >/dev/null
installer_directory="$(
  grep '^installer-directory=' "${GH_STRATADIFF_TEST_LOG}"
)"
installer_directory=${installer_directory#installer-directory=}
[[ "${installer_directory}" != *//* ]] || \
  fail 'trailing-slash TMPDIR reached the upstream installer as a non-normalized path'

real_tmp_parent=${temporary_directory}/real-tmp
linked_tmp_parent=${temporary_directory}/linked-tmp
mkdir "${real_tmp_parent}"
ln -s "${real_tmp_parent}" "${linked_tmp_parent}"
reset_scenario success Darwin x86_64
TMPDIR="${linked_tmp_parent}/" \
  "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 \
  "${temporary_directory}/linked-tmp-output" gh-stratadiff-darwin-amd64 >/dev/null
installer_directory="$(
  grep '^installer-directory=' "${GH_STRATADIFF_TEST_LOG}"
)"
installer_directory=${installer_directory#installer-directory=}
[[ "${installer_directory}" == "${real_tmp_parent}/"* ]] || \
  fail 'symlink TMPDIR was not resolved before invoking the upstream installer'

reset_scenario mutable-release Linux x86_64
expect_failure mutable-release \
  "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 \
  "${temporary_directory}/mutable" gh-stratadiff-linux-amd64
[[ ! -e "${temporary_directory}/mutable" ]] || fail 'mutable release created output'
if grep -F '/contents/scripts/install-release.sh' "${GH_STRATADIFF_TEST_LOG}" >/dev/null; then
  fail 'mutable release fetched the installer'
fi

for scenario in draft-release prerelease invalid-tag-object empty-installer installer-failure \
  version-mismatch missing-inbox tag-drift; do
  reset_scenario "${scenario}" Linux x86_64
  output=${temporary_directory}/${scenario}
  expect_failure "${scenario}" \
    "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 \
    "${output}" gh-stratadiff-linux-amd64
  [[ ! -e "${output}/gh-stratadiff-linux-amd64" ]] || \
    fail "${scenario} left a promoted binary"
done

reset_scenario success Linux x86_64
expect_failure invalid-tag \
  "${repository_root}/scripts/promote-upstream-release.sh" latest \
  "${temporary_directory}/invalid-tag" gh-stratadiff-linux-amd64
[[ ! -s "${GH_STRATADIFF_TEST_LOG}" ]] || fail 'invalid tag contacted GitHub'

reset_scenario success Linux x86_64
expect_failure wrong-asset \
  "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 \
  "${temporary_directory}/wrong-asset" gh-stratadiff-linux-arm64
[[ ! -s "${GH_STRATADIFF_TEST_LOG}" ]] || fail 'wrong asset contacted GitHub'

reset_scenario success FreeBSD x86_64
expect_failure unsupported-platform \
  "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 \
  "${temporary_directory}/unsupported" gh-stratadiff-linux-amd64
[[ ! -s "${GH_STRATADIFF_TEST_LOG}" ]] || fail 'unsupported platform contacted GitHub'

reset_scenario success Linux x86_64
expect_failure relative-output \
  "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 relative \
  gh-stratadiff-linux-amd64
[[ ! -s "${GH_STRATADIFF_TEST_LOG}" ]] || fail 'relative output contacted GitHub'

reset_scenario success Linux x86_64
real_output_parent=${temporary_directory}/real-output-parent
linked_output_parent=${temporary_directory}/linked-output-parent
mkdir "${real_output_parent}"
ln -s "${real_output_parent}" "${linked_output_parent}"
expect_failure symlink-output \
  "${repository_root}/scripts/promote-upstream-release.sh" v0.4.0 \
  "${linked_output_parent}/dist" gh-stratadiff-linux-amd64
[[ ! -e "${real_output_parent}/dist" ]] || fail 'symlink output created a directory through its referent'
[[ ! -s "${GH_STRATADIFF_TEST_LOG}" ]] || fail 'symlink output contacted GitHub'

tag_repository=${temporary_directory}/tag-repository
git init --quiet "${tag_repository}"
git -C "${tag_repository}" config user.name 'StrataDiff Test'
git -C "${tag_repository}" config user.email 'stratadiff-test@example.invalid'
printf 'release fixture\n' > "${tag_repository}/tracked"
git -C "${tag_repository}" add tracked
git -C "${tag_repository}" commit --quiet -m fixture
tag_commit="$(git -C "${tag_repository}" rev-parse HEAD)"
git -C "${tag_repository}" tag -a v0.4.0 -m v0.4.0
[[ "$(cd -- "${tag_repository}" && \
  "${repository_root}/scripts/check-release-tag.sh" v0.4.0 "${tag_commit}")" == 0.4.0 ]] || \
  fail 'valid release tag was rejected'
printf 'dirty\n' > "${tag_repository}/untracked"
expect_failure dirty-release-checkout \
  run_release_check_in_directory "${tag_repository}" \
  "${repository_root}/scripts/check-release-tag.sh" "${tag_commit}"

reset_scenario success Linux x86_64
"${repository_root}/scripts/check-repository-policy.sh" >/dev/null
for scenario in \
  immutable-disabled \
  missing-ruleset \
  duplicate-ruleset \
  missing-bypass-actors \
  null-bypass-actors \
  extra-bypass-actors \
  invalid-ruleset
do
  reset_scenario "${scenario}" Linux x86_64
  expect_failure "policy-${scenario}" "${repository_root}/scripts/check-repository-policy.sh"
done
grep -F 'release tag ruleset is missing or does not match the fail-closed policy' \
  "${temporary_directory}/policy-missing-bypass-actors.out" >/dev/null || \
  fail 'repository policy did not fail closed when bypass_actors was absent'

release_assets=${temporary_directory}/release-assets
mkdir "${release_assets}"
asset_names=(
  gh-stratadiff-darwin-amd64
  gh-stratadiff-darwin-arm64
  gh-stratadiff-linux-amd64
  gh-stratadiff-linux-arm64
)
for asset in "${asset_names[@]}"; do
  printf 'fixture-%s\n' "${asset}" > "${release_assets}/${asset}"
  if command -v sha256sum >/dev/null 2>&1; then
    digest="$(sha256sum "${release_assets}/${asset}")"
    digest=${digest%% *}
  else
    digest="$(shasum -a 256 "${release_assets}/${asset}")"
    digest=${digest%% *}
  fi
  printf '%s  %s\n' "${digest}" "${asset}" > "${release_assets}/${asset}.sha256"
  printf '{}\n' > "${release_assets}/${asset}.intoto.jsonl"
done
reset_scenario success Linux x86_64
"${repository_root}/scripts/verify-release-assets.sh" \
  "${release_assets}" \
  gcomfident-crypto/gh-stratadiff \
  refs/tags/v0.4.0 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  gcomfident-crypto/gh-stratadiff/.github/workflows/release.yml
[[ "$(grep -c '^gh attestation verify ' "${GH_STRATADIFF_TEST_LOG}")" -eq 4 ]] || \
  fail 'all four extension attestations were not verified'

printf 'tampered\n' >> "${release_assets}/gh-stratadiff-linux-amd64"
expect_failure tampered-inventory \
  "${repository_root}/scripts/verify-release-assets.sh" "${release_assets}"

printf 'release contract tests passed\n'
