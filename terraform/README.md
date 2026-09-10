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
eks.tf         # Cluster EKS, node group, accès admin/CD, add-ons metrics-server/vpc-cni (Phase 5-9)
security-groups.tf  # Durcissement du security group par défaut du VPC (Phase 5)
load-balancer-controller.tf  # IRSA pour l'AWS Load Balancer Controller (Phase 6)
policies/      # Documents IAM trop volumineux pour être inline (Phase 6)
velero.tf      # Bucket S3 + IRSA pour Velero (Phase 11)
```

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
- **Aucun security group "control plane"/"nodes" recréé à la main** :
  vérifié contre la documentation AWS à jour avant d'écrire `eks.tf` —
  dupliquer ce pattern est une pratique obsolète pour un node group managé.
  EKS crée et gère un security group unique, self-referencing, appliqué au
  control plane et aux nœuds ; rien n'y est autorisé en entrée depuis
  Internet par défaut, même si les nœuds ont une IP publique (confirmé
  indépendamment via `aws ec2 describe-security-groups` après apply). Le
  seul durcissement ajouté à la main (`security-groups.tf`) est le security
  group par défaut du VPC, vidé de toute règle (aligné CIS AWS Foundations
  Benchmark 5.3).
- **Aucune version Kubernetes épinglée** dans `aws_eks_cluster` : EKS
  déprécie une version tous les ~14 mois environ, épingler un numéro figé
  ici risquerait un apply en échec plus tard sur une version qui ne serait
  plus supportée. La version réellement déployée est exposée via l'output
  `eks_cluster_version`.
- **`authentication_mode = "API"`** (Access Entries) plutôt que l'ancien
  `aws-auth` ConfigMap : plus simple à gérer entièrement en Terraform, sans
  provider Kubernetes additionnel. Un access entry dédié donne un accès
  admin à l'utilisateur IAM qui applique ce Terraform — sans lui, même le
  créateur du cluster n'aurait pas accès à l'API.
- **Endpoint API public, non restreint par IP** : la CD (Phase 7) déploiera
  depuis des runners GitHub Actions hébergés dont les IP changent en
  permanence, donc une whitelist par IP casserait le pipeline. La véritable
  frontière de sécurité est IAM (Access Entries), pas le réseau.
- **1 seul nœud `t3.medium`, taille fixe, `ON_DEMAND`** : voir le
  raisonnement complet dans `eks.tf` (pas de Spot avec un nœud unique sans
  redondance, capacité suffisante pour héberger l'app et l'observabilité à
  venir sur un seul nœud plutôt que de recréer le cluster à chaque phase).
- **IRSA distinct pour l'AWS Load Balancer Controller** (`load-balancer-controller.tf`) :
  contrairement au fournisseur OIDC de GitHub Actions, celui du cluster EKS
  n'est pas dans la liste des fournisseurs "connus" validés nativement par
  AWS - `thumbprint_list` reste obligatoire ici, calculé dynamiquement via
  `data "tls_certificate"` plutôt que codé en dur. La policy IAM est celle
  publiée par le projet upstream (`policies/`, v3.5.0), copiée telle quelle
  plutôt que réécrite à la main pour éviter d'oublier une permission.
- **Add-on `metrics-server`** ajouté explicitement : sans lui, un
  `HorizontalPodAutoscaler` créé par le chart Helm de l'app resterait
  décoratif (métriques `<unknown>`, jamais de scaling réel). Add-on géré
  par AWS, gratuit.
- **Accès EKS de la CD limité au namespace `default`** (`AmazonEKSEditPolicy`
  scopé, pas `AmazonEKSClusterAdminPolicy`) : le rôle GitHub Actions
  (`oidc.tf`) ne doit gérer que les ressources applicatives de son propre
  namespace, jamais le control plane, le node group ou les composants de
  plateforme installés à part (contrôleur ALB, metrics-server).
- **`cd.yml` ne fait jamais `terraform apply`** : un pipeline non surveillé
  qui provisionnerait automatiquement des ressources payantes (EKS, ALB) à
  chaque push contournerait la règle "informer du coût avant toute création
  payante" suivie dans ce projet. Le provisioning de l'infrastructure reste
  une étape manuelle et délibérée ; `cd.yml` ne fait que déployer
  l'application sur un cluster qui existe déjà.

### Bug réel rencontré : format du `sub` claim OIDC GitHub

Le premier run réel de `cd.yml` a échoué sur *chaque* tentative avec
`Not authorized to perform sts:AssumeRoleWithWebIdentity`, alors que la
trust policy suivait exactement le format documenté par GitHub et AWS
(`repo:<owner>/<repo>:ref:refs/heads/<branch>`).

Plutôt que de deviner, un job de debug temporaire a décodé le vrai jeton
OIDC émis par GitHub pour ce run (`ACTIONS_ID_TOKEN_REQUEST_TOKEN`/`_URL`,
partie payload en base64). Le `sub` réel était :

```
repo:Aliyoub@25158336/devops-platform-aws-eks@1361862012:ref:refs/heads/main
```

— le format **"immutable subject claim"** (avec les IDs numériques du
compte et du repository), pas le format classique attendu. Point piégeux
supplémentaire : l'API `GET /repos/{owner}/{repo}/actions/oidc/customization/sub`
répond `"use_immutable_subject": false` pour ce repository, ce qui laissait
penser que le format classique était actif — alors que le jeton réellement
émis utilisait bien le format immutable. Décoder le jeton réel a été le
seul moyen fiable de trancher.

Corrigé en alignant la condition `sub` de la trust policy sur ce format
exact. Un bon rappel que pour l'authentification, il faut vérifier ce qui
est réellement émis plutôt que ce que la documentation ou une API annexe
prétend.

### Bug réel rencontré : l'application des NetworkPolicy n'était pas active

En Phase 9, les `NetworkPolicy` du chart `helm/myapp` (default-deny +
autorisations explicites) n'avaient aucun effet mesurable : un test d'egress
volontairement interdit (requête HTTP sortante vers un site externe depuis
un pod applicatif) réussissait quand même. Le conteneur
`aws-eks-nodeagent`, censé faire respecter ces règles, tournait bien
(`Running`), ce qui aurait pu faire croire à tort que tout fonctionnait.

En creusant, `vpc-cni` n'était pas géré comme add-on EKS explicite dans ce
projet — c'est celui installé par défaut par EKS à la création du cluster,
en dehors de toute gestion Terraform. Dans cet état, l'application des
NetworkPolicy n'est pas activée par défaut. Plutôt que de deviner un nom de
variable, le schéma de configuration réel de l'addon a été interrogé
(`aws eks describe-addon-configuration --addon-name vpc-cni ...`), qui a
révélé la clé exacte : `enableNetworkPolicy`. Corrigé en gérant `vpc-cni`
comme un `aws_eks_addon` Terraform explicite (adopté via
`resolve_conflicts_on_create = "OVERWRITE"`, sans recréer le composant
existant) avec `configuration_values = { enableNetworkPolicy = "true" }`.

Revérifié empiriquement après coup, pas supposé corrigé : le même test
d'egress échoue désormais bien (timeout), tandis que le DNS et le trafic
entrant depuis l'ALB continuent de fonctionner normalement.

### Velero (`velero.tf`, Phase 11)

- **Bucket S3 en `force_destroy = true`** : même raison que `force_delete`
  sur ECR (Phase 4) — ne jamais bloquer un `terraform destroy` entre deux
  sessions de travail parce que le bucket contient encore des sauvegardes.
- **Aucune permission IAM EC2/EBS** accordée à Velero (snapshots de
  volumes) : ce projet n'a aucun `PersistentVolume`, les accorder serait
  une permission inutilisée. Voir `disaster-recovery/README.md`.
- **IRSA via le fournisseur OIDC du cluster déjà existant**
  (`aws_iam_openid_connect_provider.eks`, créé en Phase 6 pour le
  contrôleur ALB) plutôt qu'un nouveau fournisseur — un cluster n'a qu'un
  seul OIDC issuer, pas besoin d'en recréer un par composant.

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

# Une fois le cluster créé, configurer kubectl (fichier dédié, ne touche
# jamais un ~/.kube/config existant) :
../scripts/get-kubeconfig.sh
KUBECONFIG=~/.kube/devops-platform-aws-eks.yaml kubectl get nodes
```
