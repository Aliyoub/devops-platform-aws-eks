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
