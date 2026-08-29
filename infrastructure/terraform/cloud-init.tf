locals {
  ubuntu_image_name = "noble-server-cloudimg-arm64.img"
  ubuntu_image_path = "${path.module}/../../artifacts/images/${local.ubuntu_image_name}"
  ssh_public_key    = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "libvirt_cloudinit_disk" "control_plane" {
  name = "${var.control_plane_name}-cloud-init.iso"

  meta_data = yamlencode({
    instance-id    = var.control_plane_name
    local-hostname = var.control_plane_name
  })

  user_data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
    hostname       = var.control_plane_name
    ssh_public_key = local.ssh_public_key
  })
}
