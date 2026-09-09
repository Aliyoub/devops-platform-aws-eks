# IRSA (IAM Roles for Service Accounts) pour l'AWS Load Balancer Controller.
# Contrairement au fournisseur OIDC de GitHub Actions (oidc.tf), celui du
# cluster EKS n'est pas dans la liste des fournisseurs "connus" qu'AWS
# valide via sa propre liste d'autorités de certification - thumbprint_list
# reste donc obligatoire ici, calculé dynamiquement plutôt que codé en dur.

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = {
    Name = "${local.name_prefix}-eks-oidc"
  }
}

locals {
  eks_oidc_provider_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scope au ServiceAccount exact utilisé par le chart Helm du contrôleur
    # (kube-system/aws-load-balancer-controller) : aucun autre pod du
    # cluster ne peut assumer ce rôle.
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${local.name_prefix}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json

  tags = {
    Name = "${local.name_prefix}-alb-controller"
  }
}

# Policy IAM officielle du projet aws-load-balancer-controller (v3.5.0,
# https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.5.0/docs/install/iam_policy.json)
# copiée telle quelle plutôt que réécrite à la main : c'est un document
# large et maintenu par le projet lui-même, le dupliquer manuellement
# introduirait un risque de permission manquante ou trop large.
resource "aws_iam_policy" "alb_controller" {
  name        = "${local.name_prefix}-alb-controller"
  description = "Permissions requises par l'AWS Load Balancer Controller (upstream v3.5.0)."
  policy      = file("${path.module}/policies/aws-load-balancer-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
