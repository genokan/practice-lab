#!/usr/bin/env bash
set -euo pipefail

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
terraform_directory="$repository_root/infrastructure/terraform"
known_hosts_directory="$repository_root/artifacts/ssh"
known_hosts_path="$known_hosts_directory/known_hosts"
control_plane_ip=$(terraform -chdir="$terraform_directory" output -raw control_plane_ip)

mkdir -p "$known_hosts_directory"

exec ssh \
  -o "UserKnownHostsFile=$known_hosts_path" \
  -o StrictHostKeyChecking=accept-new \
  -o ProxyJump=bcant@mb1.opsguy.io \
  "ansible@$control_plane_ip" \
  "$@"
