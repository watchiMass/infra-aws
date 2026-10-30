variable "environment" {
  description = "Nom de l'environnement (dev, prod…)."
  type        = string
}

variable "region" {
  description = "Région AWS de l'environnement."
  type        = string
}

variable "cluster_name" {
  description = "Nom du cluster EKS (convention guide : <env>-eks)."
  type        = string
}

variable "kubernetes_version" {
  description = "Version Kubernetes supportée par EKS (ex. 1.36)."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloc CIDR IPv4 de la VPC."
  type        = string
}

variable "nat_gateway_mode" {
  description = "Topologie NAT : un gateway par AZ ou un gateway partagé."
  type        = string

  validation {
    condition     = contains(["per_az", "single"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode doit valoir per_az ou single."
  }
}

variable "domain_name" {
  description = "Zone DNS dédiée à l'environnement (ex. dev.obszh.fr)."
  type        = string
}

variable "api_allowed_cidrs" {
  description = "CIDRs autorisés à joindre l'endpoint public de l'API EKS."
  type        = list(string)
}

variable "secret_arns" {
  description = "Secrets Manager accessibles par External Secrets."
  type        = list(string)
  default     = []
}

variable "secrets_kms_key_arns" {
  description = "Clés KMS client utilisées pour chiffrer les secrets autorisés."
  type        = list(string)
  default     = []
}

variable "enable_cert_manager" {
  description = "Crée le rôle IRSA cert-manager (DNS-01, wildcards uniquement)."
  type        = bool
  default     = false
}

variable "enable_keda" {
  description = "Crée le rôle IRSA KEDA (scalers CloudWatch)."
  type        = bool
  default     = false
}

variable "git_org" {
  description = "Compte ou organisation GitHub propriétaire des dépôts GitOps."
  type        = string
}

variable "gitops_platform_repo" {
  description = "Nom du dépôt GitOps infrastructure (Flux)."
  type        = string
  default     = "gitops-platform"
}

variable "gitops_apps_repo" {
  description = "Nom du dépôt GitOps applications (Argo CD)."
  type        = string
  default     = "gitops-apps"
}

variable "repo_visibility" {
  description = "Visibilité des dépôts GitOps."
  type        = string
  default     = "private"
}

variable "github_token" {
  description = "PAT GitHub (scope repo) pour le bootstrap Flux et le provider GitHub."
  type        = string
  sensitive   = true
  default     = "" # fourni à l'apply via TF_VAR_github_token, jamais dans un fichier
}
