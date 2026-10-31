#!/usr/bin/env bash
# ==============================================================================
# Helper Script: Full End-to-End Orchestration (Cluster + Add-ons)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo " Starting Full End-to-End Lab 2 Provisioning Pipeline"
echo "=========================================================="

"$SCRIPT_DIR/provision-aws-ec2.sh"
"$SCRIPT_DIR/setup-kubespray.sh"
"$SCRIPT_DIR/deploy-cluster.sh"
"$SCRIPT_DIR/deploy-addons.sh"
"$SCRIPT_DIR/verify-cluster.sh"

echo "=========================================================="
echo " All Lab 2 Components Deployed and Verified Successfully!"
echo "=========================================================="
