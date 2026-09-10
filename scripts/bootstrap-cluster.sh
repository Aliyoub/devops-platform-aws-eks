#!/usr/bin/env bash
# Installe les composants de plateforme sur un cluster EKS fraîchement créé
# par Terraform : AWS Load Balancer Controller, kube-prometheus-stack.
# Volontairement séparé du pipeline CD (cd.yml) - la CD ne déploie que
# l'application, jamais les composants partagés du cluster (voir
# helm/README.md et monitoring/README.md).
#
# Usage : ./scripts/bootstrap-cluster.sh
# Prérequis : terraform apply déjà exécuté, kubeconfig déjà configuré
# (./scripts/get-kubeconfig.sh).
set -euo pipefail

cd "$(dirname "$0")/.."

CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name)
VPC_ID=$(terraform -chdir=terraform output -raw vpc_id)
ALB_CONTROLLER_ROLE_ARN=$(terraform -chdir=terraform output -raw alb_controller_role_arn)
REGION="us-east-1"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/devops-platform-aws-eks.yaml}"

helm repo add eks https://aws.github.io/eks-charts > /dev/null
helm repo update > /dev/null

KUBECONFIG="$KUBECONFIG_PATH" helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --version 3.5.0 \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_CONTROLLER_ROLE_ARN"

echo ""
echo "En attente que le contrôleur soit pret..."
KUBECONFIG="$KUBECONFIG_PATH" kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s

echo ""
echo "Contrôleur ALB installé et pret."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
helm repo update > /dev/null

KUBECONFIG="$KUBECONFIG_PATH" kubectl create namespace monitoring \
  --dry-run=client -o yaml | KUBECONFIG="$KUBECONFIG_PATH" kubectl apply -f - > /dev/null

KUBECONFIG="$KUBECONFIG_PATH" helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --version 90.0.0 \
  -n monitoring \
  -f monitoring/values.yaml \
  --wait --timeout 5m

echo ""
echo "kube-prometheus-stack installé et pret."

./scripts/apply-dashboards.sh

echo ""
echo "Mot de passe admin Grafana :"
KUBECONFIG="$KUBECONFIG_PATH" kubectl get secret --namespace monitoring \
  -l app.kubernetes.io/component=admin-secret \
  -o jsonpath="{.items[0].data.admin-password}" | base64 --decode
echo ""
echo "Accès : kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
