# devops-lap2

Production-ready Infrastructure-as-Code (IaC) repository for provisioning a multi-node Kubernetes cluster on Amazon Web Services (AWS) EC2 Ubuntu 22.04 LTS instances using **Kubespray**, **Ansible**, **Traefik Ingress Controller**, **cert-manager**, **Headlamp Dashboard**, **ArgoCD**, and an **End-to-End React.js GitOps Pipeline** mapped to `dara.lifestyle`.

---

## 🏛️ Infrastructure & Cluster Architecture

- **Control Machine**: Local workstation or management EC2 instance executing Ansible playbooks and Kubespray automation over SSH.
- **1 Control Plane (Master Node)**: Handles Kubernetes API (`kube-apiserver`), `etcd`, `kube-scheduler`, and `kube-controller-manager` (`t3.medium` / `t3.large`).
- **2 Worker Nodes by default**: Run user workloads, pods, Traefik ingress controller, and applications (`t3.medium`). Set `AWS_WORKER_COUNT=3` only when the account has enough vCPU quota.
- **Automated Deployment**: Managed end-to-end with minimal manual intervention.

### Cluster Topology & Service Mapping

| Machine Role | Hostname | Machine Type | Service / Component | Domain / Endpoint | Ingress & TLS |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Control Plane** | `k8s-master-01` | `t3.medium` | K8s API, etcd, scheduler, coredns | `https://<MASTER_IP>:6443` | Internal mTLS / SANs |
| **Worker Node 01** | `k8s-worker-01` | `t3.medium` | Traefik Ingress, Headlamp, Pods | `https://headlamp.dara.lifestyle` | Traefik + Let's Encrypt |
| **Worker Node 02** | `k8s-worker-02` | `t3.medium` | Traefik Ingress, ArgoCD, React.js App, Pods | `https://argocd.dara.lifestyle` | Traefik + Let's Encrypt |

---

## 📂 Repository Structure

```text
lap2/
├── ansible.cfg                          # Global Ansible configuration
├── inventory/
│   └── mycluster/
│       ├── inventory.ini                # Kubespray host & group inventory
│       └── group_vars/
│           ├── all/
│           │   └── all.yml              # Domains, passwords, cert settings
│           └── k8s_cluster/
│               ├── addons.yml           # Helm & metrics-server enable, NGINX disabled
│               └── k8s-cluster.yml      # Containerd runtime, Calico CNI, Kubeconfig fetch
├── playbooks/
│   ├── 01-cluster.yml                   # Ubuntu 22.04 kernel & networking setup
│   ├── 02-addons.yml                    # Traefik, cert-manager, Headlamp, ArgoCD, React
│   ├── 03-fetch-kubeconfig.yml          # Fetches admin.conf to local artifacts and ~/.kube/config
│   └── 99-destroy.yml                   # Teardown of add-ons and workloads
├── react-app/                           # React.js application source & CI/CD pipeline
│   ├── Dockerfile                       # Multi-stage production container build
│   ├── nginx.conf                       # Production SPA web server configuration
│   ├── Jenkinsfile                      # Declarative Jenkins CI/CD pipeline
│   ├── .github/workflows/ci-cd.yaml     # GitHub Actions automated build & GitOps sync
│   ├── src/                             # React application source code & components
│   └── k8s/                             # Local copy of Kubernetes manifests
├── roles/
│   ├── traefik/                         # Helm deployment for Traefik Ingress Controller
│   ├── cert_manager/                    # Jetstack cert-manager & Let's Encrypt ClusterIssuer
│   ├── headlamp/                        # Headlamp Dashboard & RBAC admin token
│   ├── argocd/                          # ArgoCD + IngressRoute + ServersTransport + Password reset
│   └── react_app/                       # React.js manifests + ArgoCD Application CRD
├── manifests/                            # Standalone manifests for direct kubectl apply
│   ├── traefik/traefik-values.yaml
│   ├── cert-manager/prod-clusterissuer.yaml
│   ├── headlamp/{headlamp-ingress.yaml, headlamp-rbac.yaml}
│   ├── argocd/{argocd-ingress-route.yaml, argocd-server-transport.yaml, patch-insecure.yaml}
│   └── react-app/{deployment.yaml, service.yaml, ingress.yaml, argocd-application.yaml}
├── scripts/
│   ├── provision-aws-ec2.sh             # Provisions 4 AWS EC2 instances, SG & key pair
│   ├── update-inventory.sh              # Refreshes inventory from live AWS EC2 or manual IPs
│   ├── setup-kubespray.sh               # Local machine Kubespray & Python dependency setup
│   ├── deploy-cluster.sh                # Deploys Kubernetes via Kubespray
│   ├── deploy-addons.sh                 # Executes 02-addons.yml Ansible playbook
│   ├── deploy-all.sh                    # Full end-to-end automation runner
│   ├── verify-cluster.sh                # CLI validation for nodes, pods, DNS, TLS
│   └── destroy-all.sh                   # AWS EC2 & Security Group cleanup
├── site.yml                             # Top-level Ansible orchestrator playbook
├── destroy.yml                          # Top-level Ansible teardown playbook
└── README.md                            # Complete documentation & guide
```

---

## 🚀 Step-by-Step Deployment Instructions

### Step 1: Provision AWS EC2 Virtual Machines & Security Groups

Configure an AWS CLI profile (AWS IAM Identity Center/SSO is preferred), then set the trusted admin CIDR. The four EC2 instances and disks incur ongoing charges while running:

```bash
aws configure sso --profile lab2
aws sso login --profile lab2
export AWS_PROFILE="lab2"
export AWS_DEFAULT_REGION="ap-southeast-2" # or us-east-1, etc.
export AWS_ADMIN_CIDR="YOUR_PUBLIC_IP/32"
```

`AWS_ADMIN_CIDR` is required. Use the public IP/CIDR allowed to administer SSH and the Kubernetes API; do not use `0.0.0.0/0`.

Execute the AWS provisioning script to create or reuse one master and two Ubuntu 22.04 LTS worker instances by default, and configure the `k8s-cluster-sg` security group. The controller is separate from these three nodes:

```bash
cd ~/lap2
./scripts/provision-aws-ec2.sh
```

The provisioner writes `inventory/mycluster/inventory.ini` for the nodes it manages.

Test SSH connectivity across all nodes:
```bash
ansible -i inventory/mycluster/inventory.ini all -m ping
```

---

### Step 2: Configure Public DNS Records

Point each DNS `A` record for `dara.lifestyle` at both workers' public IPs (traffic lands on Traefik hostPort `80`/`443`). The current addresses can be queried from AWS; they may change if the instances are stopped and restarted:

| Host / Subdomain | Target IP Address |
| :--- | :--- |
| `headlamp.dara.lifestyle` | Public IP of `k8s-worker-01` and `k8s-worker-02` |
| `argocd.dara.lifestyle` | Public IP of `k8s-worker-01` and `k8s-worker-02` |
| `react.dara.lifestyle` | Public IP of `k8s-worker-01` and `k8s-worker-02` |

---

### Step 3: Setup Kubespray Environment

Initialize the Kubespray environment and required Python dependencies (already prepared):

```bash
./scripts/setup-kubespray.sh
```

---

### Step 4: Deploy the Kubernetes Cluster

Deploy Kubernetes with Containerd and Calico:

```bash
./scripts/deploy-cluster.sh
```

*Note: Kubespray automatically copies `admin.conf` to `lap2/artifacts/admin.conf` and injects the master's public IP.*

---

### Step 5: Deploy Add-ons, Ingress & Workloads

Run the Ansible add-ons playbook to deploy Traefik, cert-manager, Headlamp, ArgoCD, and the React.js GitOps app:

```bash
./scripts/deploy-addons.sh
```

Or run everything end-to-end in a single command. This first reuses a running EC2 instance tagged `Name=k8s-master-01`, creates any missing cluster nodes, refreshes the inventory, then runs Kubespray, add-ons, and verification. Set `AWS_PROFILE`, `AWS_DEFAULT_REGION`, and `AWS_ADMIN_CIDR` as described in Step 1 first:

```bash
./scripts/deploy-all.sh
```

---

## ⚙️ Add-ons & Ingress Details

### 1. Traefik Ingress Controller
- Configured to bind directly to host VM ports via `hostPort: 80` (HTTP) and `hostPort: 443` (HTTPS).
- Automatically redirects all incoming HTTP traffic on port 80 to port 443 HTTPS.
- Standard NGINX ingress is disabled to avoid port contention.

### 2. cert-manager & Let's Encrypt
- Deploys cert-manager with CRDs enabled.
- Configures `ClusterIssuer` named `letsencrypt-prod` solving ACME HTTP-01 challenges via Traefik.

### 3. Headlamp Dashboard
- Mapped to domain: `https://headlamp.dara.lifestyle`.
- Automatically provisions `headlamp-admin` ServiceAccount and `cluster-admin` RBAC binding.
- Generated login token is exported to `lap2/artifacts/headlamp-token.txt`.

### 4. ArgoCD Deployment & Custom Admin Password
- Mapped to domain: `https://argocd.dara.lifestyle`.
- Deploys Traefik `ServersTransport` with `insecureSkipVerify: true` to prevent backend IP SAN certificate mismatch errors.
- Patches `argocd-cmd-params-cm` with `server.insecure: "true"`.
- Automates bcrypt password hashing and injects the new password directly into `argocd-secret`.
- Credentials saved to `lap2/artifacts/argocd-credentials.txt`:
  - **Username**: `admin`
  - **Password**: generated during deployment and saved in the owner-only `artifacts/argocd-credentials.txt` file.

### 5. React.js GitOps Pipeline
- Deploys React application manifests (`Deployment`, `Service`, `Ingress`) in the `production` namespace.
- Ingress configured with `cert-manager.io/cluster-issuer: letsencrypt-prod` for `https://react.dara.lifestyle`.
- Deploys an ArgoCD `Application` resource (`react-app-gitops`) with automated sync, self-healing, and pruning enabled.

---

## 🔍 CLI Verification & Health Checks

Run the automated cluster validation script:

```bash
./scripts/verify-cluster.sh
```

### Manual Validation Commands

```bash
# Set KUBECONFIG to the local artifact or run from master
export KUBECONFIG=~/lap2/artifacts/admin.conf

# 1. Check all nodes status (Ready)
kubectl get nodes -o wide

# 2. Check all cluster pods
kubectl get pods -A

# 3. Check Traefik Ingress Controller pods and host ports
kubectl get pods -n traefik -o wide

# 4. Check cert-manager and issued TLS certificates
kubectl get clusterissuer
kubectl get certificate -A

# 5. Check Ingresses and IngressRoutes
kubectl get ingress,ingressroute -A

# 6. Verify ArgoCD application sync status
kubectl get application -n argocd

# 7. Test endpoint HTTPS reachability
curl -vkI https://headlamp.dara.lifestyle
curl -vkI https://argocd.dara.lifestyle
curl -vkI https://react.dara.lifestyle
```

---

## 🧹 Infrastructure Teardown & Purge

To uninstall all add-ons and workloads while preserving the cluster:
```bash
ansible-playbook -i inventory/mycluster/inventory.ini destroy.yml
```

To completely delete the Kubernetes cluster and purge all AWS EC2 / GCP instances and firewall rules:
```bash
./scripts/destroy-all.sh
```
