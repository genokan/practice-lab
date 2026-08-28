# Architecture Decisions

## 2026-08-28: Reuse libvirt defaults with repository-owned bootstrap

`practice-lab` uses libvirt's conventional `default` NAT network (`192.168.122.0/24`)
and its conventional `default` directory storage pool (`/var/lib/libvirt/images`) on
MB1. It does not create a project-specific LAN bridge or a second private subnet.

MB1 had the default network XML and image directory but neither object was registered
with libvirt. `scripts/bootstrap-libvirt.sh` is therefore the sole documented mechanism
to define, start, and autostart these prerequisites. Its guarded destroy action only
undefines them after every libvirt domain and volume is gone; it does not remove their
host directory.
