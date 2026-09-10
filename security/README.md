# Sécurité

Vue d'ensemble des mesures de sécurité du projet — chacune est détaillée et
justifiée dans le README du module concerné ; ce fichier fait le lien entre
elles plutôt que de dupliquer le détail.

## Défense en profondeur : trois couches indépendantes

| Couche | Mesures | Détail |
|---|---|---|
| **Kubernetes** | RBAC least-privilege, SecurityContext restrictif, NetworkPolicy default-deny, Pod Security Admission `restricted` | `helm/README.md` |
| **AWS/IAM** | OIDC sans clé statique, permissions accordées de façon incrémentale, IAM scopé par ressource | `terraform/README.md` |
| **Conteneur** | Build multi-stage minimal, non-root, scan Trivy en gate CI | `docker/README.md`, `.github/workflows/ci.yml` |

Si une couche est mal configurée, les autres limitent quand même le risque.

## RBAC

Le ServiceAccount `myapp` n'a **aucun** Role/RoleBinding — l'application ne
parle jamais à l'API Kubernetes, donc la forme la plus stricte du moindre
privilège est de ne lui accorder aucune permission. Vérifié réellement :

```
kubectl auth can-i list pods --as=system:serviceaccount:default:myapp -n default
# no
```

Le rôle IAM de la CD (GitHub Actions, Phase 7) a un accès EKS limité au
namespace `default` (`AmazonEKSEditPolicy` scopé, pas cluster-admin) — voir
`terraform/README.md`.

## SecurityContext

`runAsNonRoot`, utilisateur/groupe non-root fixes (1001),
`allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`,
`capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`. Détail et
vérifications dans `helm/README.md`.

## NetworkPolicy

Default-deny (ingress + egress) sur les pods de l'application, puis
autorisations explicites : ingress depuis le VPC sur le port applicatif
uniquement, egress DNS uniquement. **Vérifié empiriquement**, pas supposé :
un test d'egress vers un site externe, exécuté depuis un pod réel, échoue
bien (timeout) après activation ; l'ALB atteint toujours l'application.

Un vrai bug a été rencontré ici : la présence du conteneur
`aws-eks-nodeagent` ne suffisait pas — l'application effective des
NetworkPolicy nécessite `enableNetworkPolicy: "true"` dans la configuration
de l'addon EKS `vpc-cni` (vérifié contre le schéma de configuration réel de
l'addon, pas deviné). Détail complet dans `terraform/README.md`.

## Pod Security Admission

Namespace `default` labellisé en mode `restricted`
(`security/namespace-default.yaml`) — le niveau le plus strict des Pod
Security Standards de Kubernetes. Constaté réellement : appliquer ce label
avant que les pods respectent ses exigences produit un avertissement
explicite listant la violation exacte (ici, l'absence de `seccompProfile`).

## Scan de vulnérabilités (Trivy)

Intégré au job Docker de `ci.yml`, bloque le pipeline (`exit-code: 1`) sur
toute vulnérabilité HIGH ou CRITICAL avec un correctif disponible
(`ignore-unfixed: true` — on ne peut pas bloquer indéfiniment sur des CVE
qu'on ne peut littéralement pas corriger nous-mêmes).

Un vrai scan a trouvé des vulnérabilités HIGH/CRITICAL réelles dans
l'image : des paquets Alpine (OpenSSL) non patchés, et surtout `npm`/`npx`
embarqués dans l'image finale avec leurs propres dépendances vendorisées
vulnérables — alors que le runtime n'exécute jamais `npm` (seulement
`node server.js`). Corrigé dans `docker/Dockerfile` (`apk upgrade` +
suppression de `npm`/`npx` du stage final), revérifié par un nouveau scan :
0 vulnérabilité HIGH/CRITICAL. Détail dans `docker/README.md`.

## AWS

IAM least-privilege (permissions accordées de façon incrémentale au fil
des phases, jamais en bloc par anticipation), Security Groups restrictifs
(le SG géré par EKS n'autorise rien depuis Internet même si les nœuds ont
une IP publique — pas de NAT Gateway dans le profil low-cost), aucune
credential en clair dans le repository. Détail dans `terraform/README.md`.
