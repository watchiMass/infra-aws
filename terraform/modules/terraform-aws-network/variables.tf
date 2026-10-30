
variable "vpc_cidr" {
  description = "Bloc CIDR IPv4 de la VPC."
  type        = string
}

variable "eks_cluster_name" {
  description = "Nom EKS utilisé pour le tag de découverte des subnets."
  type        = string
}

variable "nat_gateway_mode" {
  description = "Topologie NAT : un gateway par AZ ou un gateway partagé."
  type        = string

  validation {
    condition     = contains(["per_az", "single"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode doit valoir per_az ou single."
  }

  default = "per_az"
}

variable "tags" {
  description = "Tags communs appliqués aux ressources du module."
  type        = map(string)
  default     = {}
}