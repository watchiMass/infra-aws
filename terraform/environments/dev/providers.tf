provider "aws" {
  region = var.region

  default_tags {
    tags = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# GitHub : dépôts GitOps et fichier metadata.yaml (pont §2.7).
provider "github" {
  owner = var.git_org
  token = var.github_token
}
