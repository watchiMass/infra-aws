# Stockage S3 des backends d'observabilité (Loki, Tempo).
# La rétention est gérée par Loki/Tempo eux-mêmes : pas de lifecycle ici.
resource "aws_s3_bucket" "this" {
  for_each = var.buckets

  bucket = each.key
  tags   = var.tags

  # force_destroy assumé (stratégie « destroy total » en dev, choix utilisateur) :
  # les logs/traces accumulés disparaissent avec les buckets au destroy.
  force_destroy = true
}

# SSE-S3 : suffisant pour des logs/traces, sans coût de clé KMS.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Les données d'observabilité ne sont JAMAIS publiques.
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
