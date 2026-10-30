locals {
  tags = {
    environment = var.environment
    managed-by  = "terraform"
    cluster     = var.cluster_name
  }
}

module "network" {
  source = "../../modules/terraform-aws-network"

  vpc_cidr         = var.vpc_cidr
  eks_cluster_name = var.cluster_name
  nat_gateway_mode = var.nat_gateway_mode
  tags             = local.tags
}

module "route53" {
  source = "../../modules/terraform-aws-route53"

  domain_name = var.domain_name
  tags        = local.tags
}

module "eks" {
  source = "../../modules/terraform-aws-eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  api_allowed_cidrs  = var.api_allowed_cidrs
  tags               = local.tags
}

module "irsa" {
  source = "../../modules/terraform-aws-irsa"

  cluster_name            = var.cluster_name
  oidc_provider_arn       = module.eks.oidc_provider_arn
  route53_hosted_zone_arn = module.route53.zone_arn
  secret_arns             = var.secret_arns
  secrets_kms_key_arns    = var.secrets_kms_key_arns
  enable_cert_manager     = var.enable_cert_manager
  enable_keda             = var.enable_keda
}

# --- §2.7 GitOps Bridge — Terraform → Git → Flux ---

data "aws_caller_identity" "current" {}

# Les dépôts sont créés PAR Terraform : pas de poule-œuf entre le bootstrap
# Flux (qui a besoin du dépôt) et l'écriture des fichiers (qui a besoin
# d'un premier commit — d'où auto_init).
resource "github_repository" "gitops_platform" {
  name        = var.gitops_platform_repo
  visibility  = var.repo_visibility
  auto_init   = true
  description = "GitOps INFRASTRUCTURE — consommé par Flux CD"
}

resource "github_repository" "gitops_apps" {
  name        = var.gitops_apps_repo
  visibility  = var.repo_visibility
  auto_init   = true
  description = "GitOps APPLICATIONS — consommé par Argo CD"
}

# Le « pont » : métadonnées du cluster poussées dans Git, consommées ensuite
# par Flux via postBuild.substituteFrom / valuesFrom (voir §3).
resource "github_repository_file" "cluster_metadata" {
  repository          = github_repository.gitops_platform.name
  branch              = "main"
  file                = "clusters/${var.environment}/metadata.yaml"
  overwrite_on_create = true
  content = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "cluster-metadata"
      namespace = "flux-system"
    }
    data = {
      aws_account_id              = data.aws_caller_identity.current.account_id
      aws_region                  = var.region
      aws_vpc_id                  = module.network.vpc_id
      aws_cluster_name            = module.eks.cluster_name
      oidc_provider_arn           = module.eks.oidc_provider_arn
      domain_name                 = var.domain_name
      platform_repo_url           = "https://github.com/${var.git_org}/${var.gitops_platform_repo}"
      apps_repo_url               = "https://github.com/${var.git_org}/${var.gitops_apps_repo}"
      external_dns_role_arn       = module.irsa.external_dns_role_arn
      external_secrets_role_arn   = module.irsa.external_secrets_role_arn
      image_reflector_role_arn    = module.irsa.image_reflector_role_arn
      cluster_autoscaler_role_arn = module.irsa.cluster_autoscaler_role_arn
    }
  })
}

# kubeconfig local : prérequis du bootstrap Flux (local-exec), absent du guide.
resource "terraform_data" "update_kubeconfig" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}"
  }
}

# Bootstrap de Flux (idempotent) : installe les contrôleurs dans le cluster
# et pointe la Kustomization racine sur clusters/<env>/.
resource "terraform_data" "flux_bootstrap" {
  depends_on = [terraform_data.update_kubeconfig, github_repository_file.cluster_metadata]

  provisioner "local-exec" {
    environment = { GITHUB_TOKEN = var.github_token }
    command     = <<-EOT
      flux bootstrap github \
        --owner=${var.git_org} \
        --repository=${var.gitops_platform_repo} \
        --branch=main \
        --path=clusters/${var.environment} \
        --components-extra=image-reflector-controller,image-automation-controller \
        --token-auth
    EOT
  }
}
