resource "libvirt_volume" "ubuntu_noble_arm64" {
  name = local.ubuntu_image_name
  pool = var.storage_pool

  create = {
    content = {
      url = abspath(local.ubuntu_image_path)
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "control_plane_root" {
  name          = "${var.control_plane_name}.qcow2"
  pool          = var.storage_pool
  capacity      = var.control_plane_disk_gib
  capacity_unit = "GiB"

  backing_store = {
    path = libvirt_volume.ubuntu_noble_arm64.path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "control_plane_cloud_init" {
  name = "${var.control_plane_name}-cloud-init.iso"
  pool = var.storage_pool

  create = {
    content = {
      url = libvirt_cloudinit_disk.control_plane.path
    }
  }

  target = {
    format = {
      type = "raw"
    }
  }
}

resource "libvirt_domain" "control_plane" {
  name        = var.control_plane_name
  type        = "kvm"
  memory      = var.control_plane_memory_mib
  memory_unit = "MiB"
  vcpu        = var.control_plane_vcpus
  autostart   = true
  running     = true

  os = {
    type         = "hvm"
    type_arch    = "aarch64"
    type_machine = "virt"
    firmware     = "efi"
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    controllers = [{
      type  = "scsi"
      index = 0
      model = "virtio-scsi"
    }]

    disks = [
      {
        device = "disk"
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          volume = {
            pool   = var.storage_pool
            volume = libvirt_volume.control_plane_root.name
          }
        }
        target = {
          bus = "virtio"
          dev = "vda"
        }
      },
      {
        device = "disk"
        driver = {
          name = "qemu"
          type = "raw"
        }
        source = {
          volume = {
            pool   = var.storage_pool
            volume = libvirt_volume.control_plane_cloud_init.name
          }
        }
        target = {
          bus = "scsi"
          dev = "sda"
        }
      },
    ]

    interfaces = [{
      mac = {
        address = var.control_plane_mac
      }
      model = {
        type = "virtio"
      }
      source = {
        network = {
          network = var.network_name
        }
      }
      wait_for_ip = {
        source  = "lease"
        timeout = 300
      }
    }]
  }
}
