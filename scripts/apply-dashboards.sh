#!/usr/bin/env bash
# Empaquette chaque dashboard JSON de monitoring/dashboards/ dans un
# ConfigMap labellisé, découvert automatiquement par le sidecar Grafana
# (grafana.sidecar.dashboards, voir monitoring/values.yaml).
set -euo pipefail

cd "$(dirname "$0")/.."
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/devops-platform-aws-eks.yaml}"

for dashboard in monitoring/dashboards/*.json; do
  name=$(basename "$dashboard" .json)
  KUBECONFIG="$KUBECONFIG_PATH" kubectl create configmap "dashboard-$name" \
    --from-file="$dashboard" \
    -n monitoring \
    --dry-run=client -o yaml \
    | KUBECONFIG="$KUBECONFIG_PATH" kubectl label --local -f - grafana_dashboard=1 -o yaml --dry-run=client \
    | KUBECONFIG="$KUBECONFIG_PATH" kubectl apply -f -
  echo "Dashboard applique : $name"
done
