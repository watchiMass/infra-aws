output "cluster_name" {
  description = "Nom du cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint de l'API Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "ARN OIDC utilisé par les rôles IRSA."
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "ID de la VPC."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Subnets privés (nœuds EKS)."
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Subnets publics (load balancers)."
  value       = module.network.public_subnet_ids
}

output "zone_id" {
  description = "ID de la zone Route 53 de l'environnement."
  value       = module.route53.zone_id
}

output "zone_name_servers" {
  description = "Name servers à déléguer dans la zone racine."
  value       = module.route53.name_servers
}

output "external_dns_role_arn" {
  description = "ARN IRSA external-dns."
  value       = module.irsa.external_dns_role_arn
}

output "external_secrets_role_arn" {
  description = "ARN IRSA external-secrets."
  value       = module.irsa.external_secrets_role_arn
}

output "image_reflector_role_arn" {
  description = "ARN IRSA image-reflector Flux."
  value       = module.irsa.image_reflector_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN IRSA cluster-autoscaler."
  value       = module.irsa.cluster_autoscaler_role_arn
}

output "platform_repo_url" {
  description = "URL du dépôt GitOps infrastructure (Flux)."
  value       = "https://github.com/${var.git_org}/${var.gitops_platform_repo}"
}

output "apps_repo_url" {
  description = "URL du dépôt GitOps applications (Argo CD)."
  value       = "https://github.com/${var.git_org}/${var.gitops_apps_repo}"
}
