variable "kubeconfig_path" {
  description = "Absolute path to the ignored kubeconfig for the target cluster."
  type        = string

  validation {
    condition     = startswith(var.kubeconfig_path, "/")
    error_message = "kubeconfig_path must be an absolute path outside the execution cache."
  }
}

variable "kubeconfig_context" {
  description = "Optional context; null selects the kubeconfig's current context."
  type        = string
  default     = null
}

variable "argocd_chart_version" {
  description = "Pinned version of the official argo-cd Helm chart."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.argocd_chart_version))
    error_message = "Provide an exact stable chart version, such as 10.10.2."
  }
}

variable "argocd_namespace" {
  description = "Namespace created by Helm for Argo CD."
  type        = string
  default     = "argocd"
}

variable "argocd_release_name" {
  description = "Name of the Helm-managed Argo CD release."
  type        = string
  default     = "argocd"
}

variable "values_files" {
  description = "Optional absolute paths to Helm values files, layered over module defaults in order and before argocd_values. Keep secrets outside Git."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for path in var.values_files : startswith(path, "/")])
    error_message = "Every values file must have an absolute path."
  }
}

variable "argocd_values" {
  description = "Nested Helm values overrides merged by Helm over module defaults and values_files. Keep secrets outside Git."
  type        = any
  default     = {}
  nullable    = false

  validation {
    condition     = can(keys(var.argocd_values))
    error_message = "argocd_values must be an object of Helm values."
  }
}

variable "helm_timeout_seconds" {
  description = "Time allowed for Helm operations, including readiness and hook jobs."
  type        = number
  default     = 600

  validation {
    condition     = var.helm_timeout_seconds > 0 && floor(var.helm_timeout_seconds) == var.helm_timeout_seconds
    error_message = "helm_timeout_seconds must be a positive integer."
  }
}

variable "applications" {
  description = "Bootstrap Argo CD Applications, uniquely named. Commit only non-secret Git configuration; configure private repository access separately."
  type = list(object({
    application_name = string
    repo_url         = string
    ref              = string
    path             = string
    project          = optional(string, "default")
    prune            = optional(bool, true)
    self_heal        = optional(bool, true)
  }))
  default = []

  validation {
    condition = alltrue([for app in var.applications : (
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", app.application_name)) &&
      length(app.application_name) <= 63 &&
      trimspace(app.repo_url) != "" &&
      trimspace(app.ref) != "" &&
      trimspace(app.path) != "" &&
      !startswith(app.path, "/") &&
      !contains(split("/", app.path), "..")
    )])
    error_message = "Each application needs a valid application_name, Git URL, ref, and non-empty repository-relative path without '..'."
  }

  validation {
    condition     = length(distinct([for app in var.applications : app.application_name])) == length(var.applications)
    error_message = "Application names must be unique within the bootstrap unit."
  }
}
