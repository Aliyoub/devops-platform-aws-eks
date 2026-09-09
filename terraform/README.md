# Terraform

## Structure

Un fichier par domaine plutôt qu'un seul gros fichier, pour rester lisible
et faciliter la revue de code :

```
versions.tf    # contraintes de version Terraform et du provider AWS
providers.tf   # configuration du provider AWS (région, tags par défaut)
main.tf        # locals partagés (préfixe de nommage, tags communs)
variables.tf   # variables d'entrée
outputs.tf     # valeurs exposées après apply
vpc.tf         # VPC, subnets, Internet Gateway, table de routage (Phase 3)
ecr.tf         # Repository ECR + lifecycle policy (Phase 4)
oidc.tf        # Fournisseur OIDC GitHub Actions + rôle IAM assumable (Phase 4)
iam.tf         # Politiques IAM attachées aux rôles du projet (Phase 4+)
```

D'autres fichiers arriveront à la Phase 5 : `eks.tf` et
`security-groups.tf`.

## Choix effectués

- **Provider AWS `~> 6.0`** : version majeure actuelle au moment du projet
  (vérifiée sur le registry Terraform, pas supposée de mémoire).
- **`default_tags` au niveau du provider** plutôt que de répéter les mêmes
  tags sur chaque ressource : `Project`, `Environment` et `ManagedBy` sont
  appliqués automatiquement à tout ce que Terraform crée ; seuls les tags
  spécifiques à une ressource (`Name`, tags de découverte Kubernetes) sont
  déclarés explicitement.
- **`data "aws_availability_zones"`** plutôt que des noms d'AZ codés en
  dur : le code reste correct si on change de région, sans dépendre d'AZ
  qui n'existent pas partout.
- **Uniquement des subnets publics, pas de NAT Gateway** : c'est le profil
  low-cost retenu pour ce projet (voir la racine du repo et `PLAN.md`). Le
  compromis et l'alternative "prod-like" sont documentés dans le README
  principal.
- **Tags `kubernetes.io/cluster/<nom>` et `kubernetes.io/role/elb`** sur les
  subnets publics : requis par EKS et par l'AWS Load Balancer Controller
  (Phase 6) pour découvrir automatiquement dans quels subnets provisionner
  le cluster et les Application Load Balancer.
- **État Terraform local** (pas de backend S3 distant) : ce projet est géré
  par une seule personne, l'infrastructure est détruite entre les sessions
  de travail, et un backend distant (S3 + verrouillage natif depuis
  Terraform 1.10, sans DynamoDB nécessaire) n'apporte de valeur réelle que
  pour du travail en équipe ou une infrastructure durable. Ajouter un
  bucket S3 juste pour l'état irait à l'encontre du principe "aucune
  ressource AWS inutile" pour ce cas d'usage. `terraform.tfstate*` est
  gitignored car il peut contenir des données sensibles.
- **Repository ECR en `IMMUTABLE`** : un tag poussé ne peut jamais être
  écrasé, ce qui force des tags traçables (SHA de commit) plutôt qu'un
  `latest` flottant réécrit silencieusement à chaque build.
- **Lifecycle policy ECR** : les images non taguées expirent après 7 jours,
  et seules les 15 dernières images taguées sont conservées — évite une
  dérive de coût de stockage au fil des builds successifs.
- **OIDC plutôt que des clés IAM statiques** pour GitHub Actions : le
  `thumbprint_list` de `aws_iam_openid_connect_provider` est volontairement
  omis (AWS valide désormais les fournisseurs OIDC connus comme GitHub via
  sa propre liste d'autorités de certification, l'argument est optionnel
  depuis 2023). Le rôle IAM assumable est scopé au repository et à la
  branche exacts via le `sub` claim
  (`repo:Aliyoub/devops-platform-aws-eks:ref:refs/heads/main`) : une pull
  request ne peut jamais l'assumer.
- **Permissions IAM ajoutées de façon incrémentale** : le rôle GitHub
  Actions ne reçoit pour l'instant que le droit de pousser sur le
  repository ECR du projet (`iam.tf`). Les permissions Terraform/EKS
  nécessaires au déploiement complet seront ajoutées aux phases suivantes,
  au fur et à mesure des besoins réels du pipeline — pas données en bloc
  par anticipation.

## Commandes

```
cd terraform
cp terraform.tfvars.example terraform.tfvars   # optionnel, les défauts suffisent
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
terraform destroy   # à faire entre chaque session de travail
```
