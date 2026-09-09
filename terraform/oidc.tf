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
    #
    # Format "immutable subject claim" (repo:<owner>@<user_id>/<repo>@<repo_id>:...)
    # et non le format classique repo:<owner>/<repo>:... documenté par
    # défaut dans la doc GitHub/AWS - découvert en décodant réellement le
    # token OIDC émis par ce compte (un job de debug temporaire l'a
    # affiché), pas en supposant le format par défaut. Le endpoint
    # `GET /repos/{owner}/{repo}/actions/oidc/customization/sub` reste
    # trompeur ici : il répond `use_immutable_subject: false` alors que le
    # token réellement émis utilise bien ce format.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Aliyoub@25158336/devops-platform-aws-eks@1361862012:ref:refs/heads/main"]
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
