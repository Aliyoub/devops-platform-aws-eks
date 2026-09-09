output "vpc_id" {
  description = "ID du VPC créé."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs des subnets publics."
  value       = aws_subnet.public[*].id
}

output "availability_zones" {
  description = "Zones de disponibilité utilisées pour les subnets publics."
  value       = aws_subnet.public[*].availability_zone
}

output "internet_gateway_id" {
  description = "ID de l'Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "ecr_repository_url" {
  description = "URL du repository ECR (pour docker push/pull)."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN du repository ECR."
  value       = aws_ecr_repository.app.arn
}

output "github_actions_role_arn" {
  description = "ARN du rôle IAM assumable par GitHub Actions via OIDC (à utiliser dans cd.yml, Phase 7)."
  value       = aws_iam_role.github_actions.arn
}
