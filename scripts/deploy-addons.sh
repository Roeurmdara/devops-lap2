#!/usr/bin/env bash
# ==============================================================================
# Helper Script: Deploy Cluster Add-ons & Workloads via Ansible
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY="$BASE_DIR/inventory/mycluster/inventory.ini"

if [[ -z "${ARGOCD_ADMIN_PASSWORD:-}" ]]; then
	echo "Error: Set ARGOCD_ADMIN_PASSWORD in the environment before deploying add-ons." >&2
	exit 1
fi

echo "=========================================================="
echo " Deploying Add-ons (Traefik, Cert-Manager, Headlamp, ArgoCD, React App)"
echo " Inventory: $INVENTORY"
echo "=========================================================="

ansible-playbook -i "$INVENTORY" "$BASE_DIR/playbooks/02-addons.yml"

echo ""
echo "=========================================================="
echo " Deployment Finished!"
echo " Verification: Run ./scripts/verify-cluster.sh"
echo "=========================================================="
