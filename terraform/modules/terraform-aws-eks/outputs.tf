output "cluster_name" {
  description = "Nom du cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint de l'API Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "ARN OIDC utilisé pour créer les rôles IRSA."
  value       = module.eks.oidc_provider_arn
}