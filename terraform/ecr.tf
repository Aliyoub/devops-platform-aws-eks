resource "aws_ecr_repository" "app" {
  name = local.name_prefix

  # IMMUTABLE : une fois poussé, un tag ne peut plus être écrasé. Cohérent
  # avec le principe "ne jamais dépendre uniquement de latest" (brief §10) :
  # ça force un tag traçable et unique par build (ex. le SHA du commit) au
  # lieu de laisser un tag flottant être remplacé silencieusement.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.name_prefix}-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expirer les images non taguees apres 7 jours"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Ne conserver que les 15 dernieres images taguees"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 15
        }
        action = { type = "expire" }
      }
    ]
  })
}
