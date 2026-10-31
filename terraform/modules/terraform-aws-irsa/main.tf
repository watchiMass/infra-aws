# IRSA associe un rôle IAM à un Kubernetes ServiceAccount par le fournisseur OIDC
# du cluster. Le Pod obtient alors des identifiants STS temporaires ; aucune clé
# AWS statique n'est stockée dans Kubernetes. Crée un rôle distinct par
# ServiceAccount et par périmètre de permissions : ne partage pas un rôle
# administratif entre Flux et les addons. Voir le
# [guide IRSA d'EKS](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).

module "irsa_external_dns" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix              = "${var.cluster_name}-external-dns-"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [var.route53_hosted_zone_arn]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

locals {
  # Une liste vide produit une policy IAM sans Resource
  # (MalformedPolicyDocument: "Policy statement must contain resources") :
  # fallback sur le périmètre par défaut du module (tous les secrets de
  # Secrets Manager, toutes les clés KMS), à resserrer quand secret_arns
  # sera renseigné.
  external_secrets_arns     = length(var.secret_arns) > 0 ? var.secret_arns : ["arn:aws:secretsmanager:*:*:secret:*"]
  external_secrets_kms_arns = length(var.secrets_kms_key_arns) > 0 ? var.secrets_kms_key_arns : ["arn:aws:kms:*:*:key/*"]
}

module "irsa_external_secrets" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix                      = "${var.cluster_name}-external-secrets-"
  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = local.external_secrets_arns
  external_secrets_kms_key_arns         = local.external_secrets_kms_arns

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}

# Flux image-reflector : lit les tags ECR pour l'automation d'images (§5.7).
# NB : le guide §2.4 écrit « irsa-image-reflector », mais le vrai ServiceAccount
# créé par `flux bootstrap` s'appelle image-reflector-controller — on cible celui-ci.
module "irsa_image_reflector" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix = "${var.cluster_name}-image-reflector-"
  role_policy_arns = {
    ecr-readonly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["flux-system:image-reflector-controller"]
    }
  }
}

# cluster-autoscaler : scaling des node groups EKS (§3.5).
module "irsa_cluster_autoscaler" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix                 = "${var.cluster_name}-cluster-autoscaler-"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

# cert-manager DNS-01 (optionnel) : nécessaire uniquement pour des certificats
# wildcard ; le ClusterIssuer HTTP-01 du guide §3.5 n'en a pas besoin.
module "irsa_cert_manager" {
  count   = var.enable_cert_manager ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix              = "${var.cluster_name}-cert-manager-"
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [var.route53_hosted_zone_arn]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }
}

# KEDA sur CloudWatch (optionnel) : uniquement pour des scalers AWS.
module "irsa_keda" {
  count   = var.enable_keda ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix = "${var.cluster_name}-keda-"
  role_policy_arns = {
    cloudwatch-read = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["keda:keda-operator"]
    }
  }
}

# Loki : accès S3 limité à SON bucket de logs (§4.3 — oubli du guide).
resource "aws_iam_policy" "loki_s3" {
  name = "${var.cluster_name}-loki-s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
        "s3:ListBucket", "s3:GetBucketLocation",
      ]
      Resource = [var.loki_bucket_arn, "${var.loki_bucket_arn}/*"]
    }]
  })
}

module "irsa_loki" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix = "${var.cluster_name}-loki-"
  role_policy_arns = { loki-s3 = aws_iam_policy.loki_s3.arn }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["observability:loki"]
    }
  }
}

# Tempo : accès S3 limité à SON bucket de traces (§4.4 — oubli du guide).
resource "aws_iam_policy" "tempo_s3" {
  name = "${var.cluster_name}-tempo-s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
        "s3:ListBucket", "s3:GetBucketLocation",
      ]
      Resource = [var.tempo_bucket_arn, "${var.tempo_bucket_arn}/*"]
    }]
  })
}

module "irsa_tempo" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix = "${var.cluster_name}-tempo-"
  role_policy_arns = { tempo-s3 = aws_iam_policy.tempo_s3.arn }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["observability:tempo"]
    }
  }
}