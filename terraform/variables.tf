variable "aws_region" {
  description = "Région AWS de déploiement."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nom du projet, utilisé comme préfixe pour les ressources et leurs tags."
  type        = string
  default     = "devops-platform-aws-eks"
}

variable "environment" {
  description = "Nom de l'environnement (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Blocs CIDR des subnets publics, un par zone de disponibilité utilisée."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "eks_node_instance_types" {
  description = "Types d'instance EC2 du node group EKS."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Nombre de nœuds du node group (taille fixe : desired = min = max, pas d'autoscaling de nœuds pour ce projet)."
  type        = number
  default     = 1
}
