output "argocd_release_name" {
  description = "Installed Argo CD Helm release name."
  value       = helm_release.argocd.name
}

output "argocd_namespace" {
  description = "Namespace containing Argo CD."
  value       = helm_release.argocd.namespace
}

output "argocd_chart_version" {
  description = "Pinned chart version managed by this configuration."
  value       = helm_release.argocd.version
}

output "applications" {
  description = "Bootstrap Applications managed by OpenTofu, keyed by application_name."
  value = { for name, application in kubectl_manifest.applications : name => {
    name      = application.name
    namespace = application.namespace
  } }
}
