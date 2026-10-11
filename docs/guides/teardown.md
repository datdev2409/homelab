# Teardown cluster 001

The script is currently a guarded scaffold. `make teardown CLUSTER=001`
exits without modifying resources until teardown orchestration and cleanup are implemented.

The implemented workflow must:

1. Back up data that must survive, outside the disposable VMs.
2. Handle GitOps workloads while Argo CD is running. Define Application finalizers
   and cascading deletion explicitly; deleting an Application alone does not
   necessarily remove its workloads.
3. Destroy the cluster-bootstrap unit while Kubernetes is reachable.
4. Destroy the base-env unit last.
5. Verify cleanup and retain protected state/backups as required for recovery.

Proxmox and HDD preparation are host prerequisites and are not destroyed with
the cluster. If VMs are lost before bootstrap cleanup, document state recovery
rather than blindly forgetting resources or recreating them from a second state.

The bootstrap module owns each entry in `applications` through `kubectl_manifest`
and removes these before the Argo CD Helm release. Cluster 001 currently lists
`root-001`. Bootstrap Applications have no cascading-deletion
finalizer, so child Applications and their workloads remain unless explicitly
cleaned up. The chart retains CRDs and the Helm-created namespace may remain;
both disappear when the disposable VMs are destroyed. See the
[module guide](../../infrastructure/root_modules/cluster-bootstrap/README.md).
