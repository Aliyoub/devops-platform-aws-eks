# Troubleshooting

Cinq incidents réalistes, **réellement reproduits** sur le cluster de ce
projet le 2026-09-10 (pas décrits de mémoire, pas simulés) : déclenchés
volontairement, diagnostiqués avec les commandes `kubectl` réelles,
corrigés, puis vérifiés — avec les sorties de commandes réellement
obtenues à chaque étape. Chaque dossier suit le même format : symptôme,
diagnostic, commandes utilisées, cause, correction, vérification, lessons
learned.

| # | Incident | Cause |
|---|---|---|
| [1](incident-1-pod-crashloop/) | Pod ne démarre pas | Probe de liveness pointant vers un chemin inexistant |
| [2](incident-2-service-inaccessible/) | Service inaccessible | Sélecteur du Service ne correspondant à aucun pod |
| [3](incident-3-rbac/) | RBAC insuffisant | ServiceAccount sans Role/RoleBinding |
| [4](incident-4-resources/) | Pod bloqué en Pending | `resources.requests` dépassant la capacité du nœud |
| [5](incident-5-imagepullbackoff/) | ImagePullBackOff | Tag d'image inexistant sur ECR |

Les incidents 1, 2, 4 et 5 ont été reproduits directement sur le
déploiement réel `myapp` (modification temporaire du chart ou des valeurs
Helm, observation du symptôme réel, correction, retour à l'état
initial vérifié — `git diff` ne montre plus aucune trace après coup).
L'incident 3 utilise un ServiceAccount et un pod de debug dédiés
(`incident-3-rbac/`), pour tester un vrai scénario RBAC sans jamais
perturber l'application en fonctionnement.
