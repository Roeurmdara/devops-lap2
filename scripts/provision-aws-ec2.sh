#!/usr/bin/env bash
# ==============================================================================
# Helper Script: Provision Ubuntu 22.04 EC2 Instances on AWS for Kubernetes (Lab 2)
# Architecture: 1 Master Node (Control Plane), 2 Worker Nodes by default
# Domain: dara.lifestyle
# ==============================================================================
set -e
export AWS_PAGER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Configurable parameters (Environment variables or defaults)
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-2}}"
AWS_ADMIN_CIDR="${AWS_ADMIN_CIDR:-}"
INSTANCE_TYPE="${AWS_INSTANCE_TYPE:-t3.medium}" # 2 vCPU, 4GB RAM minimum for k8s
DISK_SIZE="${AWS_DISK_SIZE:-50}"
TARGET_USER="${TARGET_USER:-ubuntu}"
WORKER_COUNT="${AWS_WORKER_COUNT:-2}"
KEY_NAME="${AWS_KEY_NAME:-keyServer}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/keyServer.pem}"
SSH_PUB_KEY="${SSH_KEY_PATH}.pub"
SG_NAME="k8s-cluster-sg"

echo "=========================================================="
echo " ☁️  AWS EC2 Kubernetes Cluster Provisioner (Lab 2)"
echo " Region : $AWS_REGION | Type: $INSTANCE_TYPE | Disk: ${DISK_SIZE}GB"
echo " Master : 1 node  | Workers: $WORKER_COUNT nodes | User: $TARGET_USER"
echo " Domain : dara.lifestyle"
echo "=========================================================="

if [ -z "$AWS_ADMIN_CIDR" ]; then
  echo "Error: Set AWS_ADMIN_CIDR to the trusted admin network (for example, 203.0.113.10/32)."
  exit 1
fi

if [[ ! "$WORKER_COUNT" =~ ^[1-3]$ ]]; then
  echo "Error: AWS_WORKER_COUNT must be 1, 2, or 3."
  exit 1
fi

# 1. Check AWS CLI and Credentials
which aws >/dev/null || { echo "Error: AWS CLI is not installed."; exit 1; }
aws sts get-caller-identity --region "$AWS_REGION" >/dev/null 2>&1 || {
  echo ""
  echo "❌ Error: AWS credentials not configured or session expired."
  echo "Please export your credentials or configure AWS CLI:"
  echo "  export AWS_ACCESS_KEY_ID='YOUR_ACCESS_KEY'"
  echo "  export AWS_SECRET_ACCESS_KEY='YOUR_SECRET_KEY'"
  echo "  export AWS_DEFAULT_REGION='$AWS_REGION'"
  echo "or run:"
  echo "  aws configure"
  exit 1
}

CALLER_ARN=$(aws sts get-caller-identity --region "$AWS_REGION" --query "Arn" --output text)
echo "Authenticated as: $CALLER_ARN"

# 2. SSH Key Management
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "[1/6] Generating local SSH key pair at $SSH_KEY_PATH..."
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "dara-ansible-aws"
fi

echo "[2/6] Ensuring AWS EC2 Key Pair ($KEY_NAME) exists..."
if ! aws ec2 describe-key-pairs --region "$AWS_REGION" --key-names "$KEY_NAME" >/dev/null 2>&1; then
  echo "  Importing public key to AWS EC2 Key Pair: $KEY_NAME..."
  aws ec2 import-key-pair \
    --region "$AWS_REGION" \
    --key-name "$KEY_NAME" \
    --public-key-material "fileb://$SSH_PUB_KEY"
else
  echo "  Key Pair $KEY_NAME already exists in $AWS_REGION."
fi

# 3. Discover Default VPC
echo "[3/6] Discovering Default VPC and Subnet..."
VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
  VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --query "Vpcs[0].VpcId" --output text)
fi
echo "  Using VPC: $VPC_ID"

# 4. Security Group Configuration
echo "[4/6] Ensuring Security Group ($SG_NAME) exists..."
SG_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
  echo "  Creating Security Group: $SG_NAME..."
  SG_ID=$(aws ec2 create-security-group \
    --region "$AWS_REGION" \
    --group-name "$SG_NAME" \
    --description "Kubernetes Cluster Security Group for Lab 2 (dara.lifestyle)" \
    --vpc-id "$VPC_ID" \
    --output text --query "GroupId")

  echo "  Authorizing ingress traffic rules for $SG_ID..."
  # Allow all internal traffic within the Security Group
  aws ec2 authorize-security-group-ingress \
    --region "$AWS_REGION" \
    --group-id "$SG_ID" \
    --protocol -1 \
    --source-group "$SG_ID"

  # Allow external SSH, HTTP, HTTPS, K8s API, NodePort
  aws ec2 authorize-security-group-ingress \
    --region "$AWS_REGION" \
    --group-id "$SG_ID" \
    --ip-permissions \
      IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges="[{CidrIp=$AWS_ADMIN_CIDR,Description=SSH}]" \
      IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="HTTP"}]' \
      IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="HTTPS"}]' \
      IpProtocol=tcp,FromPort=6443,ToPort=6443,IpRanges="[{CidrIp=$AWS_ADMIN_CIDR,Description=K8sAPI}]"
else
  echo "  Security Group $SG_NAME ($SG_ID) already exists."
fi

# 5. Find Latest Ubuntu 22.04 LTS AMI
echo "[5/6] Locating official Ubuntu 22.04 LTS AMI in $AWS_REGION..."
AMI_ID=$(aws ec2 describe-images \
  --region "$AWS_REGION" \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=state,Values=available" \
  --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" \
  --output text)
echo "  Found AMI: $AMI_ID"

# 6. Launch EC2 Instances (1 Master and the configured number of workers)
NODES=("k8s-master-01")
for ((worker_number = 1; worker_number <= WORKER_COUNT; worker_number++)); do
  printf -v worker_name 'k8s-worker-%02d' "$worker_number"
  NODES+=("$worker_name")
done
echo "[6/6] Checking & Launching EC2 instances..."

for NODE in "${NODES[@]}"; do
  EXISTING_ID=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$NODE" "Name=instance-state-name,Values=pending,running" \
    --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null || true)

  if [ "$EXISTING_ID" != "None" ] && [ -n "$EXISTING_ID" ]; then
    echo "  Node $NODE already active (ID: $EXISTING_ID). Skipping launch."
  else
    echo "  Launching $NODE ($INSTANCE_TYPE, $DISK_SIZE GB gp3)..."
    INSTANCE_ID=$(aws ec2 run-instances \
      --region "$AWS_REGION" \
      --image-id "$AMI_ID" \
      --count 1 \
      --instance-type "$INSTANCE_TYPE" \
      --key-name "$KEY_NAME" \
      --security-group-ids "$SG_ID" \
      --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$DISK_SIZE,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NODE},{Key=Role,Value=kubernetes},{Key=Project,Value=dara.lifestyle}]" \
      --query "Instances[0].InstanceId" \
      --output text)
    echo "  Launched $NODE (ID: $INSTANCE_ID)"
  fi
done

echo "Waiting for instances to reach 'running' state..."
NODE_NAMES=$(IFS=,; printf '%s' "${NODES[*]}")
aws ec2 wait instance-running \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=$NODE_NAMES" \
  --output text 2>/dev/null || sleep 15

# Retrieve IPs
get_ips() {
  local name="$1"
  aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$name" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress]" \
    --output text
}

read -r MASTER_EXT_IP MASTER_INT_IP <<< "$(get_ips k8s-master-01)"
if [[ -z "$MASTER_EXT_IP" || -z "$MASTER_INT_IP" ]]; then
  echo "Error: Could not retrieve both IP addresses for k8s-master-01."
  exit 1
fi

WORKER_EXT_IPS=()
WORKER_INT_IPS=()
echo "----------------------------------------------------------"
echo "  k8s-master-01 : Ext: $MASTER_EXT_IP | Int: $MASTER_INT_IP"
for ((worker_number = 1; worker_number <= WORKER_COUNT; worker_number++)); do
  printf -v worker_name 'k8s-worker-%02d' "$worker_number"
  read -r worker_ext_ip worker_int_ip <<< "$(get_ips "$worker_name")"
  if [[ -z "$worker_ext_ip" || -z "$worker_int_ip" ]]; then
    echo "Error: Could not retrieve both IP addresses for $worker_name."
    exit 1
  fi
  WORKER_EXT_IPS+=("$worker_ext_ip")
  WORKER_INT_IPS+=("$worker_int_ip")
  echo "  $worker_name : Ext: $worker_ext_ip | Int: $worker_int_ip"
done
echo "----------------------------------------------------------"

# Write Kubespray Inventory
INVENTORY_FILE="$BASE_DIR/inventory/mycluster/inventory.ini"
echo "Writing Kubespray inventory: $INVENTORY_FILE..."

cat <<EOF > "$INVENTORY_FILE"
# ==============================================================================
# Kubespray Inventory for AWS Kubernetes Cluster (Lab 2)
# Automatically generated by provision-aws-ec2.sh on $(date -u)
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
EOF

for ((worker_index = 0; worker_index < WORKER_COUNT; worker_index++)); do
  printf 'k8s-worker-%02d ansible_host=%s ip=%s\n' \
    "$((worker_index + 1))" \
    "${WORKER_EXT_IPS[$worker_index]}" \
    "${WORKER_INT_IPS[$worker_index]}" >> "$INVENTORY_FILE"
done

cat <<EOF >> "$INVENTORY_FILE"
[k8s_cluster:children]
kube_control_plane
kube_node
EOF


# Update master IP in group_vars/k8s_cluster/k8s-cluster.yml for SANs
K8S_VARS="$BASE_DIR/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml"
if [ -f "$K8S_VARS" ] && [ -n "$MASTER_EXT_IP" ]; then
  sed -i "s/- \"master.dara.lifestyle\"/- \"master.dara.lifestyle\"\n  - \"${MASTER_EXT_IP}\"/g" "$K8S_VARS" 2>/dev/null || true
fi

echo "=========================================================="
echo " ✅ AWS EC2 Provisioning Complete!"
echo " Next Steps:"
echo " 1. Test SSH connectivity:"
echo "    ansible -i $INVENTORY_FILE all -m ping"
echo " 2. Point DNS records for dara.lifestyle to Worker IPs:"
echo "    headlamp.dara.lifestyle -> ${WORKER_EXT_IPS[0]}"
echo "    argocd.dara.lifestyle   -> ${WORKER_EXT_IPS[0]}"
echo "    react.dara.lifestyle    -> ${WORKER_EXT_IPS[0]}"
echo " 3. Run Kubernetes and Add-ons Deployment:"
echo "    ./scripts/deploy-all.sh"
echo "=========================================================="
