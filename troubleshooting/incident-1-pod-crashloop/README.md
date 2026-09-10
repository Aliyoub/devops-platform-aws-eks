# Incident 1 — Pod ne démarre pas (CrashLoopBackOff)

Reproduit réellement le 2026-09-10 sur le déploiement `myapp` du cluster
`devops-platform-aws-eks-dev` — pas simulé.

## 1. Symptôme

Après un déploiement, les pods `myapp` redémarrent en boucle au lieu de se
stabiliser :

```
NAME                    READY   STATUS    RESTARTS      AGE
myapp-64f967df9-8cfk4   0/1     Running   3 (19s ago)   109s
myapp-64f967df9-knzs7   1/1     Running   4 (1s ago)    2m1s
```

## 2. Diagnostic

```
kubectl get pods -l app.kubernetes.io/name=myapp
kubectl describe pod <pod>
kubectl logs <pod>
```

`kubectl describe pod` (extrait des Events) montre la vraie cause :

```
Normal   Killing    24s (x3 over 84s)   kubelet   spec.containers{myapp}: Container myapp failed liveness probe, will be restarted
Warning  Unhealthy  4s (x11 over 104s)  kubelet   spec.containers{myapp}: Liveness probe failed: HTTP probe failed with statuscode: 404
```

`kubectl logs` montre que l'application elle-même démarre sans erreur :

```
▲ Next.js 16.3.4
- Local:         http://localhost:3000
- Network:       http://0.0.0.0:3000
✓ Ready in 0ms
✓ Running next.config took 1.7ms
```

→ L'application tourne, mais la probe interroge un chemin qui répond `404`.
Le problème n'est pas le code applicatif, c'est la configuration du pod.

## 3. Commandes utilisées

- `kubectl get pods -l app.kubernetes.io/name=myapp` — repérer le
  `CrashLoopBackOff`/redémarrages.
- `kubectl describe pod <pod>` — lire les Events (`Unhealthy`, `Killing`)
  pour identifier laquelle des probes échoue et pourquoi.
- `kubectl logs <pod>` — confirmer si l'application elle-même a un problème
  ou si elle tourne normalement (ici : elle tourne bien).

## 4. Cause

Le `livenessProbe` du Deployment pointait vers `/wrong-health`, un chemin
qui n'existe pas dans l'application (les vraies routes sont `/health` et
`/ready`). Kubernetes considérait donc le conteneur comme en échec et le
redémarrait en boucle, alors que l'application fonctionnait normalement.

## 5. Correction

Remettre le bon chemin dans `helm/myapp/templates/deployment.yaml` :

```yaml
livenessProbe:
  httpGet:
    path: /health   # au lieu de /wrong-health
    port: http
```

Puis redéployer :

```
helm upgrade myapp helm/myapp -f helm/myapp/values-dev.yaml \
  --set image.repository=<url_ecr> --set image.tag=<sha> --wait
```

## 6. Vérification

```
NAME                    READY   STATUS    RESTARTS   AGE
myapp-648776bd7-8s2dt   1/1     Running   0          15s
myapp-648776bd7-p5wh8   1/1     Running   0          26s
```

`0` redémarrage, `1/1 Running` sur les deux pods.

## 7. Lessons learned

- Un `CrashLoopBackOff` ne signifie pas forcément un bug applicatif :
  toujours vérifier `kubectl logs` avant de suspecter le code — ici les
  logs étaient parfaitement sains.
- Les Events de `kubectl describe pod` donnent la cause exacte
  (`Unhealthy`, code HTTP retourné) sans avoir à deviner.
- Les chemins de probes devraient être testés (`curl` en local, comme fait
  en Phase 1) avant d'être écrits dans le chart, pas découverts en
  production.
