# Helm

## Pourquoi Helm

Kubernetes seul (manifests YAML bruts) n'a pas de notion de version
d'application déployée, ni de mécanisme de rollback atomique, ni de moyen
propre de paramétrer un même ensemble de ressources selon l'environnement
(dev/prod). Helm résout ces trois problèmes : `helm upgrade` produit une
révision numérotée et `helm rollback` revient dessus instantanément, et les
fichiers `values-*.yaml` permettent de garder un seul jeu de templates
pour plusieurs environnements plutôt que de dupliquer des manifests.

## Structure

```
myapp/
├── Chart.yaml
├── values.yaml        # défauts
├── values-dev.yaml     # réellement appliqué dans ce projet
├── values-prod.yaml    # illustratif, jamais appliqué contre une vraie infra
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    ├── serviceaccount.yaml
    ├── hpa.yaml
    ├── poddisruptionbudget.yaml
    └── networkpolicy.yaml
```

Pas de `secret.yaml` : l'application n'a actuellement aucune donnée
sensible à stocker (pas de base de données, pas de clé API externe). En
ajouter un maintenant créerait un composant qui ne protège rien de réel.

## Choix effectués

- **Ingress `alb` (AWS Load Balancer Controller)** plutôt qu'ingress-nginx :
  voir la justification dans le README principal / `PLAN.md`. Provisionne
  un vrai Application Load Balancer AWS à l'`helm install`.
- **`readOnlyRootFilesystem: true`** sur le conteneur : le serveur Next.js
  standalone n'a besoin d'écrire nulle part sur son propre système de
  fichiers pour fonctionner ; un `emptyDir` est monté sur `/tmp` au cas où
  une dépendance y écrirait (`os.tmpdir()`). Vérifié réellement : les pods
  démarrent et passent les probes sans erreur d'écriture.
- **`runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities: drop
  [ALL]`** : cohérent avec l'utilisateur non-root déjà défini dans l'image
  Docker (Phase 1).
- **`checksum/config` en annotation du pod** : force un rolling restart
  automatique si le ConfigMap change (sinon Kubernetes ne redéploierait pas
  les pods existants pour une simple mise à jour de configuration).
- **`maxUnavailable: 0, maxSurge: 1`** sur le rolling update : jamais moins
  de replicas disponibles pendant un déploiement, un pod de plus le temps
  du remplacement.
- **HPA branché sur un vrai `metrics-server`** (ajouté en add-on EKS via
  Terraform, `eks.tf`) plutôt que laissé décoratif : sans lui, le HPA
  existerait mais afficherait `<unknown>` pour le CPU et ne scalerait
  jamais. Vérifié réellement : `kubectl get hpa` renvoie une métrique CPU
  chiffrée (`cpu: 2%/70%`), pas `<unknown>`.
- **PodDisruptionBudget `minAvailable: 1`** : garantit qu'un drain de nœud
  ou une maintenance ne fasse jamais tomber tous les replicas en même
  temps (pertinent surtout avec plusieurs nœuds ; documenté ici même si ce
  projet n'a qu'un seul nœud EKS).
- **Tag d'image jamais `latest`** : le tag est le SHA court du commit
  (cohérent avec le repository ECR en `IMMUTABLE`, Phase 4).
- **`seccompProfile: RuntimeDefault`** (Phase 9) : requis par Pod Security
  Admission en mode `restricted`, activé sur le namespace `default`. Sans
  lui, les pods sont rejetés à la création — constaté réellement (le
  namespace labellisé `restricted` a immédiatement averti que les pods
  existants violaient la policy, avant ce correctif).
- **`NetworkPolicy` default-deny + autorisations explicites** (Phase 9) :
  ingress limité au port applicatif depuis le CIDR du VPC, egress limité au
  DNS uniquement. Vérifié empiriquement, pas supposé : test positif (l'ALB
  atteint toujours l'app) et test négatif (une requête sortante vers un
  site externe, exécutée depuis un pod, timeout comme attendu). Limite
  honnêtement documentée dans `networkpolicy.yaml` : avec le VPC CNI, les
  pods et les ENI de l'ALB partagent le même espace d'adressage, donc
  l'ipBlock ne distingue pas "trafic de l'ALB" de "trafic d'un autre pod du
  cluster" — sa vraie valeur est de limiter le port et de bloquer
  l'extérieur du VPC, pas une segmentation pod-à-pod fine.
- **RBAC** : le ServiceAccount `myapp` n'a aucun Role/RoleBinding — l'appli
  ne parle jamais à l'API Kubernetes, donc la forme la plus stricte du
  moindre privilège est de ne lui donner aucune permission. Vérifié via
  `kubectl auth can-i list pods --as=system:serviceaccount:default:myapp`
  → `no`.

## Déploiement réel effectué

```
helm install myapp helm/myapp \
  -f helm/myapp/values-dev.yaml \
  --set image.repository=<url_ecr> \
  --set image.tag=<sha_du_commit>
```

Vérifié après déploiement (pas seulement le statut `helm install`, mais le
comportement réel) : `kubectl get pods` (2/2 `Running`), l'Ingress
réconcilié avec un vrai nom DNS d'ALB, et les 4 routes de l'application
(`/`, `/architecture`, `/health`, `/ready`) répondant `200` en HTTP à
travers cet ALB public.
