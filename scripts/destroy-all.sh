#!/usr/bin/env bash
# ==============================================================================
# Teardown Script: Delete Kubernetes Workloads and Purge Cloud VMs (AWS / GCP)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY="$BASE_DIR/inventory/mycluster/inventory.ini"
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}"
ZONE="${GCP_ZONE:-asia-southeast1-a}"

echo "=========================================================="
echo " ⚠️  CAUTION: Kubernetes Teardown & Cloud Purge Script"
echo "=========================================================="

if [ "$1" != "--force" ] && [ "$2" != "--force" ]; then
  read -p "Are you sure you want to delete the Kubernetes cluster and all cloud VMs? (y/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# 1. Run Ansible teardown
if [ -f "$INVENTORY" ]; then
  echo "[1/3] Tearing down Kubernetes add-ons & resources via Ansible..."
  ansible-playbook -i "$INVENTORY" "$BASE_DIR/destroy.yml" || true
fi

# 2. Terminate AWS EC2 Instances if configured
if which aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
  echo "[2/3] Terminating AWS EC2 instances..."
  INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=k8s-master-01,k8s-worker-01,k8s-worker-02,k8s-worker-03" "Name=instance-state-name,Values=pending,running,stopped" \
    --query "Reservations[].Instances[].InstanceId" --output text)

  if [ -n "$INSTANCE_IDS" ] && [ "$INSTANCE_IDS" != "None" ]; then
    echo "  Terminating EC2 instances: $INSTANCE_IDS..."
    aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids $INSTANCE_IDS
    echo "  Waiting for instance termination..."
    aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids $INSTANCE_IDS || sleep 10
  else
    echo "  No active AWS instances found."
  fi

  echo "  Deleting Security Group k8s-cluster-sg..."
  aws ec2 delete-security-group --region "$AWS_REGION" --group-name "k8s-cluster-sg" 2>/dev/null || true
fi

# 3. Delete GCP Virtual Machines if gcloud configured
if which gcloud >/dev/null 2>&1 && gcloud config get-value project >/dev/null 2>&1; then
  VMS=("k8s-master-01" "k8s-worker-01" "k8s-worker-02" "k8s-worker-03")
  echo "[2b/3] Deleting GCP Virtual Machines..."
  for VM in "${VMS[@]}"; do
    if gcloud compute instances describe "$VM" --zone="$ZONE" --quiet >/dev/null 2>&1; then
      echo "  Deleting $VM..."
      gcloud compute instances delete "$VM" --zone="$ZONE" --quiet
    fi
  done
  gcloud compute firewall-rules delete allow-k8s-traffic --quiet >/dev/null 2>&1 || true
  gcloud compute firewall-rules delete allow-k8s-internal --quiet >/dev/null 2>&1 || true
fi

echo "=========================================================="
echo " Teardown & Purge Complete!"
echo "=========================================================="
