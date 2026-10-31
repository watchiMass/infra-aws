module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Garde l'accès privé activé. Si l'accès public est autorisé, limite-le
  # aux CIDR VPN/bastion/CI nécessaires, jamais à 0.0.0.0/0 par défaut.
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.api_allowed_cidrs

  # Crée le fournisseur OIDC IAM utilisé ensuite par les rôles IRSA.
  enable_irsa = true

  # Les addons ci-dessous sont gérés explicitement comme addons EKS.
  bootstrap_self_managed_addons = false
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      # CRITIQUE : le CNI doit exister AVANT les nœuds, sinon ils ne passent
      # jamais Ready et le node group est déclaré unhealthy (cercle vicieux :
      # les addons sans before_compute attendent les node groups sains).
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    general = {
      min_size       = 1
      max_size       = 6
      desired_size   = 2
      instance_types = ["m6i.large"]
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"
      labels         = { "node-type" = "general" }
    }

    spot = {
      min_size       = 0
      max_size       = 10
      desired_size   = 1
      instance_types = ["m6i.large", "m5.large", "m7i.large"]
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "SPOT"
      labels         = { "node-type" = "spot" }
      taints = [{
        key    = "node-type"
        value  = "spot"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = var.tags
}

module "irsa_ebs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name_prefix      = "${var.cluster_name}-ebs-csi-"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs_csi.version
  service_account_role_arn = module.irsa_ebs_csi.iam_role_arn

  resolve_conflicts_on_update = "PRESERVE"
}