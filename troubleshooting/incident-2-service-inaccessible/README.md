# Incident 2 — Service inaccessible (mauvais selector)

Reproduit réellement le 2026-09-10 sur le déploiement `myapp` — pas simulé.

## 1. Symptôme

Les pods sont `Running` et sains, mais l'application n'est plus accessible
du tout via l'ALB public :

```
$ curl -o /dev/null -w "HTTP: %{http_code}\n" http://<alb>/health
HTTP: 503
```

## 2. Diagnostic

```
kubectl get endpoints myapp
kubectl describe svc myapp
kubectl get pods -l app.kubernetes.io/instance=myapp --show-labels
```

`kubectl get endpoints` montre que le Service n'a **aucune** cible :

```
NAME    ENDPOINTS   AGE
myapp   <none>      78m
```

`kubectl describe svc myapp` révèle pourquoi — le sélecteur du Service ne
correspond à aucun pod réel :

```
Selector:  app.kubernetes.io/instance=myapp,app.kubernetes.io/name=wrong-app-name
```

alors que les pods portent bien `app.kubernetes.io/name=myapp` (vérifié via
`--show-labels`). Le `503` vient de l'AWS Load Balancer Controller lui-même :
sans endpoints, son target group est vide, donc rien à qui envoyer le
trafic.

## 3. Commandes utilisées

- `kubectl get endpoints myapp` — premier réflexe pour un Service qui ne
  route plus rien : y a-t-il seulement des cibles ?
- `kubectl describe svc myapp` — comparer le `Selector` affiché aux labels
  réels des pods.
- `kubectl get pods --show-labels` — vérifier les labels réels.

## 4. Cause

Le `selector` du Service (`helm/myapp/templates/service.yaml`) référençait
`app.kubernetes.io/name: wrong-app-name` au lieu du label réellement posé
sur les pods (`myapp`, via le helper `myapp.selectorLabels`).

## 5. Correction

Revenir au sélecteur généré par le helper partagé plutôt qu'un sélecteur
codé en dur, pour qu'il reste toujours cohérent avec les labels du
Deployment :

```yaml
selector:
  {{- include "myapp.selectorLabels" . | nindent 4 }}
```

Puis redéployer (`helm upgrade ... --wait`).

## 6. Vérification

```
$ kubectl get endpoints myapp
NAME    ENDPOINTS                          AGE
myapp   10.20.2.119:3000,10.20.2.56:3000   78m

$ curl -o /dev/null -w "HTTP: %{http_code}\n" http://<alb>/health
HTTP: 200
```

## 7. Lessons learned

- Un `503` depuis l'ALB ne veut pas dire que l'application a un problème —
  toujours vérifier `kubectl get pods` (sains) puis `kubectl get endpoints`
  (vides) avant de suspecter le code.
- Coder un sélecteur à la main au lieu de réutiliser le helper partagé
  (`_helpers.tpl`) est exactement le genre d'erreur que ce projet évite
  structurellement — ce sélecteur cassé a dû être écrit à la main pour ce
  test, le chart normal ne permet pas cette incohérence.
- `kubectl get endpoints` (ou `kubectl get endpointslices` sur les
  versions récentes) est le point de contrôle le plus rapide pour
  distinguer "le pod a un problème" de "le Service ne route pas vers le
  pod".
