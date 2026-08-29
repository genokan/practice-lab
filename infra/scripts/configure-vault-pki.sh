#!/usr/bin/env bash
set -euo pipefail

# Configure the Vault resources owned by practice-lab's cert-manager integration.
#
# This script needs a Vault token able to manage auth methods, policies, and the
# practice-lab-pki mount. It never reads or prints an existing Vault secret value.
# Kubernetes objects it relies on are declared in k8s/platform/tls/ and must already
# be synced by Argo CD. cert-manager uses TokenRequest JWTs; this script does not
# create or store a long-lived Kubernetes token in Vault.

: "${VAULT_TOKEN:?Export a Vault operator token before running this script.}"

vault_addr=${VAULT_ADDR:-https://vault.opsguy.io}
vault_public_addr=${VAULT_PUBLIC_ADDR:-https://vault.opsguy.io}
kubernetes_host=${KUBERNETES_HOST:-https://mb1.opsguy.io:6443}
auth_mount=kubernetes-practice-lab
pki_mount=practice-lab-pki
namespace=argocd
caddy_host=${CADDY_HOST:-bcant@192.168.4.10}
caddy_ca_path=${CADDY_CA_PATH:-/home/bcant/data/caddy/certs/practice-lab/vault-pki-ca.crt}

export VAULT_ADDR="$vault_addr"

for command in vault kubectl jq base64; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

vault token lookup >/dev/null || {
  echo "VAULT_TOKEN cannot perform token lookup; use a Vault operator token." >&2
  exit 1
}

kubernetes_ca=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
[[ -n "$kubernetes_ca" ]] || {
  echo "The current kubectl context has no embedded Kubernetes CA data." >&2
  exit 1
}

kubernetes_ca=$(printf '%s' "$kubernetes_ca" | base64 --decode)

if ! vault auth list -format=json | jq -e --arg mount "$auth_mount/" 'has($mount)' >/dev/null; then
  vault auth enable -path="$auth_mount" kubernetes >/dev/null
fi

vault write "auth/$auth_mount/config" \
  kubernetes_host="$kubernetes_host" \
  kubernetes_ca_cert="$kubernetes_ca" \
  disable_local_ca_jwt=true >/dev/null

if ! vault secrets list -format=json | jq -e --arg mount "$pki_mount/" 'has($mount)' >/dev/null; then
  vault secrets enable -path="$pki_mount" pki >/dev/null
  vault secrets tune -max-lease-ttl=87600h "$pki_mount" >/dev/null
  vault write -field=certificate "$pki_mount/root/generate/internal" \
    common_name="Practice Lab Root CA" \
    ttl=87600h >/dev/null
fi

vault write "$pki_mount/config/urls" \
  issuing_certificates="$vault_public_addr/v1/$pki_mount/ca" \
  crl_distribution_points="$vault_public_addr/v1/$pki_mount/crl" >/dev/null

vault write "$pki_mount/roles/argocd-edge" \
  allowed_domains=argo.opsguy.io \
  allow_bare_domains=true \
  allow_subdomains=false \
  key_type=ec \
  key_bits=256 \
  max_ttl=720h >/dev/null
vault patch "$pki_mount/roles/argocd-edge" require_cn=false >/dev/null

vault write "$pki_mount/roles/argocd-server" \
  allowed_domains=argocd.svc,argocd.svc.cluster.local \
  allow_bare_domains=false \
  allow_subdomains=true \
  key_type=ec \
  key_bits=256 \
  max_ttl=720h >/dev/null
vault patch "$pki_mount/roles/argocd-server" require_cn=false >/dev/null

vault policy write cert-manager-argocd-edge - >/dev/null <<POLICY
path "$pki_mount/sign/argocd-edge" {
  capabilities = ["update"]
}
POLICY

vault policy write cert-manager-argocd-server - >/dev/null <<POLICY
path "$pki_mount/sign/argocd-server" {
  capabilities = ["update"]
}
POLICY

vault write "auth/$auth_mount/role/cert-manager-argocd-edge" \
  bound_service_account_names=vault-pki-edge-issuer \
  bound_service_account_namespaces="$namespace" \
  audience="vault://$namespace/vault-pki-edge" \
  policies=cert-manager-argocd-edge \
  ttl=1m >/dev/null

vault write "auth/$auth_mount/role/cert-manager-argocd-server" \
  bound_service_account_names=vault-pki-server-issuer \
  bound_service_account_namespaces="$namespace" \
  audience="vault://$namespace/vault-pki-server" \
  policies=cert-manager-argocd-server \
  ttl=1m >/dev/null

echo "Vault PKI and Kubernetes auth configured for practice-lab."

if [[ "${INSTALL_CADDY_CA:-0}" == "1" ]]; then
  caddy_ca_dir=$(dirname "$caddy_ca_path")
  vault read -field=certificate "$pki_mount/cert/ca" | \
    ssh "$caddy_host" "install -d -m 0755 '$caddy_ca_dir' && cat > '$caddy_ca_path'"
  echo "Installed the public Vault PKI CA for Caddy at $caddy_host:$caddy_ca_path."
fi
