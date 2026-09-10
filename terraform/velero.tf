# Disaster recovery applicatif (Velero) - voir disaster-recovery/README.md
# pour le raisonnement complet, notamment l'adaptation par rapport à un
# snapshot etcd classique (inapplicable sur un control plane EKS managé).

resource "aws_s3_bucket" "velero_backups" {
  bucket = "${local.name_prefix}-velero-backups"

  # Ce projet est détruit et recréé entre les sessions de travail : le
  # bucket ne doit jamais bloquer un `terraform destroy` parce qu'il
  # contient encore des sauvegardes (même leçon que force_delete sur ECR,
  # Phase 4).
  force_destroy = true

  tags = {
    Name = "${local.name_prefix}-velero-backups"
  }
}

resource "aws_s3_bucket_public_access_block" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "velero_assume_role" {
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

    # Namespace/ServiceAccount par défaut du chart Helm vmware-tanzu/velero.
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:velero:velero"]
    }
  }
}

resource "aws_iam_role" "velero" {
  name               = "${local.name_prefix}-velero"
  assume_role_policy = data.aws_iam_policy_document.velero_assume_role.json

  tags = {
    Name = "${local.name_prefix}-velero"
  }
}

# Permissions volontairement limitées au stockage S3 des sauvegardes.
# Les permissions EC2 (ec2:CreateSnapshot, DescribeVolumes...) recommandées
# par la doc officielle du plugin AWS de Velero servent aux snapshots EBS
# de volumes persistants - ce projet n'a aucun PersistentVolume (Prometheus
# et Grafana tournent en stockage éphémère, voir monitoring/README.md), les
# accorder maintenant serait une permission inutilisée. À ajouter le jour
# où une charge de travail avec état persistant apparaîtrait.
data "aws_iam_policy_document" "velero" {
  statement {
    sid    = "VeleroS3Objects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.velero_backups.arn}/*"]
  }

  statement {
    sid       = "VeleroS3ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.velero_backups.arn]
  }
}

resource "aws_iam_policy" "velero" {
  name        = "${local.name_prefix}-velero"
  description = "Permet a Velero de lire/ecrire ses sauvegardes dans son bucket S3 dedie, uniquement."
  policy      = data.aws_iam_policy_document.velero.json
}

resource "aws_iam_role_policy_attachment" "velero" {
  role       = aws_iam_role.velero.name
  policy_arn = aws_iam_policy.velero.arn
}
