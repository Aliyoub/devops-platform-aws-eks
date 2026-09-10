# Incident 3 — RBAC : ServiceAccount sans les permissions nécessaires

Reproduit réellement le 2026-09-10, sur un ServiceAccount et un pod de
debug dédiés (`serviceaccount.yaml`, `pod.yaml`) — pas simulé, et sans
toucher au déploiement `myapp` en fonctionnement.

## 1. Symptôme

Un pod de debug (`debug-tools`), qui doit pouvoir lister les pods du
namespace pour un usage d'exploitation courant, échoue dès qu'il essaie :

```
$ kubectl exec debug-tools -- kubectl get pods -n default
Error from server (Forbidden): pods is forbidden: User
"system:serviceaccount:default:debug-tools" cannot list resource "pods"
in API group "" in the namespace "default"
command terminated with exit code 1
```

## 2. Diagnostic

```
kubectl auth can-i list pods --as=system:serviceaccount:default:debug-tools -n default
```

```
no
```

`kubectl auth can-i` confirme immédiatement, sans avoir besoin de relancer
la commande depuis le pod, que ce ServiceAccount n'a aucune permission sur
les pods dans ce namespace.

## 3. Commandes utilisées

- `kubectl auth can-i <verbe> <ressource> --as=<serviceaccount> -n <namespace>`
  — LE réflexe de diagnostic RBAC : simuler l'autorisation sans avoir à
  reproduire l'appel réel.
- `kubectl exec <pod> -- kubectl get pods` — confirmer avec le token réel
  du pod, pas seulement une simulation.

## 4. Cause

Le ServiceAccount `debug-tools` avait été créé sans aucun Role ni
RoleBinding associé — par défaut, un ServiceAccount Kubernetes n'a
strictement aucune permission sur l'API.

## 5. Correction

Créer un Role scopé au strict nécessaire (lire les pods du namespace
`default`, rien d'autre) et le lier au ServiceAccount — pas de
`ClusterRole`, pas de `cluster-admin`, pas d'accès aux `secrets` :

```yaml
# role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: debug-tools-pod-reader
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: debug-tools-pod-reader
  namespace: default
subjects:
  - kind: ServiceAccount
    name: debug-tools
    namespace: default
roleRef:
  kind: Role
  name: debug-tools-pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```
kubectl apply -f troubleshooting/incident-3-rbac/role.yaml
```

## 6. Vérification

```
$ kubectl auth can-i list pods --as=system:serviceaccount:default:debug-tools -n default
yes

$ kubectl exec debug-tools -- kubectl get pods -n default
NAME                    READY   STATUS    RESTARTS   AGE
debug-tools             1/1     Running   0          29s
myapp-648776bd7-8s2dt   1/1     Running   0          4m51s
myapp-648776bd7-p5wh8   1/1     Running   0          5m2s
```

Et surtout, vérification que la correction reste bien scopée au strict
nécessaire — l'accès aux secrets, jamais demandé, reste refusé :

```
$ kubectl auth can-i list secrets --as=system:serviceaccount:default:debug-tools -n default
no
```

## 7. Lessons learned

- `kubectl auth can-i` doit être le premier réflexe face à une erreur
  `Forbidden` — il évite d'avoir à re-simuler l'appel qui échoue.
- Corriger un problème RBAC "au plus simple" (donner `cluster-admin`)
  aurait aussi fait disparaître l'erreur, mais silencieusement ouvert un
  accès bien plus large que nécessaire. La correction ici a été vérifiée
  comme étant toujours refusée sur une ressource non demandée (`secrets`)
  — la preuve que le principe de moindre privilège a été respecté, pas
  seulement affirmé.
- Ce pod de debug devait aussi respecter Pod Security Admission
  `restricted` (Phase 9) comme n'importe quelle autre charge de travail du
  namespace `default` — pas d'exception pour un outil "juste pour tester".
