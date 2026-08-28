#!/usr/bin/env bash
set -euo pipefail

# Bootstrap only the conventional libvirt resources required by this repository.
# The script intentionally does not modify MB1's LAN, Wi-Fi, firewall, Docker, or
# Docker Swarm configuration.

action=${1:-}
libvirt_host=${LIBVIRT_HOST:-bcant@mb1.opsguy.io}

usage() {
  cat <<'USAGE'
Usage: scripts/bootstrap-libvirt.sh <apply|status|destroy|cleanup-session-artifact>

  apply    Define, start, and autostart libvirt's conventional default NAT network
           and default directory storage pool on MB1.
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

network_is_active() {
  virsh net-info "$network_name" | awk -F: '/^Active:/ { gsub(/[[:space:]]/, "", $2); exit($2 == "yes" ? 0 : 1) }'
}

pool_is_active() {
  virsh pool-info "$pool_name" | awk -F: '/^State:/ { gsub(/[[:space:]]/, "", $2); exit($2 == "running" ? 0 : 1) }'
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

virsh net-info "$network_name"
virsh pool-info "$pool_name"
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
