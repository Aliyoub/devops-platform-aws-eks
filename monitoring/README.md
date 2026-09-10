# Observabilité

## Pourquoi kube-prometheus-stack

Installer Prometheus, Grafana, l'operator et les exporters séparément à la
main aurait pris plus de temps pour un résultat équivalent au chart
`kube-prometheus-stack` (standard de facto de l'écosystème, maintenu par la
communauté Prometheus). La valeur ajoutée réelle de ce projet n'est pas
d'avoir su lancer `helm install`, mais le dashboard personnalisé construit
par-dessus (`dashboards/myapp-overview.json`).

## Choix effectués

- **Alertmanager désactivé** : aucune destination réelle configurée
  (Slack/PagerDuty/e-mail) dans ce projet — l'installer sans jamais rien y
  envoyer consommerait des ressources sur l'unique nœud sans rien
  démontrer de réel.
- **`kubeEtcd`, `kubeControllerManager`, `kubeScheduler` désactivés** : sur
  EKS, ces composants du control plane sont managés par AWS et ne sont pas
  exposés au client — les `ServiceMonitor` par défaut du chart pour ces
  cibles échoueraient systématiquement (aucun endpoint à scraper).
- **Pas de stockage persistant** (ni pour Prometheus, ni pour Grafana) :
  l'infrastructure de ce projet est détruite entre les sessions de travail
  ; provisionner un volume EBS demanderait d'installer l'add-on EBS CSI
  driver pour un bénéfice nul ici, puisque rien n'a besoin de survivre à
  la destruction du cluster. Rétention Prometheus réduite à 6h en
  conséquence.
- **Grafana exposé uniquement via `kubectl port-forward`**, pas via
  l'Ingress/ALB : un deuxième ALB pour un usage interne (nous-mêmes)
  coûterait sans bénéfice réel pour ce projet.
- **Mot de passe admin Grafana généré aléatoirement par Helm**, jamais fixé
  dans un fichier commité — récupéré à la demande via `kubectl`.
- **Un vrai bug rencontré** : la première tentative a échoué, le conteneur
  Grafana partant en `OOMKilled` en boucle avec une limite mémoire de
  128 Mi. Constaté via `kubectl describe pod` (pas anticipé), corrigé en
  passant la limite à 384 Mi puis revérifié par un `helm upgrade` réel.

## Dashboard personnalisé (`dashboards/myapp-overview.json`)

6 panneaux, tous vérifiés avec de vraies requêtes PromQL retournant des
données réelles (pas seulement un import qui "a l'air" de marcher) :

- Pods disponibles vs voulus (`kube_deployment_status_replicas_available`
  / `kube_deployment_spec_replicas`)
- Pods `Running` (`kube_pod_status_phase`)
- CPU par pod de l'application (`container_cpu_usage_seconds_total`)
- Mémoire par pod de l'application (`container_memory_working_set_bytes`)
- CPU du nœud (`node_cpu_seconds_total`)
- Mémoire disponible du nœud (`node_memory_MemAvailable_bytes`)

Appliqué via un ConfigMap labellisé `grafana_dashboard: "1"`
(`scripts/apply-dashboards.sh`), découvert automatiquement par le sidecar
Grafana (`grafana.sidecar.dashboards`, voir `values.yaml`) — aucune
étape manuelle dans l'UI Grafana, reproductible à chaque recréation du
cluster.

## Accès

```
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# puis ouvrir http://localhost:3000

kubectl get secret --namespace monitoring \
  -l app.kubernetes.io/component=admin-secret \
  -o jsonpath="{.items[0].data.admin-password}" | base64 --decode
# utilisateur : admin
```
