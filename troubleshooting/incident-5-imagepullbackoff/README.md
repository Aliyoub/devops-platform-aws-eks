# Incident 5 — ImagePullBackOff (tag d'image inexistant)

Reproduit réellement le 2026-09-10 sur le déploiement `myapp` — pas simulé.

## 1. Symptôme

Après un déploiement, le nouveau pod ne démarre jamais et affiche
successivement `ErrImagePull` puis `ImagePullBackOff` :

```
NAME                     READY   STATUS         RESTARTS   AGE
myapp-5d467f95d4-r6r8l   0/1     ErrImagePull   0          63s
myapp-648776bd7-8s2dt    1/1     Running        0          9m55s
myapp-648776bd7-p5wh8    1/1     Running        0          10m
```

(Les anciens pods restent `Running` — même mécanisme qu'à l'incident 4 :
`maxUnavailable: 0` empêche de les arrêter tant que le remplaçant n'est
pas opérationnel.)

## 2. Diagnostic

```
kubectl describe pod <pod>
```

```
Normal   Pulling    28s (x3 over 68s)  kubelet  spec.containers{myapp}: Pulling image "...devops-platform-aws-eks-dev:does-not-exist"
Warning  Failed     28s (x3 over 68s)  kubelet  spec.containers{myapp}: Failed to pull image "...does-not-exist": rpc error: code = NotFound ... not found
Warning  Failed     28s (x3 over 68s)  kubelet  spec.containers{myapp}: Error: ErrImagePull
Normal   BackOff    3s (x4 over 67s)   kubelet  spec.containers{myapp}: Back-off pulling image "...does-not-exist"
Warning  Failed     3s (x4 over 67s)   kubelet  spec.containers{myapp}: Error: ImagePullBackOff
```

Le message est sans ambiguïté : le registre ECR répond `NotFound` pour ce
tag précis. `ErrImagePull` est la première tentative ; `ImagePullBackOff`
apparaît une fois que le kubelet espace ses tentatives suivantes.

## 3. Commandes utilisées

- `kubectl get pods` — repérer le statut `ErrImagePull`/`ImagePullBackOff`.
- `kubectl describe pod <pod>` — lire le message d'erreur exact renvoyé par
  le registre (ici, `not found`) plutôt que de deviner entre un problème
  de tag, de permissions ECR, ou de réseau.

## 4. Cause

Le tag d'image déployé (`does-not-exist`) n'a jamais été poussé sur le
repository ECR — contrairement au fonctionnement normal de ce projet, où
le tag correspond toujours à un SHA de commit réellement construit et
poussé (Phase 4, `docker push`).

## 5. Correction

Redéployer avec un tag d'image qui existe réellement dans ECR :

```
helm upgrade myapp helm/myapp -f helm/myapp/values-dev.yaml \
  --set image.repository=<url_ecr> --set image.tag=<sha_reel> --wait
```

## 6. Vérification

```
NAME                    READY   STATUS    RESTARTS   AGE
myapp-648776bd7-8s2dt   1/1     Running   0          10m
myapp-648776bd7-p5wh8   1/1     Running   0          10m
```

Et bout en bout, l'application reste joignable via l'ALB :

```
$ curl -o /dev/null -w "HTTP: %{http_code}\n" http://<alb>/health
HTTP: 200
```

## 7. Lessons learned

- Le message d'erreur de `kubectl describe pod` distingue clairement un
  tag inexistant (`not found`) d'un problème de permissions ECR (qui
  renverrait plutôt `unauthorized`/`403`) — lire le message exact évite de
  chercher du mauvais côté.
- C'est précisément pour éviter ce type d'incident en production que le
  repository ECR de ce projet est en `IMMUTABLE` (Phase 4) et que le tag
  déployé est toujours le SHA exact du commit construit par la CI/CD
  (Phase 7) — jamais un tag saisi à la main.
- Le même mécanisme de rolling update (`maxUnavailable: 0`) qui a ralenti
  la bascule à l'incident 4 protège aussi ici : un tag cassé ne fait
  jamais tomber le service, les anciens pods sains continuent de répondre
  pendant que le nouveau échoue.
