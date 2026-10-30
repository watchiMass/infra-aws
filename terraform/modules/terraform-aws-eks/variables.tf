variable "cluster_name" {
  description = "Nom du cluster EKS."
  type        = string
}

variable "kubernetes_version" {
  description = "Version Kubernetes actuellement supportée par EKS."
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC dédiée au cluster."
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets privés répartis dans trois AZ."
  type        = list(string)
}

variable "api_allowed_cidrs" {
  description = "CIDR autorisés à joindre le endpoint public de l'API EKS."
  type        = list(string)
}

variable "tags" {
  description = "Tags communs aux ressources du cluster."
  type        = map(string)
  default     = {}
}