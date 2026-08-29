#!/usr/bin/env bash
set -euo pipefail

# Configure the non-secret Vault resources used by workload integrations.
#
# This script creates an empty KV v2 mount plus narrowly scoped, read-only policies
# and Kubernetes-auth roles. It never writes, reads, or prints a workload secret.
# Secret values are added separately with the normal Vault CLI or UI.

: "${VAULT_TOKEN:?Export a Vault operator token before running this script.}"

vault_addr=${VAULT_ADDR:-https://vault.opsguy.io}
auth_mount=kubernetes-practice-lab
kv_mount=practice-lab-kv
agent_audience=https://kubernetes.default.svc.cluster.local

export VAULT_ADDR="$vault_addr"

for command in vault jq; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

vault token lookup >/dev/null || {
  echo "VAULT_TOKEN cannot perform token lookup; use a Vault operator token." >&2
  exit 1
}

vault auth list -format=json | jq -e --arg mount "$auth_mount/" 'has($mount)' >/dev/null || {
  echo "Vault auth mount $auth_mount is missing; run configure-vault-pki.sh first." >&2
  exit 1
}

if ! vault secrets list -format=json | jq -e --arg mount "$kv_mount/" 'has($mount)' >/dev/null; then
  vault secrets enable -path="$kv_mount" kv-v2 >/dev/null
fi

for environment in staging prod; do
  namespace="hello-$environment"

  vault policy write "practice-lab-$environment-read" - >/dev/null <<POLICY
path "$kv_mount/data/$environment/*" {
  capabilities = ["read"]
}
POLICY

  vault write "auth/$auth_mount/role/eso-$environment" \
    bound_service_account_names=vault-secrets \
    bound_service_account_namespaces="$namespace" \
    audience="vault://$namespace/vault-secret-store" \
    policies="practice-lab-$environment-read" \
    ttl=1h >/dev/null

  vault write "auth/$auth_mount/role/workload-$environment" \
    bound_service_account_names=vault-workload \
    bound_service_account_namespaces="$namespace" \
    audience="$agent_audience" \
    policies="practice-lab-$environment-read" \
    ttl=1h >/dev/null
done

echo "Vault workload KV mount, policies, and Kubernetes auth roles configured."
