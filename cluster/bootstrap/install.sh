#!/usr/bin/env bash
# Idempotent install of the core components onto a freshly-bootstrapped Talos cluster.
# Pre-reqs: kubeconfig in env, talosctl bootstrap already done, node is Ready=False.
#
# Usage:
#   export KUBECONFIG=/path/to/kubeconfig
#   ./cluster/bootstrap/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Versions (keep in sync with docs/bootstrap.md) -----------------------------
# cert-manager, Longhorn, and metrics-server are now managed by Argo CD; see
# gitops/infrastructure/{cert-manager,longhorn,metrics-server}/ for their versions.
GATEWAY_API_VERSION="v1.4.1"
CILIUM_VERSION="1.19.4"
ARGOCD_VERSION="9.5.15"

# --- Helm repos -----------------------------------------------------------------
helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

# --- Gateway API CRDs (must precede Cilium) -------------------------------------
echo "==> Gateway API CRDs"
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml" --server-side
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml" --server-side

# --- Cilium ---------------------------------------------------------------------
echo "==> Cilium ${CILIUM_VERSION}"
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version "${CILIUM_VERSION}" \
  --values "${SCRIPT_DIR}/cilium-values.yaml" \
  --wait

kubectl -n kube-system rollout status ds/cilium --timeout=5m

echo "==> Cilium L2 pool + announcement policy"
kubectl apply -f "${SCRIPT_DIR}/cilium-l2.yaml"

# --- ArgoCD ---------------------------------------------------------------------
echo "==> Argo CD ${ARGOCD_VERSION}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF
# The SOPS age key must exist before the repo-server starts, or pods will crashloop.
if ! kubectl -n argocd get secret argocd-sops-age >/dev/null 2>&1; then
  echo "  -- creating argocd-sops-age from \$HOME/.config/sops/age/keys.txt"
  kubectl -n argocd create secret generic argocd-sops-age \
    --from-file=key.txt="${HOME}/.config/sops/age/keys.txt"
fi

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version "${ARGOCD_VERSION}" \
  --values "${SCRIPT_DIR}/argocd-values.yaml" \
  --wait

# --- Root Application -----------------------------------------------------------
# Hands the cluster off to GitOps. cert-manager, Longhorn, and metrics-server
# come up via gitops/infrastructure/* from here on.
echo "==> Root Application"
kubectl apply -f "${SCRIPT_DIR}/../../gitops/root/root-app.yaml"

echo
echo "Bootstrap complete."
echo "Argo CD will now reconcile gitops/infrastructure/* and gitops/apps/*."
echo
echo "Initial ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
