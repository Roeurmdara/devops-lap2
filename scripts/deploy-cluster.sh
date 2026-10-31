#!/usr/bin/env bash
# ==============================================================================
# Helper Script: Deploy Kubernetes Cluster via Kubespray
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY="$BASE_DIR/inventory/mycluster/inventory.ini"
KUBESPRAY_DIR="$BASE_DIR/kubespray"

echo "=========================================================="
echo " Starting Automated Kubernetes Cluster Deployment"
echo " Inventory: $INVENTORY"
echo "=========================================================="

if [ ! -d "$KUBESPRAY_DIR" ]; then
  echo "Setting up Kubespray..."
  "$SCRIPT_DIR/setup-kubespray.sh"
fi

echo "[1/4] Testing SSH connectivity across all nodes..."
ansible -i "$INVENTORY" all -m ping

echo "[2/4] Preparing Ubuntu 22.04 node prerequisites..."
ansible-playbook -i "$INVENTORY" "$BASE_DIR/playbooks/01-cluster.yml"

echo "[3/4] Executing Kubespray cluster playbook..."
ansible-playbook -i "$INVENTORY" "$KUBESPRAY_DIR/cluster.yml" -b -v

echo "[4/4] Retrieving and configuring admin kubeconfig..."
ansible-playbook -i "$INVENTORY" "$BASE_DIR/playbooks/03-fetch-kubeconfig.yml"

echo "=========================================================="
echo " Kubernetes Cluster Provisioned Successfully!"
echo " Next: Deploy Add-ons (Traefik, Headlamp, ArgoCD, React App)"
echo "   ./scripts/deploy-addons.sh"
echo "=========================================================="
