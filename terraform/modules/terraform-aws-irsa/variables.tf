variable "cluster_name" {
  description = "Nom du cluster EKS, utilisé comme préfixe des rôles IRSA."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN du fournisseur OIDC IAM associé à ce cluster."
  type        = string
}

variable "route53_hosted_zone_arn" {
  description = "ARN de la zone Route 53 gérée par les controllers DNS."
  type        = string
}

variable "secret_arns" {
  description = "Secrets Manager secrets accessibles par External Secrets."
  type        = list(string)
  default     = []
}

variable "secrets_kms_key_arns" {
  description = "Clés KMS client utilisées pour chiffrer les secrets autorisés."
  type        = list(string)
  default     = []
}

variable "enable_cert_manager" {
  description = "Crée le rôle IRSA cert-manager pour la résolution DNS-01 (wildcards)."
  type        = bool
  default     = false
}

variable "enable_keda" {
  description = "Crée le rôle IRSA KEDA pour les scalers CloudWatch."
  type        = bool
  default     = false
}
