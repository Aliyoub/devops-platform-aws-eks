# Politiques IAM attachées aux rôles du projet. Le rôle GitHub Actions
# (oidc.tf) ne reçoit ici que les permissions dont il a besoin *maintenant*
# (pousser une image sur ECR) ; les permissions Terraform/EKS nécessaires au
# déploiement complet (cd.yml, Phase 7) seront ajoutées de façon incrémentale
# aux phases suivantes plutôt que données en bloc dès le départ - moindre
# privilège appliqué à la construction du projet elle-même, pas seulement au
# résultat final.

data "aws_iam_policy_document" "github_actions_ecr_push" {
  statement {
    sid     = "ECRAuth"
    effect  = "Allow"
    actions = ["ecr:GetAuthorizationToken"]
    # ecr:GetAuthorizationToken s'authentifie au niveau du compte, pas d'un
    # repository - AWS exige resource = "*" pour cette action précise.
    resources = ["*"]
  }

  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_policy" "github_actions_ecr_push" {
  name        = "${local.name_prefix}-github-actions-ecr-push"
  description = "Permet a GitHub Actions de pousser des images sur le repository ECR du projet, uniquement."
  policy      = data.aws_iam_policy_document.github_actions_ecr_push.json
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr_push.arn
}

# Phase 7 (cd.yml) : uniquement de quoi récupérer les infos du cluster pour
# générer un kubeconfig (`aws eks update-kubeconfig`). L'autorisation
# d'agir une fois connecté vient de l'access entry EKS (eks.tf), pas d'IAM.
data "aws_iam_policy_document" "github_actions_eks_describe" {
  statement {
    sid       = "EKSDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [aws_eks_cluster.main.arn]
  }
}

resource "aws_iam_policy" "github_actions_eks_describe" {
  name        = "${local.name_prefix}-github-actions-eks-describe"
  description = "Permet a GitHub Actions de recuperer les infos du cluster EKS pour generer un kubeconfig."
  policy      = data.aws_iam_policy_document.github_actions_eks_describe.json
}

resource "aws_iam_role_policy_attachment" "github_actions_eks_describe" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_eks_describe.arn
}
