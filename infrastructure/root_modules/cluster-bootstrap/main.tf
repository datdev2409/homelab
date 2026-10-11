resource "helm_release" "argocd" {
  name             = var.argocd_release_name
  namespace        = var.argocd_namespace
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  create_namespace = true

  values = concat(
    [file("${path.module}/argocd/values.yaml")],
    [for path in var.values_files : file(path)],
    [yamlencode(var.argocd_values)],
  )

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = true
  timeout         = var.helm_timeout_seconds
  max_history     = 3

  lifecycle {
    precondition {
      condition     = fileexists(var.kubeconfig_path)
      error_message = "Fetch this cluster's kubeconfig after Ansible bootstrap before planning or applying Argo CD."
    }
  }
}
