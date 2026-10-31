output "external_dns_role_arn" {
  description = "ARN IRSA du ServiceAccount ExternalDNS."
  value       = module.irsa_external_dns.iam_role_arn
}

output "external_secrets_role_arn" {
  description = "ARN IRSA du ServiceAccount External Secrets."
  value       = module.irsa_external_secrets.iam_role_arn
}

output "image_reflector_role_arn" {
  description = "ARN IRSA du contrôleur image-reflector de Flux (lecture ECR)."
  value       = module.irsa_image_reflector.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN IRSA du cluster-autoscaler."
  value       = module.irsa_cluster_autoscaler.iam_role_arn
}

output "cert_manager_role_arn" {
  description = "ARN IRSA de cert-manager (null si désactivé)."
  value       = var.enable_cert_manager ? module.irsa_cert_manager[0].iam_role_arn : null
}

output "keda_role_arn" {
  description = "ARN IRSA de KEDA (null si désactivé)."
  value       = var.enable_keda ? module.irsa_keda[0].iam_role_arn : null
}

output "loki_role_arn" {
  description = "ARN IRSA de Loki (accès S3 aux logs)."
  value       = module.irsa_loki.iam_role_arn
}

output "tempo_role_arn" {
  description = "ARN IRSA de Tempo (accès S3 aux traces)."
  value       = module.irsa_tempo.iam_role_arn
}
