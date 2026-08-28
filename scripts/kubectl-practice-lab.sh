#!/usr/bin/env bash
set -euo pipefail

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
terraform_directory="$repository_root/infrastructure/terraform"
kubeconfig_path="$repository_root/kubeconfig/practice-lab.yaml"
control_plane_ip=$(terraform -chdir="$terraform_directory" output -raw control_plane_ip)

if [[ ! -f "$kubeconfig_path" ]]; then
  printf 'Kubeconfig not found. Run `make k3s` first.\n' >&2
  exit 1
fi

ssh \
  -o ExitOnForwardFailure=yes \
  -o ConnectTimeout=10 \
  -N \
  -L "127.0.0.1:6443:${control_plane_ip}:6443" \
  bcant@mb1.opsguy.io &
tunnel_pid=$!

cleanup() {
  kill "$tunnel_pid" 2>/dev/null || true
  wait "$tunnel_pid" 2>/dev/null || true
}
trap cleanup EXIT

sleep 1
KUBECONFIG="$kubeconfig_path" kubectl "$@"
