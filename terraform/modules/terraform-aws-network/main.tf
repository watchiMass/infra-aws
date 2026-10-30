

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Pour une VPC /16, chaque subnet est un /20.
  # Les index privés 0..2 et publics 8..10 produisent des plages distinctes.
  private_subnets = [
    for index in range(3) : cidrsubnet(var.vpc_cidr, 4, index)
  ]
  public_subnets = [
    for index in range(3) : cidrsubnet(var.vpc_cidr, 4, index + 8)
  ]

  cluster_tag = {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.17"

  name = "${var.eks_cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway     = true
  one_nat_gateway_per_az = var.nat_gateway_mode == "per_az"
  single_nat_gateway     = var.nat_gateway_mode == "single"

  map_public_ip_on_launch = false
  enable_dns_hostnames    = true
  enable_dns_support      = true

  private_subnet_tags = merge(var.tags, local.cluster_tag, {
    "kubernetes.io/role/internal-elb" = "1"
  })

  public_subnet_tags = merge(var.tags, local.cluster_tag, {
    "kubernetes.io/role/elb" = "1"
  })

  # Tag de découverte EKS sur la VPC elle-même : requis par certains
  # contrôleurs AWS (ex. AWS Load Balancer Controller).
  tags = merge(var.tags, local.cluster_tag)
}

# Appeler le module depuis le projet : 
# provider "aws" {
#   region = var.aws_region

#   default_tags {
#     tags = {
#       environment = var.environment
#       managed-by  = "terraform"
#     }
#   }
# }

# module "network" {
#   source = "./modules/network"

#   name             = "${var.environment}-management"
#   vpc_cidr         = var.vpc_cidr
#   eks_cluster_name = "${var.environment}-management"
#   nat_gateway_mode = "per_az"

#   tags = {
#     environment = var.environment
#     cluster     = "${var.environment}-management"
#   }
# }

# Passe ensuite `module.network.vpc_id` et `module.network.private_subnet_ids` au
# module EKS du projet. Si l'état Terraform du réseau et celui du cluster sont
# dans des workspaces distincts, publie et consomme ces valeurs par un mécanisme
# d'outputs explicite (par exemple Terraform Cloud outputs ou remote state), en
# limitant les permissions d'accès à l'état.
