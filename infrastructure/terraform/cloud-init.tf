locals {
  ubuntu_image_name   = "noble-server-cloudimg-arm64-20260826.img"
  ubuntu_image_path   = "${path.module}/../../artifacts/images/${local.ubuntu_image_name}"
  ubuntu_image_sha256 = "afa139bac6f2629e1f2f8f34215f3a9ad9779801bcb945521ba1a45016743f"
  ssh_public_key      = trimspace(file(pathexpand(var.ssh_public_key_path)))
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
