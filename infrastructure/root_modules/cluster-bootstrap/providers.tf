provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

provider "kubectl" {
  config_path       = var.kubeconfig_path
  config_context    = var.kubeconfig_context
  load_config_file  = true
  apply_retry_count = 5
}
