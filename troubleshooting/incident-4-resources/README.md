# Incident 4 — Ressources (requests trop élevées, scheduling impossible)

Reproduit réellement le 2026-09-10 sur le déploiement `myapp` — pas simulé.

## 1. Symptôme

Après un déploiement, un pod reste bloqué `Pending` indéfiniment :

```
NAME                    READY   STATUS    RESTARTS   AGE
myapp-5975868d7-nlmd9   0/1     Pending   0          41s
myapp-648776bd7-8s2dt   1/1     Running   0          7m32s
myapp-648776bd7-p5wh8   1/1     Running   0          7m43s
```

(Les anciens pods restent `Running` : la stratégie de rolling update
`maxUnavailable: 0` empêche de les arrêter tant que le remplaçant n'est
pas prêt — ce qui, ici, ne se produira jamais.)

## 2. Diagnostic

```
kubectl describe pod <pod-pending>
kubectl describe node
```

`kubectl describe pod` (Events) donne la cause exacte sans ambiguïté :

```
Warning  FailedScheduling  48s  default-scheduler  0/1 nodes are
available: 1 Insufficient cpu. no new claims to deallocate,
preemption: 0/1 nodes are available: 1 Preemption is not helpful for
scheduling.
```

`kubectl describe node` (Allocated resources) confirme que le nœud est
déjà largement occupé par le reste de la plateforme (app existante,
contrôleur ALB, monitoring, `metrics-server`...) :

```
Resource   Requests      Limits
--------   --------      ------
cpu        1025m (53%)   1700m (88%)
memory     1340Mi (40%)  2868Mi (87%)
```

Sur un nœud `t3.medium` (2 vCPU), une requête de `10` cœurs ne peut
matériellement pas être satisfaite.

## 3. Commandes utilisées

- `kubectl get pods` — repérer le pod bloqué en `Pending`.
- `kubectl describe pod <pod>` — lire l'Event `FailedScheduling`, qui
  nomme la ressource en cause (`cpu`).
- `kubectl describe node` — comparer la demande à la capacité réellement
  disponible sur le nœud.

## 4. Cause

Le `resources.requests.cpu` du Deployment avait été fixé à `10` (10 cœurs
CPU), très au-delà de la capacité du nœud unique du cluster (2 vCPU au
total, déjà partagés avec le reste de la plateforme).

Point technique rencontré au passage : Kubernetes refuse à l'admission une
requête strictement supérieure à la limite (`spec.resources.requests` >
`spec.resources.limits`) — la première tentative avec seulement
`requests.cpu=10` a été rejetée immédiatement par l'API, avant même
d'atteindre le scheduler. Il a fallu élever aussi `limits.cpu` à `10` pour
obtenir le scénario "Pending" réellement visé (une requête cohérente mais
irréaliste), plutôt qu'un rejet à l'admission.

## 5. Correction

Revenir à des valeurs de `resources.requests`/`resources.limits`
réalistes (celles de `helm/myapp/values-dev.yaml`) :

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi
```

```
helm upgrade myapp helm/myapp -f helm/myapp/values-dev.yaml \
  --set image.repository=<url_ecr> --set image.tag=<sha> --wait
```

## 6. Vérification

```
NAME                    READY   STATUS    RESTARTS   AGE
myapp-648776bd7-8s2dt   1/1     Running   0          8m18s
myapp-648776bd7-p5wh8   1/1     Running   0          8m29s
```

Les deux pods `Running`, plus aucun `Pending`.

## 7. Lessons learned

- `FailedScheduling` avec "Insufficient cpu/memory" pointe directement
  vers `resources.requests`, pas vers l'image ni le code — un diagnostic
  rapide évite de chercher du mauvais côté.
- Le cluster low-cost de ce projet (1 seul nœud `t3.medium`) rend ce type
  d'incident plus probable qu'avec plusieurs nœuds — un rappel concret du
  compromis coût/résilience déjà documenté dans le README principal.
- Avant d'activer un autoscaling de nœuds (Cluster Autoscaler/Karpenter,
  amélioration future listée dans le projet), il faut d'abord des
  `requests` réalistes : sur-dimensionner les requests rendrait
  l'autoscaling de nœuds nécessaire pour compenser une mauvaise
  configuration, plutôt que pour absorber une vraie charge.
