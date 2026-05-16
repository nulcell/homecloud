#!/usr/bin/env bash
# Idempotent install of the core components onto a freshly-bootstrapped Talos cluster.
# Pre-reqs: kubeconfig in env, talosctl bootstrap already done, node is Ready=False.
#
# Usage:
#   export KUBECONFIG=/path/to/kubeconfig
#   ./bootstrap/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Versions (keep in sync with docs/bootstrap.md) -----------------------------
GATEWAY_API_VERSION="v1.4.1"
CILIUM_VERSION="1.19.4"
CERT_MANAGER_VERSION="v1.20.2"
LONGHORN_VERSION="1.11.2"
METRICS_SERVER_VERSION="3.13.0"
ARGOCD_VERSION="9.5.14"

# --- Helm repos -----------------------------------------------------------------
helm repo add cilium https://helm.cilium.io 2>/dev/null || true
helm repo add longhorn https://charts.longhorn.io 2>/dev/null || true
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server 2>/dev/null || true
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

# --- Gateway API CRDs (must precede Cilium) -------------------------------------
echo "==> Gateway API CRDs"
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
# kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml"

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

# --- cert-manager ---------------------------------------------------------------
echo "==> cert-manager ${CERT_MANAGER_VERSION}"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version "${CERT_MANAGER_VERSION}" \
  --values "${SCRIPT_DIR}/cert-manager-values.yaml" \
  --wait

# --- Longhorn -------------------------------------------------------------------
echo "==> Longhorn ${LONGHORN_VERSION}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
EOF
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version "${LONGHORN_VERSION}" \
  --values "${SCRIPT_DIR}/longhorn-values.yaml" \
  --wait

# --- metrics-server -------------------------------------------------------------
echo "==> metrics-server ${METRICS_SERVER_VERSION}"
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version "${METRICS_SERVER_VERSION}" \
  --values "${SCRIPT_DIR}/metrics-server-values.yaml" \
  --wait

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

echo
echo "Bootstrap complete."
echo "Next: apply gitops/root/root-app.yaml after editing the repoURL."
echo
echo "Initial ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
