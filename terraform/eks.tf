data "aws_caller_identity" "current" {}

# --- Rôle IAM du control plane EKS ---

resource "aws_iam_role" "eks_cluster" {
  name = "${local.name_prefix}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-eks-cluster"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Cluster EKS ---
#
# Pas de version epinglee explicitement : le brief privilegie des versions
# explicites (Terraform, providers), mais pour la version Kubernetes elle-
# meme, EKS deprecie une version tous les ~14 mois - epingler un numero ici
# risquerait de faire echouer l'apply avec une version qui n'est plus
# supportee au moment ou ce projet sera relu. En omettant `version`, EKS
# utilise la derniere version disponible au moment de la creation (voir la
# doc du provider AWS) ; la version reellement deployee est exposee en
# output apres apply, donc jamais ambigue.
#
# endpoint_public_access = true, sans restriction de public_access_cidrs :
# la CD (Phase 7) deploie depuis des runners GitHub Actions heberges, dont
# les IP changent en permanence - impossible de les whitelister de facon
# fiable. La vraie frontiere de securite ici n'est pas reseau mais IAM : le
# cluster utilise authentication_mode = "API" (Access Entries), donc seuls
# les principals IAM explicitement autorises ci-dessous peuvent s'y
# authentifier, quelle que soit l'IP d'origine.
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    endpoint_public_access  = true
    endpoint_private_access = false
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  access_config {
    authentication_mode = "API"
  }

  tags = {
    Name = "${local.name_prefix}-eks"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Accès administrateur pour l'utilisateur IAM qui applique ce Terraform
# (moi). Sans ça, meme le créateur du cluster ne peut pas s'y connecter
# avec kubectl : authentication_mode = "API" ne donne plus d'accès implicite
# au principal créateur (contrairement à l'ancien comportement par défaut).
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Accès pour le pipeline CD (GitHub Actions, Phase 7) : uniquement
# AmazonEKSEditPolicy scopé au namespace "default", où vit l'application.
# Pas d'accès cluster-admin pour la CD - elle n'a besoin de gérer que les
# ressources applicatives de son propre namespace, jamais le control plane,
# le node group ou les composants de plateforme (contrôleur ALB,
# metrics-server) installés à part.
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.github_actions.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.github_actions.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }
}

# --- Rôle IAM du node group ---

resource "aws_iam_role" "eks_nodes" {
  name = "${local.name_prefix}-eks-nodes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-eks-nodes"
  }
}

resource "aws_iam_role_policy_attachment" "eks_nodes_worker_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_ecr_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- Node group managé ---
#
# 1 seul node, taille fixe (desired = min = max) : pas d'autoscaling de
# nœuds pour ce projet (Cluster Autoscaler/Karpenter seraient l'amélioration
# naturelle pour la suite). ON_DEMAND plutôt que SPOT : avec un seul nœud,
# une interruption Spot ferait tomber tout le
# cluster sans redondance pour absorber le choc pendant une session de
# travail active - la légère économie ne compense pas le risque
# d'interruption imprévisible en plein travail.
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.public[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = var.eks_node_instance_types

  scaling_config {
    desired_size = var.eks_node_desired_size
    min_size     = var.eks_node_desired_size
    max_size     = var.eks_node_desired_size
  }

  tags = {
    Name = "${local.name_prefix}-eks-nodes"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_worker_policy,
    aws_iam_role_policy_attachment.eks_nodes_cni_policy,
    aws_iam_role_policy_attachment.eks_nodes_ecr_policy,
    aws_eks_access_policy_association.admin,
  ]
}

# metrics-server : sans lui, un HorizontalPodAutoscaler créé plus tard
# (helm/myapp) resterait "décoratif" - il existerait mais afficherait
# <unknown> pour les métriques CPU et ne scalerait jamais réellement.
# Add-on géré par AWS (gratuit, un seul petit pod), plutôt qu'un Helm chart
# tiers à maintenir soi-même.
resource "aws_eks_addon" "metrics_server" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "metrics-server"
  addon_version = "v0.9.0-eksbuild.9"

  depends_on = [aws_eks_node_group.main]
}

# vpc-cni est installé par défaut par EKS à la création du cluster, en
# dehors de toute gestion Terraform - mais dans cet état "self-managed",
# l'application des NetworkPolicy (helm/myapp) n'est PAS activée par
# défaut, malgré la présence du conteneur aws-eks-nodeagent (vérifié
# empiriquement : un test d'egress vers un site externe passait alors
# qu'il aurait dû être bloqué par une NetworkPolicy default-deny). La clé
# `enableNetworkPolicy` doit être positionnée explicitement - vérifiée
# contre le schéma de configuration réel de l'addon
# (`aws eks describe-addon-configuration`) plutôt que supposée. On
# "adopte" ici le composant déjà présent via resolve_conflicts_on_create
# = OVERWRITE, sans le recréer.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.23.0-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })

  depends_on = [aws_eks_node_group.main]
}
