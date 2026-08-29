#!/usr/bin/env bash
set -euo pipefail

# Bootstrap only the conventional libvirt resources required by this repository.
# The script intentionally does not modify MB1's LAN, Wi-Fi, or Docker Swarm
# configuration. It adds narrowly scoped rules to Docker's intended DOCKER-USER
# extension chain for default-libvirt guest egress. A systemd TCP proxy exposes the
# k3s API on MB1 without changing the guest network.

action=${1:-}
libvirt_host=${LIBVIRT_HOST:-bcant@mb1.opsguy.io}

usage() {
  cat <<'USAGE'
Usage: scripts/bootstrap-libvirt.sh <apply|status|destroy|cleanup-session-artifact>

  apply    Define, start, and autostart libvirt's conventional default NAT network
           and default directory storage pool on MB1. Also install the narrowly
           scoped forwarding rule required for guest egress and the k3s API proxy
           on mb1.opsguy.io:6443.
  status   Print the current state of those resources.
  destroy  Stop and undefine those resources only when no libvirt domains and no
           volumes remain in the default pool. It never removes the image directory.
  cleanup-session-artifact
           Remove the inactive per-user default network left by the pre-system-URI
           bootstrap bug. Refuses if that session network is active.

Set LIBVIRT_HOST to override the default SSH destination.
USAGE
}

case "$action" in
  apply)
    ssh "$libvirt_host" 'bash -s' <<'REMOTE'
set -euo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///system

network_name=default
network_xml=/etc/libvirt/qemu/networks/default.xml
pool_name=default
pool_target=/var/lib/libvirt/images
forwarding_helper_path=/usr/local/libexec/practice-lab-libvirt-forward.sh
forwarding_service_path=/etc/systemd/system/practice-lab-libvirt-forward.service
k3s_api_service_path=/etc/systemd/system/practice-lab-k3s-api.service

network_is_active() {
  virsh net-info "$network_name" | awk -F: '/^Active:/ { gsub(/[[:space:]]/, "", $2); active = $2 } END { exit(active == "yes" ? 0 : 1) }'
}

pool_is_active() {
  virsh pool-info "$pool_name" | awk -F: '/^State:/ { gsub(/[[:space:]]/, "", $2); state = $2 } END { exit(state == "running" ? 0 : 1) }'
}

if ! virsh net-info "$network_name" >/dev/null 2>&1; then
  # Fedora restricts /etc/libvirt to root. Read the existing definition without
  # copying it to a persistent temporary file, then define it as the libvirt user.
  sudo -n cat "$network_xml" | virsh net-define /dev/stdin
fi

virsh net-autostart "$network_name"
if ! network_is_active; then
  # Autostart can race with this explicit request; accept an already-active result.
  virsh net-start "$network_name" || network_is_active
fi

if ! virsh pool-info "$pool_name" >/dev/null 2>&1; then
  test -d "$pool_target"
  virsh pool-define-as "$pool_name" dir --target "$pool_target"
fi

virsh pool-autostart "$pool_name"
if ! pool_is_active; then
  virsh pool-start "$pool_name" || pool_is_active
fi

# Docker owns a base FORWARD chain with a drop policy on MB1. Libvirt's standard
# NAT table is present, but its guest traffic cannot reach postrouting. DOCKER-USER
# is Docker's supported extension point; these exact rules permit only virbr0 egress
# and established replies, leaving all other Docker forwarding behavior unchanged.
sudo -n install -d -m 0755 /usr/local/libexec
sudo -n tee "$forwarding_helper_path" >/dev/null <<'FORWARD_HELPER'
#!/usr/bin/env bash
set -euo pipefail

egress_rule=(-i virbr0 -m comment --comment practice-lab-libvirt-egress -j ACCEPT)
reply_rule=(-o virbr0 -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment practice-lab-libvirt-reply -j ACCEPT)

ensure_rule() {
  local table=$1
  local chain=$2
  shift 2
  if ! iptables -t "$table" -C "$chain" "$@"; then
    iptables -t "$table" -I "$chain" 1 "$@"
  fi
}

remove_rule() {
  local table=$1
  local chain=$2
  shift 2
  while iptables -t "$table" -C "$chain" "$@"; do
    iptables -t "$table" -D "$chain" "$@"
  done
}

case "${1:-}" in
  apply)
    ensure_rule filter DOCKER-USER "${egress_rule[@]}"
    ensure_rule filter DOCKER-USER "${reply_rule[@]}"
    ;;
  remove)
    remove_rule filter DOCKER-USER "${egress_rule[@]}"
    remove_rule filter DOCKER-USER "${reply_rule[@]}"
    ;;
  *)
    echo "Usage: $0 <apply|remove>" >&2
    exit 2
    ;;
esac
FORWARD_HELPER
sudo -n chmod 0755 "$forwarding_helper_path"

sudo -n tee "$forwarding_service_path" >/dev/null <<'UNIT'
[Unit]
Description=Allow default libvirt NAT guest egress through Docker's DOCKER-USER chain
After=network-online.target docker.service libvirtd.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/practice-lab-libvirt-forward.sh apply
ExecStop=/usr/local/libexec/practice-lab-libvirt-forward.sh remove
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

sudo -n systemctl daemon-reload
sudo -n systemctl enable practice-lab-libvirt-forward.service
sudo -n systemctl restart practice-lab-libvirt-forward.service

control_plane_ip=$(virsh domifaddr practice-cp-1 --source lease 2>/dev/null | awk '/ipv4/ { split($4, address, "/"); print address[1]; exit }')
mb1_lan_ip=$(ip -4 -o addr show dev wld0 | awk '{ split($4, address, "/"); print address[1]; exit }')
if [[ -n "$control_plane_ip" && -n "$mb1_lan_ip" ]]; then
  # Remove the temporary DNAT attempt from earlier bootstrap revisions. A local TCP
  # proxy is simpler and works with libvirt's intentionally inbound-restrictive NAT.
  sudo -n iptables -D DOCKER-USER -i wld0 -o virbr0 -p tcp -d "$control_plane_ip" --dport 6443 -m comment --comment practice-lab-k3s-api -j ACCEPT 2>/dev/null || true
  sudo -n iptables -t nat -D PREROUTING -i wld0 -p tcp --dport 6443 -m comment --comment practice-lab-k3s-api -j DNAT --to-destination "$control_plane_ip:6443" 2>/dev/null || true

  sudo -n systemctl disable --now practice-lab-k3s-api.socket 2>/dev/null || true
  sudo -n rm -f /etc/systemd/system/practice-lab-k3s-api.socket

  sudo -n tee "$k3s_api_service_path" >/dev/null <<UNIT
[Unit]
Description=Proxy the practice-lab k3s API through MB1
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/ncat --listen --keep-open ${mb1_lan_ip} 6443 --sh-exec '/usr/bin/ncat ${control_plane_ip} 6443'
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
  sudo -n systemctl daemon-reload
  sudo -n systemctl enable practice-lab-k3s-api.service
  sudo -n systemctl restart practice-lab-k3s-api.service
fi

virsh net-info "$network_name"
virsh pool-info "$pool_name"
sudo -n systemctl is-active practice-lab-libvirt-forward.service
REMOTE
    ;;
  status)
    ssh "$libvirt_host" 'export LIBVIRT_DEFAULT_URI=qemu:///system; virsh net-info default || true; if virsh pool-info default; then virsh vol-list default; fi; virsh list --all'
    ;;
  destroy)
    ssh "$libvirt_host" 'bash -s' <<'REMOTE'
set -euo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///system

network_name=default
pool_name=default
forwarding_helper_path=/usr/local/libexec/practice-lab-libvirt-forward.sh
forwarding_service_path=/etc/systemd/system/practice-lab-libvirt-forward.service
k3s_api_service_path=/etc/systemd/system/practice-lab-k3s-api.service

if virsh list --all --name | grep -q "[^[:space:]]"; then
  echo "Refusing to remove shared libvirt defaults while domains still exist." >&2
  virsh list --all >&2
  exit 1
fi

if virsh pool-info "$pool_name" >/dev/null 2>&1 && virsh vol-list "$pool_name" --name | grep -q "[^[:space:]]"; then
  echo "Refusing to remove the default pool while volumes still exist." >&2
  virsh vol-list "$pool_name" >&2
  exit 1
fi

if virsh net-info "$network_name" >/dev/null 2>&1; then
  virsh net-destroy "$network_name" 2>/dev/null || true
  virsh net-undefine "$network_name"
fi

if virsh pool-info "$pool_name" >/dev/null 2>&1; then
  virsh pool-destroy "$pool_name" 2>/dev/null || true
  virsh pool-undefine "$pool_name"
fi

sudo -n systemctl disable --now practice-lab-libvirt-forward.service 2>/dev/null || true
sudo -n systemctl disable --now practice-lab-k3s-api.socket practice-lab-k3s-api.service 2>/dev/null || true
sudo -n rm -f "$forwarding_service_path" "$forwarding_helper_path" /etc/systemd/system/practice-lab-k3s-api.socket "$k3s_api_service_path"
sudo -n systemctl daemon-reload
REMOTE
    ;;
  cleanup-session-artifact)
    ssh "$libvirt_host" 'bash -s' <<'REMOTE'
set -euo pipefail
export LIBVIRT_DEFAULT_URI=qemu:///session

if ! virsh net-info default >/dev/null 2>&1; then
  exit 0
fi

if virsh net-info default | awk -F: '/^Active:/ { gsub(/[[:space:]]/, "", $2); exit($2 == "yes" ? 0 : 1) }'; then
  echo "Refusing to remove an active per-user default network." >&2
  exit 1
fi

virsh net-undefine default
REMOTE
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
