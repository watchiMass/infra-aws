output "repository_urls" {
  description = "URLs des repositories ECR (nom → URL)."
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.repository_url
  }
}

output "github_actions_role_arn" {
  description = "ARN du rôle IAM assumé par la CI GitHub Actions."
  value       = aws_iam_role.github_actions_ecr.arn
}
