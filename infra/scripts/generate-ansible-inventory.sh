#!/usr/bin/env sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
terraform_directory="$repository_root/infra/terraform"
inventory_directory="$repository_root/infra/ansible/inventory"
known_hosts_directory="$repository_root/artifacts/ssh"
known_hosts_path="$known_hosts_directory/known_hosts"
control_plane_ip=$(terraform -chdir="$terraform_directory" output -raw control_plane_ip)

mkdir -p "$inventory_directory" "$known_hosts_directory"
cat > "$inventory_directory/hosts.yaml" <<EOF
all:
  children:
    k3s_servers:
      hosts:
        practice-cp-1:
          ansible_host: ${control_plane_ip}
          ansible_user: ansible
          ansible_ssh_common_args: '-o ProxyJump=bcant@mb1.opsguy.io -o UserKnownHostsFile=${known_hosts_path} -o StrictHostKeyChecking=accept-new'
EOF
