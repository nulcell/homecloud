#!/usr/bin/env bash
# Clean up everything left behind by a decommissioned Rancher install.
# Uses `while read` (not `mapfile`) so it runs on macOS's bash 3.2 too.
#
# Usage:
#   scripts/cleanup-rancher.sh                # dry-run (default)
#   DRY_RUN=0 scripts/cleanup-rancher.sh      # actually delete
#
# Safe to re-run (idempotent). Read each section before running.
#
# Order matters:
#   1. Admission webhooks   — block all other ops by calling a gone service
#   2. APIServices          — stale discovery refs break `kubectl get`
#   3. CR finalizers + CRDs — controllers are gone, finalizers will never clear
#   4. Stuck namespaces     — force-clear via /finalize subresource
#   5. Cluster RBAC         — ClusterRoles/Bindings owned by rancher
#   6. NS labels/annotations on namespaces you want to KEEP (e.g. `media`)

set -uo pipefail

DRY_RUN="${DRY_RUN:-1}"

# Namespaces we will never touch the contents of (only clean labels off).
PRESERVE_NS_REGEX='^(default|kube-system|kube-public|kube-node-lease)$'

# Rancher-owned CRD API groups (everything under cattle.io / rancher.io).
RANCHER_CRD_REGEX='\.(cattle|rancher)\.io$'

# Pattern for Rancher-managed namespaces. Matches:
#   cattle-*              every Rancher install namespace family
#   fleet-default,        Fleet's workspace namespaces
#   fleet-local
#   local                 Rancher's "local" cluster name (NOT a workload ns)
#   rancher               the install namespace itself
#   p-XXXXX               Rancher auto-generated project namespaces
#   user-XXXXX            Rancher auto-generated user namespaces
RANCHER_NS_REGEX='^(cattle-.*|fleet-default|fleet-local|local|rancher|p-[a-z0-9]+|user-[a-z0-9]+)$'

say()  { printf '\n=== %s ===\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

# Wrap a destructive command. Echoes when DRY_RUN=1, runs otherwise.
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  [dry-run] %s\n' "$*"
  else
    printf '  > %s\n' "$*"
    "$@" || warn "command failed (continuing): $*"
  fi
}

if [[ "$DRY_RUN" == "1" ]]; then
  echo ">>> DRY RUN — nothing will be modified. Re-run with DRY_RUN=0 to apply."
fi

# ----- 0. ArgoCD applications referencing rancher --------------------------
# Argo's Application has a `resources-finalizer.argocd.argoproj.io` finalizer
# that blocks deletion until reconciliation succeeds. If the git source path
# has been removed, reconciliation fails forever and the Application is stuck.
# Strip the finalizer so Argo just deletes the Application object directly —
# the managed resources are being cleaned up by the sections below anyway.
say "0. Stuck ArgoCD applications (rancher)"
if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
  for kind in application applicationset; do
    kubectl get "$kind" -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null \
      | grep -iE '/.*rancher' \
      | while IFS=/ read -r ns name; do
          [[ -z "$ns" || -z "$name" ]] && continue
          run kubectl -n "$ns" patch "$kind" "$name" --type=merge -p '{"metadata":{"finalizers":null}}'
          run kubectl -n "$ns" delete "$kind" "$name" --ignore-not-found
        done
  done
else
  echo "  (no ArgoCD CRDs found — skipping)"
fi

# ----- 1. Webhooks ----------------------------------------------------------
say "1. Admission webhooks (rancher.cattle.io.*)"
kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration -o name \
  | grep -E 'rancher|cattle' \
  | while IFS= read -r w; do
      [[ -z "$w" ]] && continue
      run kubectl delete "$w" --ignore-not-found
    done

# ----- 2. APIServices -------------------------------------------------------
say "2. APIServices (v1.ext.cattle.io etc.)"
kubectl get apiservice -o name \
  | grep -E '\.(cattle|rancher)\.io' \
  | while IFS= read -r a; do
      [[ -z "$a" ]] && continue
      run kubectl delete "$a" --ignore-not-found
    done

# ----- 3. CRs (strip finalizers) + CRDs -------------------------------------
say "3. Custom resources + CRDs"
# Loop variable can't carry out of a piped while in bash, so collect first.
crds=$(kubectl get crd -o name | grep -E "$RANCHER_CRD_REGEX" || true)
for crd in $crds; do
  crd_name="${crd#customresourcedefinition.apiextensions.k8s.io/}"

  # Namespaced CRs of this kind — clear finalizers so they actually delete.
  kubectl get "$crd_name" --all-namespaces \
       -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' 2>/dev/null \
    | while IFS=$'\t' read -r ns name; do
        [[ -z "${ns:-}" || -z "${name:-}" ]] && continue
        run kubectl -n "$ns" patch "$crd_name" "$name" --type=merge -p '{"metadata":{"finalizers":null}}'
      done

  # Cluster-scoped CRs of this kind.
  for n in $(kubectl get "$crd_name" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    run kubectl patch "$crd_name" "$n" --type=merge -p '{"metadata":{"finalizers":null}}'
  done

  # Delete the CRD (cascades to any remaining CRs).
  run kubectl delete "$crd" --ignore-not-found --wait=false
done

# ----- 4. Stuck namespaces --------------------------------------------------
# Rancher's wrangler-based controllers (auth-prov-v2, capi, etc.) add
# finalizers like `wrangler.cattle.io/auth-prov-v2-rb` to STANDARD k8s
# resources (Role, RoleBinding, Secret, ConfigMap, ServiceAccount). With
# those controllers gone the finalizers stick — which keeps NS deletion
# stuck on "Some resources are remaining: rolebindings has 2 instances".
# Strip finalizers from these resource types in each Rancher namespace
# before patching /finalize. Safe: the namespace is about to be deleted.
say "4. Rancher-owned namespaces (force-terminate)"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  [[ "$ns" =~ $RANCHER_NS_REGEX ]] || continue
  echo "  $ns"

  for kind in role rolebinding secret configmap serviceaccount networkpolicy; do
    kubectl -n "$ns" get "$kind" -o name 2>/dev/null | while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      fin=$(kubectl -n "$ns" get "$r" -o jsonpath='{.metadata.finalizers}' 2>/dev/null)
      [[ -z "$fin" || "$fin" == '[]' ]] && continue
      run kubectl -n "$ns" patch "$r" --type=merge -p '{"metadata":{"finalizers":null}}'
    done
  done

  # /finalize subresource patch clears the 'kubernetes' NS-level finalizer.
  # Requires kubectl 1.27+.
  run kubectl patch ns "$ns" --subresource=finalize --type=merge -p '{"spec":{"finalizers":[]}}'
  run kubectl delete ns "$ns" --ignore-not-found --wait=false
done

# ----- 5. Cluster RBAC ------------------------------------------------------
say "5. Cluster RBAC (rancher / cattle / fleet)"
kubectl get clusterrolebinding -o name \
  | grep -E '(^|/)(rancher|cattle|fleet)' \
  | while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      run kubectl delete "$r" --ignore-not-found
    done
kubectl get clusterrole -o name \
  | grep -E '(^|/)(rancher|cattle|fleet)' \
  | while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      run kubectl delete "$r" --ignore-not-found
    done

# ----- 6. Strip rancher labels from KEPT namespaces -------------------------
say "6. Cleaning rancher labels/annotations from preserved namespaces"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  # Skip ones we're deleting and protected system namespaces.
  [[ "$ns" =~ $RANCHER_NS_REGEX ]] && continue
  [[ "$ns" =~ $PRESERVE_NS_REGEX ]] && continue

  # Only act if this NS actually has rancher metadata.
  meta=$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels}{.metadata.annotations}' 2>/dev/null)
  echo "$meta" | grep -qE 'cattle\.io|rancher\.io|cattle/' || continue

  echo "  $ns: stripping rancher labels/annotations"
  run kubectl label ns "$ns" field.cattle.io/projectId-
  run kubectl annotate ns "$ns" \
      field.cattle.io/projectId- \
      cattle.io/status- \
      lifecycle.cattle.io/create.namespace-auth- \
      management.cattle.io/no-default-sa-token-
done

say "Done"
if [[ "$DRY_RUN" == "1" ]]; then
  echo "No changes were made. Re-run with: DRY_RUN=0 $0"
else
  echo "Verify: kubectl get ns | grep -E 'cattle|fleet|local'  (should be empty)"
  echo "        kubectl get crd | grep -E 'cattle|rancher'      (should be empty)"
  echo "        kubectl api-resources 2>&1 | grep -i error      (should be empty)"
fi
