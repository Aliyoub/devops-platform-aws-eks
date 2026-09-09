# Fournisseur OIDC + rôle IAM permettant à GitHub Actions de s'authentifier
# à AWS sans clé statique. Voir terraform/README.md pour le raisonnement
# complet.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # thumbprint_list volontairement omis : depuis 2023, AWS valide les
  # fournisseurs OIDC connus (dont GitHub) via sa propre liste d'autorités
  # de certification racine de confiance plutôt que via un thumbprint
  # fourni manuellement (argument désormais optionnel dans le provider
  # AWS). Ça évite de maintenir une valeur qui deviendrait périmée si
  # GitHub change son certificat intermédiaire.

  tags = {
    Name = "${local.name_prefix}-github-oidc"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scope strict : seul un run déclenché sur la branche main de ce
    # repository précis peut assumer ce rôle. Une pull request (même
    # ouverte depuis ce repo) ne matche pas ce sub claim et ne peut donc
    # jamais obtenir de credentials AWS - cohérent avec ci.yml qui ne
    # touche jamais l'AWS réel.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Aliyoub/devops-platform-aws-eks:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${local.name_prefix}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "${local.name_prefix}-github-actions"
  }
}
