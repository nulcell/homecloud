# Full cluster shutdown

```bash
mise run cluster:shutdown   # asks you to type the kube context
# ...power nodes on, control plane first...
mise run cluster:start
```

Node upgrades do not use this: with Longhorn replica 2 a plain drain is enough (`mise run talos:upgrade`).

`cluster:shutdown` (in [`scripts/cluster.sh`](../../scripts/cluster.sh)), in order:

1. Warns if any backed-up volume or CNPG cluster has no backup in the last 26h.
2. Freezes ArgoCD (application and applicationset controllers to 0, waits for the pod to be gone).
3. Halts KubeVirt VMs, remembering each `runStrategy` in an annotation.
4. Hibernates every CNPG cluster.
5. In every namespace holding a Longhorn PVC: deletes HPAs and KEDA ScaledObjects, scales Deployments then StatefulSets to 0.
6. Waits for every Longhorn volume to be `detached`; aborts (nothing powered off) if any is not.
7. `talosctl shutdown --force`, workers first. The drain is skipped because everything is detached.

`cluster:start` waits for the API and nodes, un-hibernates CNPG, restores VM `runStrategy`, then unfreezes ArgoCD, which restores replica counts and HPAs from git.

## Why not `kubectl scale --all`

| Layer                                   | Effect                                     | Handled by                       |
| --------------------------------------- | ------------------------------------------ | -------------------------------- |
| ArgoCD `selfHeal` + ApplicationSets     | revert any manual scale                    | freeze both controllers first    |
| CNPG operator                           | owns Postgres pods, no Deployment/STS      | hibernate                        |
| Operators (`kps-operator`, ...)         | re-scale their StatefulSets                | Deployments scaled before STS    |
| HPAs / KEDA ScaledObjects               | re-inflate a zeroed Deployment             | deleted (ArgoCD recreates them)  |
| KubeVirt                                | `virt-launcher` owned by the VM            | `runStrategy: Halted`            |

`argocd`, `longhorn-system`, `cnpg-system` and `kube-system` stay up: Longhorn/CSI must detach volumes and CNPG must process hibernation.

`reclaimPolicy: Delete`: deleting a PVC destroys its volume. Nothing here deletes PVCs.

## Aborting or debugging

- Aborted mid-shutdown: `mise run cluster:start` undoes it (nothing is deleted except HPAs/ScaledObjects, which ArgoCD recreates).
- A volume will not detach: find the pod still mounting it
  `kubectl get pods -A -o json | jq -r '.items[] | select(any(.spec.volumes[]?; .persistentVolumeClaim)) | "\(.metadata.namespace)/\(.metadata.name)"'`
- Scale-down does not stick: check the ArgoCD controller pod is gone, no HPA remains (`kubectl get hpa -A`), and the owning operator is at 0.
