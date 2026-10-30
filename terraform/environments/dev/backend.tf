terraform {
  backend "s3" {
    bucket       = "gitops01-state"
    key          = "eks/dev/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
    encrypt      = true

  }
}