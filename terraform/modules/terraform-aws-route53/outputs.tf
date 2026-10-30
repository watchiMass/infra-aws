output "zone_id" {
  description = "ID de la zone hébergée Route 53."
  value       = aws_route53_zone.this.zone_id
}

output "zone_arn" {
  description = "ARN de la zone, utilisé par les politiques IRSA (external-dns)."
  value       = aws_route53_zone.this.arn
}

output "name_servers" {
  description = "Name servers de la zone — à déléguer dans la zone racine."
  value       = aws_route53_zone.this.name_servers
}
