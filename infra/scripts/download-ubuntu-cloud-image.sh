#!/usr/bin/env bash
set -euo pipefail

image_name="noble-server-cloudimg-arm64.img"
image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img"
checksum_url="https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
image_directory="$repository_root/artifacts/images"
image_path="$image_directory/$image_name"
checksum_path="$image_path.sha256"

mkdir -p "$image_directory"

verify_cached_image() {
  image_sha256=$(tr -d '[:space:]' < "$checksum_path")
  if [[ ! "$image_sha256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Invalid cached SHA-256 file: $checksum_path" >&2
    return 1
  fi

  printf '%s  %s\n' "$image_sha256" "$image_path" | shasum -a 256 --check
}

case "${1:-}" in
  "")
    if [ -f "$image_path" ] && [ -f "$checksum_path" ]; then
      verify_cached_image
      echo "Using verified cached image: $image_path"
      exit 0
    fi

    if [ -e "$image_path" ] || [ -e "$checksum_path" ]; then
      echo "Incomplete image cache; run $0 --refresh to replace it." >&2
      exit 1
    fi
    ;;
  --refresh)
    ;;
  *)
    echo "Usage: $0 [--refresh]" >&2
    exit 2
    ;;
esac

image_sha256=$(curl --fail --location --retry 3 --silent --show-error "$checksum_url" | awk '$2 == "*noble-server-cloudimg-arm64.img" { checksum = $1 } END { if (checksum == "") exit 1; print checksum }')

printf 'Downloading %s\n' "$image_name"
curl --fail --location --retry 3 --progress-bar --output "$image_path.part" "$image_url"
printf '%s  %s\n' "$image_sha256" "$image_path.part" | shasum -a 256 --check --status
mv "$image_path.part" "$image_path"
printf '%s\n' "$image_sha256" > "$checksum_path"

verify_cached_image
printf 'Verified SHA-256: %s\n' "$image_sha256"
