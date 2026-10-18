#!/usr/bin/env bash
set +x
set -euo pipefail
umask 077

if [[ $# -gt 2 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf 'Usage: %s [secret-name.yaml] [certificate.crt]\n' "$0"
  printf 'Omitted input paths are prompted for; the default certificate is sealed-secrets-pub.crt at the repository root.\n'
  [[ $# -le 2 ]] && exit 0
  exit 1
fi
if ! command -v kubeseal >/dev/null 2>&1; then
  printf 'Required command is missing: kubeseal\n' >&2
  exit 1
fi
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
secret_file="${1:-}"
cert_file="${2:-}"
if [[ -z "$secret_file" ]]; then
  printf 'Secret YAML path: '
  IFS= read -r secret_file
fi
if [[ -z "$cert_file" ]]; then
  printf 'Public certificate path [%s/sealed-secrets-pub.crt]: ' "$repo_root"
  IFS= read -r cert_file
  cert_file="${cert_file:-$repo_root/sealed-secrets-pub.crt}"
fi
if [[ ! -f "$secret_file" || ! -r "$secret_file" || ! -s "$secret_file" ]]; then
  printf 'Secret YAML path must point to a readable, non-empty file.\n' >&2
  exit 1
fi
case "$secret_file" in
  *.yaml) output="${secret_file%.yaml}-sealed.yaml" ;;
  *.yml) output="${secret_file%.yml}-sealed.yaml" ;;
  *) printf 'Secret manifest must have a .yaml or .yml extension.\n' >&2; exit 1 ;;
esac
if [[ ! -f "$cert_file" || ! -r "$cert_file" || ! -s "$cert_file" ]]; then
  printf 'Public certificate path must point to a readable, non-empty file.\n' >&2
  exit 1
fi
# Keep paths beginning with a hyphen from being treated as command options.
output_dir="$(cd -- "$(dirname -- "$output")" && pwd)"
output="$output_dir/$(basename -- "$output")"
if [[ -d "$output" ]]; then
  printf 'Output path is a directory.\n' >&2
  exit 1
fi
staged_output=""
cleanup() {
  if [[ -n "$staged_output" ]]; then
    rm -f -- "$staged_output"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

staged_output="$(mktemp "$output_dir/.sealed.XXXXXX")"
# Seal offline. Suppress parser errors that could expose plaintext values.
if ! kubeseal --cert "$cert_file" --scope strict --format yaml \
  < "$secret_file" > "$staged_output" 2>/dev/null || [[ ! -s "$staged_output" ]]; then
  printf 'Sealing failed. Check the Secret manifest and public certificate. Existing output was preserved.\n' >&2
  exit 1
fi
mv -f -- "$staged_output" "$output"
staged_output=""

printf 'Generated: %s\n' "$output"
printf 'Sealed offline; controller decryption validation was not performed.\n'
