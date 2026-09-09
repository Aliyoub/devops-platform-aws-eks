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

output "eks_cluster_name" {
  description = "Nom du cluster EKS."
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint de l'API Kubernetes."
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "Version Kubernetes réellement déployée (aucune version épinglée en entrée, voir eks.tf)."
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_security_group_id" {
  description = "ID du security group géré par EKS (control plane + nœuds du node group managé)."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_node_group_status" {
  description = "Statut du node group managé."
  value       = aws_eks_node_group.main.status
}
