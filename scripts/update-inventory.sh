#!/usr/bin/env bash
# ==============================================================================
# Helper Script: Refresh Kubespray Inventory (AWS / GCP / Manual)
# Usage:
#   1. Automatic via AWS: ./update-inventory.sh aws [REGION]
#   2. Automatic via GCP: ./update-inventory.sh gcp [ZONE]
#   3. Manual via IPs:    ./update-inventory.sh <MASTER_EXT> <WORKER1_EXT> <WORKER2_EXT> <WORKER3_EXT>
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY_FILE="$BASE_DIR/inventory/mycluster/inventory.ini"
TARGET_USER="${TARGET_USER:-ubuntu}"
if [ -z "$SSH_KEY_PATH" ]; then
  if [ -f "$HOME/.ssh/keyServer.pem" ]; then
    SSH_KEY_PATH="$HOME/.ssh/keyServer.pem"
  elif [ -f "$BASE_DIR/keyServer.pem" ]; then
    SSH_KEY_PATH="$BASE_DIR/keyServer.pem"
  elif [ -f "$HOME/.ssh/id_rsa" ]; then
    SSH_KEY_PATH="$HOME/.ssh/id_rsa"
  else
    SSH_KEY_PATH="$HOME/.ssh/keyServer.pem"
  fi
fi

if [ "$1" == "aws" ] || ([ "$#" -eq 0 ] && which aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1); then
  AWS_REGION="${2:-${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}}"
  echo "Fetching node IPs from AWS EC2 in region $AWS_REGION..."

  get_aws_ips() {
    local name="$1"
    aws ec2 describe-instances \
      --region "$AWS_REGION" \
      --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=running" \
      --query "Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]" \
      --output text
  }

  read -r MASTER_EXT_IP MASTER_INT_IP <<< "$(get_aws_ips k8s-master-01)"
  read -r WORKER1_EXT_IP WORKER1_INT_IP <<< "$(get_aws_ips k8s-worker-01)"
  read -r WORKER2_EXT_IP WORKER2_INT_IP <<< "$(get_aws_ips k8s-worker-02)"
  read -r WORKER3_EXT_IP WORKER3_INT_IP <<< "$(get_aws_ips k8s-worker-03)"

elif [ "$1" == "gcp" ]; then
  ZONE="${2:-${GCP_ZONE:-asia-southeast1-a}}"
  TARGET_USER="dara"
  echo "Fetching IPs from GCP (Zone: $ZONE)..."

  MASTER_EXT_IP=$(gcloud compute instances describe k8s-master-01 --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
  MASTER_INT_IP=$(gcloud compute instances describe k8s-master-01 --zone="$ZONE" --format='get(networkInterfaces[0].networkIP)')

  WORKER1_EXT_IP=$(gcloud compute instances describe k8s-worker-01 --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
  WORKER1_INT_IP=$(gcloud compute instances describe k8s-worker-01 --zone="$ZONE" --format='get(networkInterfaces[0].networkIP)')

  WORKER2_EXT_IP=$(gcloud compute instances describe k8s-worker-02 --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
  WORKER2_INT_IP=$(gcloud compute instances describe k8s-worker-02 --zone="$ZONE" --format='get(networkInterfaces[0].networkIP)')

  WORKER3_EXT_IP=$(gcloud compute instances describe k8s-worker-03 --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
  WORKER3_INT_IP=$(gcloud compute instances describe k8s-worker-03 --zone="$ZONE" --format='get(networkInterfaces[0].networkIP)')

elif [ "$#" -ge 4 ]; then
  MASTER_EXT_IP="$1"
  MASTER_INT_IP="${5:-$1}"
  WORKER1_EXT_IP="$2"
  WORKER1_INT_IP="${6:-$2}"
  WORKER2_EXT_IP="$3"
  WORKER2_INT_IP="${7:-$3}"
  WORKER3_EXT_IP="$4"
  WORKER3_INT_IP="${8:-$4}"
  echo "Using manually supplied IP addresses:"
else
  echo "Usage:"
  echo "  $0 aws [REGION]                                                 # Auto-discover AWS EC2 IPs"
  echo "  $0 gcp [ZONE]                                                   # Auto-discover GCP VM IPs"
  echo "  $0 <MASTER_EXT> <WORKER1_EXT> <WORKER2_EXT> <WORKER3_EXT>       # Manual IPs"
  exit 1
fi

echo "  k8s-master-01 : Ext: $MASTER_EXT_IP | Int: $MASTER_INT_IP"
echo "  k8s-worker-01 : Ext: $WORKER1_EXT_IP | Int: $WORKER1_INT_IP"
echo "  k8s-worker-02 : Ext: $WORKER2_EXT_IP | Int: $WORKER2_INT_IP"
echo "  k8s-worker-03 : Ext: $WORKER3_EXT_IP | Int: $WORKER3_INT_IP"

cat <<EOF > "$INVENTORY_FILE"
# ==============================================================================
# Kubespray Inventory for Kubernetes Cluster (Lab 2)
# Refreshed by update-inventory.sh on $(date -u)
# ==============================================================================

[all:vars]
ansible_user=${TARGET_USER}
ansible_ssh_private_key_file=${SSH_KEY_PATH}
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[kube_control_plane]
k8s-master-01 ansible_host=${MASTER_EXT_IP} ip=${MASTER_INT_IP}

[etcd]
k8s-master-01 ansible_host=${MASTER_EXT_IP} ip=${MASTER_INT_IP}

[kube_node]
k8s-worker-01 ansible_host=${WORKER1_EXT_IP} ip=${WORKER1_INT_IP}
k8s-worker-02 ansible_host=${WORKER2_EXT_IP} ip=${WORKER2_INT_IP}
k8s-worker-03 ansible_host=${WORKER3_EXT_IP} ip=${WORKER3_INT_IP}

[k8s_cluster:children]
kube_control_plane
kube_node
EOF

echo "Inventory written to: $INVENTORY_FILE"

# Update master IP in group_vars/k8s_cluster/k8s-cluster.yml for SANs
K8S_VARS="$BASE_DIR/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml"
if [ -f "$K8S_VARS" ] && [ -n "$MASTER_EXT_IP" ]; then
  grep -q "$MASTER_EXT_IP" "$K8S_VARS" || sed -i "s/- \"master.dara.lifestyle\"/- \"master.dara.lifestyle\"\n  - \"${MASTER_EXT_IP}\"/g" "$K8S_VARS" 2>/dev/null || true
fi
