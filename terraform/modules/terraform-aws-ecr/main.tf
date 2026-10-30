# Registre privé ECR : un repository par application.
resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name                 = each.key
  image_tag_mutability = "MUTABLE" # dev ; en prod : IMMUTABLE + tags sha uniquement

  image_scanning_configuration {
    scan_on_push = true # Trivy côté CI + scan ECR en deuxième ligne
  }

  tags = var.tags
}

# Hygiène : au-delà de 20 images par repo, les plus anciennes expirent.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = var.repositories
  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conserver max 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

data "aws_caller_identity" "current" {}

# Provider OIDC GitHub Actions — ressource UNIQUE au niveau du compte.
# S'il existe déjà dans le compte : create_github_oidc_provider = false,
# fournir github_oidc_provider_arn (ou importer la ressource existante).
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Rôle assumé par la CI GitHub Actions (OIDC — zéro clé statique).
resource "aws_iam_role" "github_actions_ecr" {
  name = "${var.prefix}-github-actions-ecr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            for repo in var.github_repos :
            "repo:${var.github_org}/${repo}:ref:refs/heads/${var.github_branch}"
          ]
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

# Policy inline : autorisation de push d'images, rien d'autre.
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push"
  role = aws_iam_role.github_actions_ecr.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/*"
      },
    ]
  })
}
