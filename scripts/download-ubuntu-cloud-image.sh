#!/usr/bin/env bash
set -euo pipefail

image_name="noble-server-cloudimg-arm64.img"
image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img"
checksum_url="https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image_directory="$repository_root/artifacts/images"
image_path="$image_directory/$image_name"

mkdir -p "$image_directory"

image_sha256=$(curl --fail --location --retry 3 --silent --show-error "$checksum_url" | awk '$2 == "*noble-server-cloudimg-arm64.img" { checksum = $1 } END { if (checksum == "") exit 1; print checksum }')

if [ ! -f "$image_path" ]; then
  printf 'Downloading %s\n' "$image_name"
  curl --fail --location --retry 3 --progress-bar --output "$image_path.part" "$image_url"
  printf '%s  %s\n' "$image_sha256" "$image_path.part" | shasum -a 256 --check --status
  mv "$image_path.part" "$image_path"
fi

printf '%s  %s\n' "$image_sha256" "$image_path" | shasum -a 256 --check
printf 'Verified SHA-256: %s\n' "$image_sha256"
