variable "domain_name" {
  description = "Nom de domaine complet de la zone (ex. dev.obszh.fr)."
  type        = string
}

variable "tags" {
  description = "Tags communs appliqués à la zone."
  type        = map(string)
  default     = {}
}
