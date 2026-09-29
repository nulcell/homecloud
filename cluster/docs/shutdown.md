# Full cluster shutdown

```bash
mise run cluster:shutdown   # asks you to type the kube context
# ...power nodes on...
mise run cluster:start
```

`cluster:shutdown` (in [`scripts/cluster.sh`](../../scripts/cluster.sh)), in order:

1. Halts KubeVirt VMs, remembering each `runStrategy` in an annotation.
2. Hibernates every CNPG cluster.
3. Cordons every node and deletes the pods in namespaces holding Longhorn volumes. Controllers recreate them as `Pending`, so volumes detach while replica counts stay as in git. ArgoCD, HPAs, KEDA and operators need no handling.
4. Waits for every Longhorn volume to be `detached`; aborts (nothing powered off) if any is not.
5. `talosctl shutdown --force`, workers first (no drain needed: everything is detached).

`cluster:start` waits for the nodes, uncordons them (the cordon survives a reboot), un-hibernates CNPG, restores VM `runStrategy` and lists apps that are not yet Healthy.

`argocd`, `longhorn-system`, `cnpg-system` and `kube-system` are left alone: Longhorn/CSI must detach volumes and CNPG must process hibernation.

`reclaimPolicy: Delete`: deleting a PVC destroys its volume. Nothing here deletes PVCs.

## Aborting or debugging

- Aborted mid-shutdown: `mise run cluster:start` undoes it.
- A volume will not detach: find the pod still mounting it:
  `kubectl get pods -A -o json | jq -r '.items[] | select(any(.spec.volumes[]?; .persistentVolumeClaim)) | "\(.metadata.namespace)/\(.metadata.name)"'`
