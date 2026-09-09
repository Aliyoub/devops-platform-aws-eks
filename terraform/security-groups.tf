# Choix vérifié contre la documentation AWS à jour (docs.aws.amazon.com/eks/
# latest/userguide/sec-group-reqs.html) avant d'écrire ce fichier : recréer
# manuellement un security group "control plane" et un security group
# "nodes" séparés avec des règles croisées est l'ancien pattern (clusters
# <= 1.14 / platform eks.3), explicitement documenté comme obsolète pour un
# node group managé. Depuis, EKS crée et gère lui-même un unique security
# group ("cluster security group"), appliqué à la fois aux ENI du control
# plane et à celles des nœuds du node group managé, avec des règles par
# défaut suffisantes et déjà restrictives : tout le trafic est autorisé
# entre les membres du groupe (self-referencing), rien n'est autorisé en
# entrée depuis Internet - même si nos nœuds ont une IP publique (faute de
# NAT Gateway), ce security group ne les expose à aucune connexion entrante
# non sollicitée par défaut. Dupliquer cette logique à la main aujourd'hui
# irait à l'encontre de la pratique recommandée actuelle, pas dans son
# sens.
#
# Ce qui reste réellement à durcir explicitement : le security group par
# défaut du VPC, qui autorise par défaut tout le trafic entre ses membres.
# Aucune ressource de ce projet ne l'utilise (EKS gère les siens), mais le
# laisser permissif est un point classique de durcissement AWS (aligné CIS
# AWS Foundations Benchmark 5.3) - le vider explicitement documente cette
# intention plutôt que de compter sur le fait qu'il soit simplement inutilisé.

resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  # Aucune règle ingress/egress déclarée : le security group par défaut du
  # VPC n'autorise donc plus aucun trafic.

  tags = {
    Name = "${local.name_prefix}-default-sg-restricted"
  }
}
