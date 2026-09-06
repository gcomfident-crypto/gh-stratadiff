#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'verify-release-assets: %s\n' "$*" >&2
  exit 1
}

if [[ $# -ne 1 && $# -ne 5 ]]; then
  printf 'usage: scripts/verify-release-assets.sh DIRECTORY [REPOSITORY SOURCE_REF SOURCE_DIGEST SIGNER_WORKFLOW]\n' >&2
  exit 2
fi

asset_directory=$1
[[ -d "${asset_directory}" && ! -L "${asset_directory}" ]] || \
  die "asset directory is not a regular directory: ${asset_directory}"

asset_names=(
  gh-stratadiff-darwin-amd64
  gh-stratadiff-darwin-arm64
  gh-stratadiff-linux-amd64
  gh-stratadiff-linux-arm64
)
expected_files=()
for asset_name in "${asset_names[@]}"; do
  expected_files+=("${asset_name}" "${asset_name}.intoto.jsonl" "${asset_name}.sha256")
done

expected_inventory="$(printf '%s\n' "${expected_files[@]}" | LC_ALL=C sort)"
actual_inventory="$(
  (
    shopt -s dotglob nullglob
    for entry in "${asset_directory}"/*; do
      printf '%s\n' "${entry##*/}"
    done
  ) | LC_ALL=C sort
)"
if [[ "${actual_inventory}" != "${expected_inventory}" ]]; then
  printf 'release asset inventory is incomplete or contains unexpected files\n' >&2
  diff -u \
    <(printf '%s\n' "${expected_inventory}") \
    <(printf '%s\n' "${actual_inventory}") >&2 || true
  exit 1
fi

for asset_name in "${asset_names[@]}"; do
  asset_path=${asset_directory}/${asset_name}
  checksum_path=${asset_path}.sha256
  bundle_path=${asset_path}.intoto.jsonl
  [[ -f "${asset_path}" && ! -L "${asset_path}" && -s "${asset_path}" ]] || \
    die "release binary is not a nonempty regular file: ${asset_name}"
  [[ -f "${checksum_path}" && ! -L "${checksum_path}" && -s "${checksum_path}" ]] || \
    die "release checksum is not a nonempty regular file: ${asset_name}.sha256"
  [[ -f "${bundle_path}" && ! -L "${bundle_path}" && -s "${bundle_path}" ]] || \
    die "release attestation is not a nonempty regular file: ${asset_name}.intoto.jsonl"

  checksum_line="$(< "${checksum_path}")"
  [[ "${checksum_line}" =~ ^[0-9a-f]{64}[[:space:]][[:space:]]${asset_name}$ ]] || \
    die "invalid checksum record: ${asset_name}.sha256"
  expected_digest=${checksum_line%% *}
  if command -v sha256sum >/dev/null 2>&1; then
    actual_digest="$(sha256sum "${asset_path}")"
    actual_digest=${actual_digest%% *}
  elif command -v shasum >/dev/null 2>&1; then
    actual_digest="$(shasum -a 256 "${asset_path}")"
    actual_digest=${actual_digest%% *}
  else
    die 'sha256sum or shasum is required'
  fi
  [[ "${actual_digest}" == "${expected_digest}" ]] || \
    die "checksum mismatch: ${asset_name}"

  if [[ $# -eq 5 ]]; then
    command -v gh >/dev/null 2>&1 || die 'gh is required for attestation verification'
    gh attestation verify "${asset_path}" \
      --hostname github.com \
      --bundle "${bundle_path}" \
      --repo "$2" \
      --source-ref "$3" \
      --source-digest "$4" \
      --signer-workflow "$5" \
      --deny-self-hosted-runners >/dev/null
  fi
done
