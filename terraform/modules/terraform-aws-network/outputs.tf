output "vpc_id" {
  description = "ID de la VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs des subnets privés, destinés aux nœuds EKS."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs des subnets publics, utiles aux load balancers externes."
  value       = module.vpc.public_subnets
}

output "private_route_table_ids" {
  description = "Tables de routage privées."
  value       = module.vpc.private_route_table_ids
}

output "availability_zones" {
  description = "AZ utilisées par la VPC."
  value       = local.azs
}