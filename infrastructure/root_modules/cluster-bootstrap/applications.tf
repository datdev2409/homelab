locals {
  application_manifests = { for app in var.applications : app.application_name => {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = app.application_name
      namespace = var.argocd_namespace
      # No cascading finalizer: teardown handles GitOps workloads separately.
    }
    spec = {
      project = app.project
      source = {
        repoURL        = app.repo_url
        targetRevision = app.ref
        path           = app.path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune      = app.prune
          selfHeal   = app.self_heal
          allowEmpty = false
        }
      }
    }
  } }
}

resource "kubectl_manifest" "applications" {
  for_each = local.application_manifests

  yaml_body = yamlencode(each.value)

  # The Application CRD is installed by Helm in this same apply.
  validate_schema = false
  wait            = true

  depends_on = [helm_release.argocd]
}
