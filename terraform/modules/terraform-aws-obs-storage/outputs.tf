output "bucket_arns" {
  description = "ARNs des buckets (nom → ARN)."
  value       = { for name, bucket in aws_s3_bucket.this : name => bucket.arn }
}

output "bucket_names" {
  description = "Noms des buckets (nom → id)."
  value       = { for name, bucket in aws_s3_bucket.this : name => bucket.id }
}
