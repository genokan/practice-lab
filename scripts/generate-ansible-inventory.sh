#!/usr/bin/env sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
terraform_directory="$repository_root/infrastructure/terraform"
inventory_directory="$repository_root/infrastructure/ansible/inventory"
control_plane_ip=$(terraform -chdir="$terraform_directory" output -raw control_plane_ip)

mkdir -p "$inventory_directory"
cat > "$inventory_directory/hosts.yaml" <<EOF
all:
  children:
    k3s_servers:
      hosts:
        practice-cp-1:
          ansible_host: ${control_plane_ip}
          ansible_user: ansible
          ansible_ssh_common_args: '-o ProxyJump=bcant@mb1.opsguy.io'
EOF
