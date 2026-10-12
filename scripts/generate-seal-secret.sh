#!/usr/bin/env bash
set +x
set -euo pipefail
umask 077

cluster_id="${1:-001}"
if [[ ! "$cluster_id" =~ ^[0-9]{3}$ ]]; then
  printf 'CLUSTER must be a three-digit cluster ID.\n' >&2
  exit 1
fi
for tool in kubectl kubeseal awk; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required command is missing: %s\n' "$tool" >&2
    exit 1
  fi
done
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
kubeconfig="$repo_root/.local/config/$cluster_id/kubeconfig.yaml"
if [[ ! -r "$kubeconfig" ]]; then
  printf 'Cluster kubeconfig is missing or unreadable.\n' >&2
  exit 1
fi

printf 'SealedSecret name: '
IFS= read -r secret_name
printf 'Namespace: '
IFS= read -r namespace
printf '.env path: '
IFS= read -r env_file

if [[ ! "$secret_name" =~ ^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$ || ${#secret_name} -gt 253 ]]; then
  printf 'Use a Kubernetes Secret name with lowercase letters, digits, hyphens, or dots.\n' >&2
  exit 1
fi
if [[ ! "$namespace" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ || ${#namespace} -gt 63 ]]; then
  printf 'Use a namespace with lowercase letters, digits, or hyphens (at most 63 characters).\n' >&2
  exit 1
fi
if [[ ! -f "$env_file" || ! -r "$env_file" || ! -s "$env_file" ]]; then
  printf '.env path must point to a readable, non-empty file.\n' >&2
  exit 1
fi
# Require explicit assignments: kubectl also accepts bare keys and reads their
# values from the process environment, which is unsuitable for this workflow.
if ! awk '
  /^[[:space:]]*(#|$)/ { next }
  {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    if (line !~ /^[A-Za-z0-9._-]+=/) invalid = 1
    count++
  }
  END { exit (invalid || count == 0) }
' < "$env_file"; then
  printf '.env must contain explicit KEY=value assignments, with no export statements or bare keys.\n' >&2
  exit 1
fi

output_dir="$repo_root/.local/generated/sealed-secrets/$cluster_id/$namespace"
output="$output_dir/$secret_name.yaml"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/homelab-seal.XXXXXX")"
staged_output=""
cleanup() {
  rm -rf -- "$work_dir"
  if [[ -n "$staged_output" ]]; then
    rm -f -- "$staged_output"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

controller=(--kubeconfig "$kubeconfig" --controller-name sealed-secrets-controller --controller-namespace sealed-secrets)
kubeseal "${controller[@]}" --fetch-cert > "$work_dir/cert.pem"
mkdir -p -- "$output_dir"
staged_output="$(mktemp "$output_dir/.sealed.XXXXXX")"
# Never source the .env file. Keep the plaintext Secret in the pipe only.
# Tool errors are withheld here because malformed input can expose secret values.
if ! kubectl --kubeconfig "$kubeconfig" -n "$namespace" create secret generic "$secret_name" \
  --from-env-file="$env_file" --dry-run=client -o json 2>/dev/null |
  kubeseal --cert "$work_dir/cert.pem" --scope strict --format yaml > "$staged_output" 2>/dev/null; then
  printf 'Sealing failed. Check the name and .env format (KEY=value, no shell syntax). Existing output was preserved.\n' >&2
  exit 1
fi
if ! kubeseal "${controller[@]}" --validate < "$staged_output"; then
  printf 'Decryption validation failed. Existing output was preserved.\n' >&2
  exit 1
fi
mv -- "$staged_output" "$output"
staged_output=""

printf 'Generated: %s\n' "$output"
printf 'Copy this encrypted YAML into your application manifest source, then commit and push.\n'
