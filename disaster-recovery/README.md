# Disaster Recovery

## Pourquoi pas un snapshot/restore etcd classique

Le brief initial de ce projet demandait une démonstration de disaster
recovery façon snapshot/restore etcd. Sur EKS, **le control plane et etcd
sont entièrement gérés par AWS** : aucun accès client, pas de nœud master à
qui se connecter pour un `etcdctl snapshot save`. Prétendre démontrer cette
procédure sur ce cluster serait une simulation, pas une compétence
réellement exercée dans ce contexte.

Deux stratégies adaptées, toutes deux réellement testées :

1. **DR infrastructure** : la preuve que tout est recréable de zéro via
   `terraform apply` + `helm install`/`bootstrap-cluster.sh` — déjà
   démontré de fait plusieurs fois au cours de ce projet (l'infrastructure
   est détruite et recréée entre chaque session de travail depuis la
   Phase 3). Sur un Kubernetes managé, l'Infrastructure as Code **est** la
   vraie stratégie de DR pour l'infrastructure elle-même.
2. **DR application** (cette page) : sauvegarde et restauration des
   ressources Kubernetes avec **Velero**, plus un test de résilience nœud.

La procédure etcd/kubeadm classique reste démontrée dans un autre
repository, `kubernetes-etcd-disaster-recovery`, sur un contexte où elle
est techniquement applicable.

## Ce qui est sauvegardé, et ce qui ne l'est pas

Velero sauvegarde les **objets de l'API Kubernetes** (Deployment, Service,
Ingress, ConfigMap, ServiceAccount, HPA, PodDisruptionBudget,
NetworkPolicy...) du namespace `default` vers un bucket S3 dédié
(`terraform/velero.tf`).

**Aucun `VolumeSnapshotLocation` n'est configuré** : ce projet n'a aucun
`PersistentVolume` (Prometheus et Grafana tournent en stockage éphémère,
voir `monitoring/README.md`) — il n'y a donc rien à sauvegarder côté
volumes. Les permissions IAM EC2 (snapshots EBS) recommandées par la
documentation officielle du plugin AWS de Velero sont volontairement
omises pour cette raison (moindre privilège : ne pas accorder une
permission qui ne sert à rien aujourd'hui).

## Pourquoi Velero plutôt qu'un simple `kubectl apply -f` sauvegardé

Un dossier de manifests YAML versionnés (ce que fait déjà ce repository
via Helm/Git) couvre la configuration *déclarée*. Velero capture en plus
l'état *réellement observé* du cluster à un instant T — utile pour un
retour arrière après une suppression accidentelle, y compris de ressources
qui ne sont pas gérées par Helm.

## Test réel effectué le 2026-09-10

### 1. Backup

```
kubectl apply -f disaster-recovery/backup.yaml
kubectl get backup myapp-backup -n velero
```

```
Phase:  Completed
Progress:
  Items Backed Up:  128
  Total Items:      128
```

Vérifié indépendamment (pas seulement le statut renvoyé par Velero) :

```
$ aws s3 ls s3://devops-platform-aws-eks-dev-velero-backups/backups/myapp-backup/
2026-09-10 11:27:58     124949 myapp-backup.tar.gz
2026-09-10 11:27:58       3815 velero-backup.json
...
```

### 2. Désastre simulé

```
$ helm uninstall myapp
release "myapp" uninstalled
$ kubectl get deploy,svc,ingress,hpa,pdb,sa,cm -l app.kubernetes.io/instance=myapp
No resources found in default namespace.
$ curl http://<ancien-alb>/health
(connexion impossible)
```

Application complètement supprimée et injoignable — un vrai désastre, pas
un état intermédiaire.

### 3. Restore

```
kubectl apply -f disaster-recovery/restore.yaml
kubectl get restore myapp-restore -n velero
```

Résultat réel : `Phase: PartiallyFailed`, 41/41 items traités, **1 erreur**.
Plutôt que de la passer sous silence, voici ce qu'elle était et pourquoi
elle n'a eu aucune conséquence :

```
error restoring k8s-default-myapp-111286c304: admission webhook
"vtargetgroupbinding.elbv2.k8s.aws" denied the request: ...
TargetGroupNotFound: One or more target groups not found
```

Le seul objet en échec est un `TargetGroupBinding` — une ressource générée
**automatiquement par le contrôleur ALB**, pas une ressource source de
vérité. Il référençait un target group AWS qui avait déjà été supprimé
avec l'ancien ALB. Sans conséquence : dès que l'Ingress restauré a été
reconcilié par le contrôleur, celui-ci a recréé un nouvel ALB et un nouveau
`TargetGroupBinding` cohérent tout seul.

### 4. Vérification

Tout restauré et fonctionnel :

```
$ kubectl get deploy,svc,ingress,hpa,pdb,sa,cm -l app.kubernetes.io/instance=myapp
deployment.apps/myapp   2/2     2            2           43s
service/myapp           ClusterIP   ...
ingress.networking.k8s.io/myapp   alb   ...   k8s-default-myapp-...-1337143768...
horizontalpodautoscaler.autoscaling/myapp   cpu: 5%/70%   2   4   2
poddisruptionbudget.policy/myapp   1   N/A   1
serviceaccount/myapp
configmap/myapp-config

$ curl http://<nouvel-alb>/ready
{"status":"ready","environment":"dev"}
```

Un nouvel ALB a été provisionné, avec un nom DNS différent de l'original
— attendu : l'ALB lui-même n'est pas un objet Kubernetes, il est recréé
par le contrôleur en réaction à l'Ingress restauré, pas "ressuscité" à
l'identique.

**Découverte réelle, positive** : `helm list` montrait toujours la release
`myapp` comme `deployed` après la restauration, et un `helm upgrade`
normal a fonctionné sans aucune intervention manuelle (revision 12 → 13).
Explication : le backup Velero couvrait tout le namespace `default`, ce
qui a incidemment inclus le Secret de suivi interne de Helm — sa
restauration a donc gardé l'état Helm cohérent avec les objets restaurés,
sans divergence à réconcilier à la main.

## Test de résilience nœud

Avec un seul nœud (profil low-cost, Phase 5), un reschedule vers un
"autre" nœud ne peut pas être démontré. Un second nœud `t3.medium` a été
ajouté **temporairement** (`aws eks update-nodegroup-config`, hors
Terraform, remis à `desiredSize=1` juste après — coût de quelques minutes
d'un nœud, ~0,04 $, signalé et confirmé avant exécution) pour un test réel.

`kubectl drain` plutôt qu'un `kill` brutal de l'instance EC2 : les deux
options sont valables (le brief mentionne "drain/kill"), le drain reste
une vraie perte de nœud du point de vue des pods qui doivent migrer, sans
attendre les ~5 minutes du délai de détection `NotReady` par défaut d'un
arrêt brutal.

### Avant

```
NAME                    NODE
myapp-648776bd7-8s2dt   ip-10-20-2-51.ec2.internal
myapp-648776bd7-p5wh8   ip-10-20-2-51.ec2.internal
```

Les deux replicas sur le même (unique) nœud d'origine.

### Drain réel

```
kubectl drain ip-10-20-2-51.ec2.internal --ignore-daemonsets --delete-emptydir-data
```

Résultat particulièrement intéressant : le `PodDisruptionBudget`
(`minAvailable: 1`, Phase 6) a **réellement bloqué** l'éviction du dernier
pod `myapp` jusqu'à ce que son remplaçant soit prêt sur l'autre nœud :

```
evicting pod default/myapp-648776bd7-p5wh8
pod/myapp-648776bd7-p5wh8 evicted
...
evicting pod default/myapp-648776bd7-8s2dt
error when evicting pods/"myapp-648776bd7-8s2dt" -n "default" (will retry
after 5s): Cannot evict pod as it would violate the pod's disruption budget.
[répété plusieurs fois, jusqu'à ce que le remplaçant soit Ready]
pod/myapp-648776bd7-8s2dt evicted
node/ip-10-20-2-51.ec2.internal drained
```

### Après

```
NAME                    NODE
myapp-648776bd7-x4dgw   ip-10-20-1-226.ec2.internal
myapp-648776bd7-x8ckw   ip-10-20-1-226.ec2.internal
```

Les deux pods ont bien migré vers le second nœud.

### Disponibilité pendant l'opération (mesurée, pas supposée)

Un test HTTP toutes les ~3 secondes contre l'ALB pendant tout le drain :

```
11:41:19  HTTP 200
11:41:23  HTTP 502    <- creux réel pendant la bascule
11:41:26  HTTP 200
11:41:29  HTTP 200
11:41:35  HTTP 000    <- creux réel pendant la bascule
11:41:41  HTTP 000
11:41:45  HTTP 200    <- rétabli
11:41:48  HTTP 200
...toujours 200 jusqu'à la fin du test...
```

Honnêtement : **pas de zéro-downtime parfait**, environ 18 secondes de
creux (le temps que l'ALB déprovisionne l'ancienne cible et enregistre la
nouvelle), pas une coupure prolongée. Avec 2 replicas et un seul nœud de
départ, les deux pods partageaient le même point de défaillance — une vraie
haute disponibilité demanderait au minimum 2 nœuds en permanence
(anti-affinité de pods en plus), ce que ce projet n'a pas retenu pour
rester low-cost (voir README principal, section coûts).

### Nettoyage

```
kubectl uncordon ip-10-20-2-51.ec2.internal
aws eks update-nodegroup-config --cluster-name devops-platform-aws-eks-dev \
  --nodegroup-name devops-platform-aws-eks-dev-nodes \
  --scaling-config minSize=1,maxSize=1,desiredSize=1
```

Revérifié après coup : `terraform plan` renvoie `No changes` (le
`desired_size=1` de `terraform/variables.tf` reste la source de vérité,
aucune dérive laissée par ce test manuel).

## Lessons learned

- Un restore Velero peut se terminer `PartiallyFailed` sans que ce soit
  réellement grave : il faut lire l'erreur exacte plutôt que de réagir au
  seul statut. Ici, l'échec touchait une ressource dérivée que le
  contrôleur concerné régénère de toute façon.
- Sauvegarder un namespace entier avec Velero restaure aussi, sans le
  demander explicitement, les objets internes d'autres outils (ici, l'état
  Helm) — un effet de bord positif dans ce cas, mais bon à savoir avant de
  scoper un backup plus finement dans un contexte multi-équipes.
- L'ALB n'est jamais "restauré" au sens propre : c'est une ressource AWS
  externe recréée par un contrôleur, pas un objet dont l'état persiste
  dans etcd/le backup.
