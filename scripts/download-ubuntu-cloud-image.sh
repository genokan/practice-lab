#!/usr/bin/env sh
set -eu

image_name="noble-server-cloudimg-arm64-20260826.img"
image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img"
image_sha256="afa139bac6f2629e1f2f8f34215f3a9ad9779801bcb945521ba1a45016743f"
repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image_directory="$repository_root/artifacts/images"
image_path="$image_directory/$image_name"

mkdir -p "$image_directory"

if [ ! -f "$image_path" ]; then
  curl --fail --location --retry 3 --output "$image_path.part" "$image_url"
  printf '%s  %s\n' "$image_sha256" "$image_path.part" | shasum -a 256 --check --status
  mv "$image_path.part" "$image_path"
fi

printf '%s  %s\n' "$image_sha256" "$image_path" | shasum -a 256 --check
