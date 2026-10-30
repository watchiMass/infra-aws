variable "prefix" {
  description = "Préfixe de nommage des rôles IAM du module."
  type        = string
}

variable "repositories" {
  description = "Noms des repositories ECR à créer."
  type        = set(string)
}

variable "github_org" {
  description = "Compte ou organisation GitHub des dépôts applicatifs."
  type        = string
}

variable "github_repos" {
  description = "Dépôts GitHub dont la CI peut assumer le rôle de push."
  type        = list(string)
}

variable "github_branch" {
  description = "Branche autorisée à assumer le rôle (ref du trust OIDC)."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Crée le provider OIDC GitHub Actions du compte (unique)."
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "ARN d'un provider OIDC GitHub existant (si create_github_oidc_provider = false)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags communs appliqués aux ressources du module."
  type        = map(string)
  default     = {}
}
