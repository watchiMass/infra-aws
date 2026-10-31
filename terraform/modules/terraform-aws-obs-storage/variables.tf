variable "buckets" {
  description = "Noms des buckets S3 de stockage d'observabilité."
  type        = set(string)
}

variable "tags" {
  description = "Tags communs appliqués aux buckets."
  type        = map(string)
  default     = {}
}
