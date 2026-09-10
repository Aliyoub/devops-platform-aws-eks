# Politique de sécurité

Ce dépôt est un projet personnel de démonstration (portfolio), pas un
service en production recevant du trafic ou des données d'utilisateurs
réels. Il n'y a pas de programme de bug bounty ni d'équipe de sécurité
dédiée.

## Signaler une vulnérabilité

Si vous repérez une vulnérabilité réelle dans ce repository (dépendance,
configuration Terraform/Kubernetes, image Docker...), merci d'ouvrir une
[issue GitHub](https://github.com/Aliyoub/devops-platform-aws-eks/issues)
ou de me contacter directement via mon profil
[github.com/Aliyoub](https://github.com/Aliyoub).

Merci de ne pas divulguer publiquement une vulnérabilité critique avant
qu'elle ait pu être corrigée.

## Mesures de sécurité déjà en place

Le détail complet (RBAC, SecurityContext, NetworkPolicy, Pod Security
Admission, scan de vulnérabilités Trivy, IAM/OIDC least-privilege) est
documenté dans [`security/README.md`](security/README.md).
