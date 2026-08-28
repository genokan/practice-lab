#!/usr/bin/env bash
set -euo pipefail

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
kubectl_command="$repository_root/scripts/kubectl-practice-lab.sh"
test_pod=phase2-connectivity

cleanup() {
  "$kubectl_command" delete pod "$test_pod" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$kubectl_command" get nodes
"$kubectl_command" rollout status deployment/coredns -n kube-system --timeout=120s
"$kubectl_command" get pods -n kube-system
"$kubectl_command" run "$test_pod" \
  --image=busybox:1.37.0 \
  --restart=Never \
  --command -- sh -ec 'nslookup kubernetes.default.svc.cluster.local && wget -qO- --timeout=10 https://example.com >/dev/null'
"$kubectl_command" wait --for=condition=Ready "pod/$test_pod" --timeout=60s || true
"$kubectl_command" wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$test_pod" --timeout=120s
"$kubectl_command" logs "$test_pod"
