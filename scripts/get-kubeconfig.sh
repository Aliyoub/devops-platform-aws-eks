#!/usr/bin/env bash
# Écrit le kubeconfig du cluster EKS dans un fichier dédié à ce projet,
# plutôt que dans ~/.kube/config par défaut, pour ne jamais interférer avec
# une configuration Kubernetes existante sur la machine (ex. un cluster k3s
# local utilisé pour autre chose).
set -euo pipefail

CLUSTER_NAME="${1:-devops-platform-aws-eks-dev}"
REGION="${2:-us-east-1}"
KUBECONFIG_PATH="${KUBECONFIG_OUTPUT:-$HOME/.kube/devops-platform-aws-eks.yaml}"

aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --kubeconfig "$KUBECONFIG_PATH"

echo ""
echo "Kubeconfig écrit dans : $KUBECONFIG_PATH"
echo "Utilisation : KUBECONFIG=$KUBECONFIG_PATH kubectl get nodes"
