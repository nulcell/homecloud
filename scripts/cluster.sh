#!/usr/bin/env bash
# Cluster shutdown/start and PVC restore, driven from live cluster state. Run through `mise run <task>`.
# usage: cluster.sh restore <argocd-app> <namespace>/<pvc> | shutdown | start
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

LH=(kubectl -n longhorn-system)
ARGO=(kubectl -n argocd)

# Retries for ~15m: the API is briefly down while the only control plane reboots.
retry() { local i; for i in $(seq 90); do "$@" >/dev/null 2>&1 && return 0; sleep 10; done; return 1; }
confirm() { local a; read -rp "$1 [y/N] " a; [ "$a" = y ]; }

# "name ip role", workers first.
nodes() {
  kubectl get nodes -o json | jq -r '.items
    | map({n: .metadata.name, ip: (.status.addresses[] | select(.type == "InternalIP").address),
           cp: (.metadata.labels | has("node-role.kubernetes.io/control-plane"))})
    | sort_by(.cp)[] | "\(.n) \(.ip) \(if .cp then "controlplane" else "worker" end)"'
}
talos() { local ip=$1; shift; talosctl -e "$ip" -n "$ip" "$@"; }

argo_scale() { # replicas
  "${ARGO[@]}" scale statefulset argocd-application-controller --replicas="$1"
  "${ARGO[@]}" scale deployment argocd-applicationset-controller --replicas="$1"
}

unmounted() { # ns pvc
  ! kubectl -n "$1" get pods -o json | jq -e --arg p "$2" 'any(.items[]; any(.spec.volumes[]?; .persistentVolumeClaim.claimName == $p))' >/dev/null
}

# Recreates a git-owned PVC from its newest backup, so ArgoCD binds the PVC it recreates to the restored data.
restore() {
  local app=${1:?usage: restore <argocd-app> <namespace>/<pvc>} ref=${2:?} ns pvc pvcjson vol last url new
  ns=${ref%/*} pvc=${ref#*/}
  pvcjson=$(kubectl -n "$ns" get pvc "$pvc" -o json)
  vol=$(jq -r .spec.volumeName <<<"$pvcjson")
  last=$("${LH[@]}" get backupvolumes.longhorn.io "$vol" -o jsonpath='{.status.lastBackupName}')
  [ -n "$last" ] || { echo "no backup for volume $vol" >&2; exit 1; }
  url=$("${LH[@]}" get backups.longhorn.io "$last" -o jsonpath='{.status.url}')
  echo "restoring $ref from backup $last"
  confirm "Scale down every Deployment/StatefulSet in $ns and replace PVC $pvc with the backup?" || exit 1

  # The appset controller would revert the paused Application, so it stays down until we resume.
  trap 'argo_scale 1' EXIT
  "${ARGO[@]}" scale deployment argocd-applicationset-controller --replicas=0
  "${ARGO[@]}" patch application "$app" --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'
  kubectl -n "$ns" scale deployment,statefulset --all --replicas=0
  retry unmounted "$ns" "$pvc"
  kubectl -n "$ns" delete pvc "$pvc" --wait
  kubectl wait --for=delete "pv/$vol" --timeout=2m

  new="restore-$(date +%s)"
  kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata: {name: $new, namespace: longhorn-system}
spec:
  size: "$("${LH[@]}" get volumes.longhorn.io "$vol" -o jsonpath='{.spec.size}')"
  accessMode: $("${LH[@]}" get volumes.longhorn.io "$vol" -o jsonpath='{.spec.accessMode}')
  numberOfReplicas: 2
  frontend: blockdev
  fromBackup: "$url"
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: $new}
spec:
  capacity: {storage: $(jq -r .spec.resources.requests.storage <<<"$pvcjson")}
  accessModes: $(jq -c .spec.accessModes <<<"$pvcjson")
  storageClassName: $(jq -r .spec.storageClassName <<<"$pvcjson")
  persistentVolumeReclaimPolicy: Delete
  claimRef: {namespace: $ns, name: $pvc}
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeHandle: $new
    volumeAttributes: {numberOfReplicas: "2", staleReplicaTimeout: "30"}
EOF
  "${LH[@]}" wait "volumes.longhorn.io/$new" --for=jsonpath='{.status.restoreRequired}'=false --timeout=15m
  "${LH[@]}" wait "volumes.longhorn.io/$new" --for=jsonpath='{.status.state}'=detached --timeout=5m
  # Resuming (EXIT trap) lets ArgoCD recreate the PVC onto the restored PV and scale the app back up.
}

shutdown() {
  local ctx ns name c ip role i
  ctx=$(kubectl config current-context)
  read -rp "Shut down the whole cluster? Type the context name ($ctx): " i
  [ "$i" = "$ctx" ] || exit 1

  echo "==> freeze ArgoCD (its pod must be gone or it heals every scale-down)"
  argo_scale 0
  "${ARGO[@]}" wait --for=delete pod -l app.kubernetes.io/name=argocd-application-controller --timeout=120s

  echo "==> halt VMs (previous runStrategy is kept in an annotation)"
  kubectl get vm -A -o json | jq -r '.items[] | select(.spec.runStrategy != "Halted") | "\(.metadata.namespace) \(.metadata.name) \(.spec.runStrategy)"' \
    | while read -r ns name c; do
        kubectl -n "$ns" annotate vm "$name" "homecloud/run-strategy=$c" --overwrite
        kubectl -n "$ns" patch vm "$name" --type merge -p '{"spec":{"runStrategy":"Halted"}}'
      done

  echo "==> hibernate CNPG clusters"
  kubectl get clusters.postgresql.cnpg.io -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' \
    | while read -r ns c; do
        kubectl -n "$ns" annotate cluster "$c" cnpg.io/hibernation=on --overwrite
        kubectl -n "$ns" wait --for=condition=cnpg.io/hibernation "cluster/$c" --timeout=5m
      done

  echo "==> scale down workloads that hold Longhorn volumes (Deployments first: parks operators)"
  for ns in $(kubectl get pvc -A -o json | jq -r '[.items[] | select((.spec.storageClassName // "") | startswith("longhorn")) | .metadata.namespace] | unique[]
      | select(. as $n | ["argocd","longhorn-system","cnpg-system","kube-system"] | index($n) | not)'); do
    kubectl -n "$ns" delete hpa,scaledobject --all --ignore-not-found 2>/dev/null || true
    kubectl -n "$ns" scale deployment --all --replicas=0
    kubectl -n "$ns" scale statefulset --all --replicas=0
  done

  echo "==> wait for every volume to detach"
  detached() { [ -z "$("${LH[@]}" get volumes.longhorn.io -o json | jq -r '.items[] | select(.status.state != "detached") | .metadata.name')" ]; }
  retry detached || { echo "volumes still attached; not powering off" >&2; "${LH[@]}" get volumes.longhorn.io; exit 1; }

  echo "==> power off (no drain needed: everything is detached)"
  while read -r name ip role; do talos "$ip" shutdown --force; done < <(nodes)
}

start() {
  local ns name v
  retry kubectl wait --for=condition=Ready node --all --timeout=60s

  echo "==> un-hibernate CNPG clusters"
  kubectl get clusters.postgresql.cnpg.io -A -o json | jq -r '.items[] | select(.metadata.annotations["cnpg.io/hibernation"] == "on") | "\(.metadata.namespace) \(.metadata.name)"' \
    | while read -r ns name; do kubectl -n "$ns" annotate cluster "$name" cnpg.io/hibernation=off --overwrite; done

  echo "==> restore VMs"
  kubectl get vm -A -o json | jq -r '.items[] | select(.metadata.annotations["homecloud/run-strategy"] != null) | "\(.metadata.namespace) \(.metadata.name) \(.metadata.annotations["homecloud/run-strategy"])"' \
    | while read -r ns name v; do
        kubectl -n "$ns" patch vm "$name" --type merge -p "{\"spec\":{\"runStrategy\":\"$v\"}}"
        kubectl -n "$ns" annotate vm "$name" homecloud/run-strategy-
      done

  echo "==> unfreeze ArgoCD (restores replica counts and HPAs from git)"
  argo_scale 1
  retry kubectl wait --for=condition=Ready node --all --timeout=60s
  "${ARGO[@]}" get applications.argoproj.io -o json | jq -r '.items[] | select(.status.health.status != "Healthy") | "not healthy yet: \(.metadata.name)"'
}

cmd=${1:?usage: cluster.sh <restore|shutdown|start>}; shift
case $cmd in
  restore) restore "$@" ;;
  shutdown) shutdown ;;
  start) start ;;
  *) echo "unknown command: $cmd" >&2; exit 2 ;;
esac
