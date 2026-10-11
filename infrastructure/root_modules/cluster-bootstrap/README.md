# cluster-bootstrap

Reserved for Argo CD installation using OpenTofu and the Helm provider, plus
the initial root Application targeting `apps/roots/<id>`.

Requires a working kubeconfig and Kubernetes API after the node bootstrap stage.
Pin provider/chart versions and commit non-secret Helm values. Implement Git
access, readiness checks, CRD ordering, state protection, and teardown semantics.
OpenTofu owns the Argo CD installation and root Application; Argo CD owns child
Applications and workloads. No deployable OpenTofu files are present yet.
