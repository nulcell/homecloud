#!/usr/bin/env bash
# Node and storage lifecycle, driven from live cluster state (nothing hard-coded).
# usage: cluster.sh preflight
#        cluster.sh rollout <upgrade|config> [node]
#        cluster.sh upgrade-k8s
#        cluster.sh restore <argocd-app> <namespace>/<pvc> [longhorn-volume]
#        cluster.sh shutdown | start
# Needs SCHEMATIC_ID, TALOS_VERSION, KUBERNETES_VERSION (set by mise).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

LH=(kubectl -n longhorn-system)
ARGO=(kubectl -n argocd)
# Never quiesced: Longhorn/CSI must stay up to detach, CNPG to hibernate.
SYSTEM_NS='["argocd","longhorn-system","cnpg-system","kube-system"]'

# Retries for ~15m; the API is briefly down while the only control plane reboots.
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

argo_freeze() {
  "${ARGO[@]}" scale statefulset argocd-application-controller --replicas=0
  "${ARGO[@]}" scale deployment argocd-applicationset-controller --replicas=0
  # A live controller pod re-heals scale-downs, so wait for it to be gone.
  "${ARGO[@]}" wait --for=delete pod -l app.kubernetes.io/name=argocd-application-controller --timeout=120s
}
argo_unfreeze() {
  "${ARGO[@]}" scale statefulset argocd-application-controller --replicas=1
  "${ARGO[@]}" scale deployment argocd-applicationset-controller --replicas=1
}

wait_volumes_healthy() {
  local i
  for i in $(seq 240); do "$0" preflight >/dev/null 2>&1 && return 0; sleep 15; done
  "$0" preflight
}

preflight() {
  local fail=0 nodes vols reps bad n total
  echo "preflight: checking nodes and Longhorn volumes"

  nodes=$(kubectl get nodes -o json)
  total=$(jq '.items | length' <<<"$nodes")
  bad=$(jq -r '.items[] | select(any(.status.conditions[]; .type == "Ready" and .status != "True")) | .metadata.name' <<<"$nodes")
  if [ -z "$bad" ]; then
    echo "✓ nodes Ready: $total/$total ($(jq -r '[.items[].metadata.name] | join(", ")' <<<"$nodes"))"
  else
    echo "✗ nodes not Ready: $(tr '\n' ' ' <<<"$bad")" >&2; fail=1
  fi

  vols=$("${LH[@]}" get volumes.longhorn.io -o json)
  reps=$("${LH[@]}" get replicas.longhorn.io -o json)
  # A drain needs a healthy replica on another node, so every attached volume needs 2.
  total=$(jq '[.items[] | select(.status.state == "attached")] | length' <<<"$vols")
  bad=$(jq -r --argjson r "$reps" '
    ($r.items | map(select(.spec.healthyAt != "" and .spec.failedAt == "")) | group_by(.spec.volumeName)
      | map({(.[0].spec.volumeName): length}) | add // {}) as $h
    | .items[] | select(.status.state == "attached" and ($h[.metadata.name] // 0) < 2)
    | "\(.status.kubernetesStatus.namespace // "-")/\(.status.kubernetesStatus.pvcName // .metadata.name): \($h[.metadata.name] // 0) healthy replica(s)"' <<<"$vols")
  n=$(jq '[.items[] | select(.status.state != "attached")] | length' <<<"$vols")
  if [ -z "$bad" ]; then
    echo "✓ attached volumes with >= 2 healthy replicas: $total/$total ($n detached, not checked)"
  else
    echo "✗ attached volumes without 2 healthy replicas (rebuilding counts as unhealthy):" >&2
    sed 's/^/    /' <<<"$bad" >&2; fail=1
  fi
  return $fail
}

rollout() {
  local action=${1:?usage: rollout <upgrade|config> [node]} only=${2:-} name ip role
  local image="factory.talos.dev/metal-installer/$SCHEMATIC_ID:$TALOS_VERSION"
  preflight
  # One node at a time: keeps etcd quorum with 3 control planes.
  while read -r name ip role; do
    [ -z "$only" ] || [ "$only" = "$name" ] || [ "$only" = "$ip" ] || continue
    echo "==> $action $name ($ip, $role)"
    case $action in
      upgrade)
        # talosctl cordons and drains the node itself before rebooting.
        talos "$ip" upgrade --image "$image" --drain-timeout 15m
        ;;
      config)
        # install.image comes from .mise.toml so the patch files never need a version bump.
        local p=(--patch "@cluster/talos/patches/$role.yaml"
                 --patch "[{\"op\":\"replace\",\"path\":\"/machine/install/image\",\"value\":\"$image\"}]")
        talos "$ip" patch machineconfig "${p[@]}" --dry-run
        if ! talos "$ip" patch machineconfig "${p[@]}" --mode no-reboot; then
          echo "config needs a reboot"
          kubectl drain "$name" --ignore-daemonsets --delete-emptydir-data --timeout=15m
          talos "$ip" patch machineconfig "${p[@]}" --mode staged
          talos "$ip" reboot
        fi
        ;;
      *) echo "unknown action: $action" >&2; exit 2 ;;
    esac
    retry kubectl wait --for=condition=Ready "node/$name" --timeout=60s
    retry kubectl uncordon "$name"
    wait_volumes_healthy
  done < <(nodes)
}

upgrade_k8s() {
  local ip; ip=$(nodes | awk '$3 == "controlplane" { print $2; exit }')
  preflight
  talos "$ip" upgrade-k8s --to "$KUBERNETES_VERSION" --dry-run
  confirm "Upgrade Kubernetes to $KUBERNETES_VERSION?" || exit 1
  talos "$ip" upgrade-k8s --to "$KUBERNETES_VERSION"
}

# Pods mounting a PVC, as "kind name" of their controller (Deployments resolved from ReplicaSets).
mounters() {
  kubectl -n "$1" get pods -o json | jq -r --arg pvc "$2" '.items[]
    | select(any(.spec.volumes[]?; .persistentVolumeClaim.claimName == $pvc))
    | .metadata.ownerReferences[0] | "\(.kind) \(.name)"' | sed -E 's/^ReplicaSet (.*)-[a-z0-9]+$/Deployment \1/' | sort -u
}
unmounted() { [ -z "$(mounters "$1" "$2")" ]; }
pv_gone() { [ -z "$(kubectl get pv "$1" -o name 2>/dev/null)" ]; }
restored() { [ "$("${LH[@]}" get volumes.longhorn.io "$1" -o jsonpath='{.status.state}/{.status.restoreRequired}')" = detached/false ]; }

restore() {
  local app=${1:?usage: restore <argocd-app> <namespace>/<pvc> [longhorn-volume]} ref=${2:?}
  local ns=${ref%/*} pvc=${ref#*/} vol=${3:-} new kind name last url size mode cap modes sc
  [ -n "$vol" ] || vol=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.volumeName}')
  [ -n "$vol" ] || { echo "PVC $ref not found; pass its Longhorn volume name as the 3rd arg" >&2; exit 1; }

  last=$("${LH[@]}" get backupvolumes.longhorn.io "$vol" -o jsonpath='{.status.lastBackupName}')
  [ -n "$last" ] || { echo "no backup for volume $vol" >&2; exit 1; }
  url=$("${LH[@]}" get backups.longhorn.io "$last" -o jsonpath='{.status.url}')
  size=$("${LH[@]}" get volumes.longhorn.io "$vol" -o jsonpath='{.spec.size}')
  mode=$("${LH[@]}" get volumes.longhorn.io "$vol" -o jsonpath='{.spec.accessMode}')
  cap=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.resources.requests.storage}')
  modes=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.accessModes}')
  sc=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.storageClassName}')
  echo "restoring $ref from backup $last ($url)"
  confirm "Delete PVC $ref? Live data is replaced by the backup." || exit 1

  # The appset controller reverts a paused Application, so it stays down until resume.
  trap '"${ARGO[@]}" scale deployment argocd-applicationset-controller --replicas=1' EXIT
  "${ARGO[@]}" scale deployment argocd-applicationset-controller --replicas=0
  "${ARGO[@]}" patch application "$app" --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'

  while read -r kind name; do
    [ -z "$kind" ] || kubectl -n "$ns" scale "$(tr '[:upper:]' '[:lower:]' <<<"$kind")/$name" --replicas=0
  done < <(mounters "$ns" "$pvc")
  retry unmounted "$ns" "$pvc"

  kubectl -n "$ns" delete pvc "$pvc" --wait
  retry pv_gone "$vol"

  new="restore-$(date +%s)"
  kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata: {name: $new, namespace: longhorn-system}
spec: {size: "$size", numberOfReplicas: 2, accessMode: $mode, frontend: blockdev, fromBackup: "$url"}
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: $new}
spec:
  capacity: {storage: $cap}
  accessModes: $modes
  persistentVolumeReclaimPolicy: Delete
  storageClassName: $sc
  claimRef: {namespace: $ns, name: $pvc}
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeHandle: $new
    volumeAttributes: {numberOfReplicas: "2", staleReplicaTimeout: "30"}
EOF
  echo "waiting for the restore to finish"
  retry restored "$new"

  # Resume: ArgoCD recreates the PVC (binds to the PV above) and restores replicas.
  "${ARGO[@]}" scale deployment argocd-applicationset-controller --replicas=1
  trap - EXIT
  retry kubectl -n "$ns" wait --for=jsonpath='{.status.phase}'=Bound "pvc/$pvc" --timeout=60s
  echo "restored $ref"
}

shutdown() {
  local ctx ns c name ip role i left=x
  ctx=$(kubectl config current-context)
  read -rp "Shut down the whole cluster? Type the context name ($ctx): " i
  [ "$i" = "$ctx" ] || exit 1

  echo "==> freeze ArgoCD"; argo_freeze

  echo "==> halt VMs"
  kubectl get vm -A -o json | jq -r '.items[] | select(.spec.runStrategy != "Halted")
    | "\(.metadata.namespace) \(.metadata.name) \(.spec.runStrategy)"' | while read -r ns name c; do
      kubectl -n "$ns" annotate vm "$name" "homecloud/run-strategy=$c" --overwrite
      kubectl -n "$ns" patch vm "$name" --type merge -p '{"spec":{"runStrategy":"Halted"}}'
    done

  echo "==> hibernate CNPG clusters"
  kubectl get clusters.postgresql.cnpg.io -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' \
    | while read -r ns c; do
        kubectl -n "$ns" annotate cluster "$c" cnpg.io/hibernation=on --overwrite
        kubectl -n "$ns" wait --for=condition=cnpg.io/hibernation "cluster/$c" --timeout=5m
      done

  echo "==> scale down workloads that hold Longhorn volumes"
  for ns in $(kubectl get pvc -A -o json | jq -r --argjson s "$SYSTEM_NS" '
      [.items[] | select(.spec.storageClassName == "longhorn") | .metadata.namespace] | unique[]
      | select(. as $n | ($s | index($n)) == null)'); do
    kubectl -n "$ns" delete hpa --all --ignore-not-found
    kubectl -n "$ns" delete scaledobject --all --ignore-not-found 2>/dev/null || true
    # Deployments first: parks operators (e.g. kps-operator) before their StatefulSets.
    for i in deployment statefulset; do
      if [ -n "$(kubectl -n "$ns" get "$i" -o name)" ]; then
        kubectl -n "$ns" scale "$i" --all --replicas=0
      fi
    done
  done

  echo "==> wait for every volume to detach"
  for i in $(seq 120); do
    left=$("${LH[@]}" get volumes.longhorn.io -o json | jq -r '.items[] | select(.status.state != "detached")
      | "\(.status.kubernetesStatus.namespace)/\(.status.kubernetesStatus.pvcName) \(.status.state)"')
    [ -z "$left" ] && break
    sleep 5
  done
  [ -z "$left" ] || { echo "still attached, not powering off:" >&2; echo "$left" >&2; exit 1; }

  echo "==> power off (drain skipped: everything is detached)"
  while read -r name ip role; do talos "$ip" shutdown --force; done < <(nodes)
}

start() {
  local ns c name v i
  echo "==> wait for the API and nodes"
  retry kubectl get nodes
  retry kubectl wait --for=condition=Ready node --all --timeout=60s

  echo "==> un-hibernate CNPG clusters"
  kubectl get clusters.postgresql.cnpg.io -A -o json | jq -r '.items[]
    | select(.metadata.annotations["cnpg.io/hibernation"] == "on") | "\(.metadata.namespace) \(.metadata.name)"' \
    | while read -r ns c; do kubectl -n "$ns" annotate cluster "$c" cnpg.io/hibernation=off --overwrite; done

  echo "==> restore VMs"
  kubectl get vm -A -o json | jq -r '.items[] | select(.metadata.annotations["homecloud/run-strategy"] != null)
    | "\(.metadata.namespace) \(.metadata.name) \(.metadata.annotations["homecloud/run-strategy"])"' | while read -r ns name v; do
      kubectl -n "$ns" patch vm "$name" --type merge -p "{\"spec\":{\"runStrategy\":\"$v\"}}"
      kubectl -n "$ns" annotate vm "$name" homecloud/run-strategy-
    done

  echo "==> unfreeze ArgoCD (restores replicas and HPAs from git)"
  argo_unfreeze
  local unhealthy='.items[] | select(.status.sync.status != "Synced" or .status.health.status != "Healthy") | .metadata.name'
  for i in $(seq 120); do
    [ -z "$("${ARGO[@]}" get applications.argoproj.io -o json | jq -r "$unhealthy")" ] && break
    sleep 15
  done
  "${ARGO[@]}" get applications.argoproj.io -o json | jq -r "$unhealthy" | sed 's/^/not ready: /'
  wait_volumes_healthy
}

cmd=${1:?usage: cluster.sh <preflight|rollout|upgrade-k8s|restore|shutdown|start>}; shift
case $cmd in
  preflight) preflight "$@" ;;
  rollout) rollout "$@" ;;
  upgrade-k8s) upgrade_k8s ;;
  restore) restore "$@" ;;
  shutdown) shutdown ;;
  start) start ;;
  *) echo "unknown command: $cmd" >&2; exit 2 ;;
esac
