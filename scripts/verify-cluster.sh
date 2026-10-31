#!/usr/bin/env bash
# ==============================================================================
# CLI Verification Script for Kubernetes Cluster & Add-ons (Lab 2)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY="$BASE_DIR/inventory/mycluster/inventory.ini"
KUBECONFIG_PATH="${KUBECONFIG:-$BASE_DIR/artifacts/admin.conf}"

echo "=========================================================="
echo " ☸️ Kubernetes Cluster & Services Health Verification"
echo "=========================================================="

# Check if kubeconfig is available locally or execute via master node SSH
USE_LOCAL_KUBECTL=false
if [ -f "$KUBECONFIG_PATH" ] && which kubectl >/dev/null 2>&1; then
  export KUBECONFIG="$KUBECONFIG_PATH"
  USE_LOCAL_KUBECTL=true
  echo "Using local kubectl with kubeconfig: $KUBECONFIG"
else
  echo "Local kubectl not found or admin.conf not local. Running via master node over SSH..."
fi

run_k8s_cmd() {
  if [ "$USE_LOCAL_KUBECTL" = true ]; then
    kubectl "$@"
  else
    ansible -i "$INVENTORY" kube_control_plane[0] -m command -a "kubectl $*" -o | sed 's/.*>>//g'
  fi
}

echo ""
echo "[1/6] Validating Kubernetes Node Status..."
echo "----------------------------------------------------------"
run_k8s_cmd get nodes -o wide

echo ""
echo "[2/6] Validating System & Add-on Pods..."
echo "----------------------------------------------------------"
run_k8s_cmd get pods -A

echo ""
echo "[3/6] Validating Traefik Ingress Controller Status..."
echo "----------------------------------------------------------"
run_k8s_cmd get pods -n traefik -o wide
run_k8s_cmd get svc -n traefik

echo ""
echo "[4/6] Validating TLS Certificates & ClusterIssuer..."
echo "----------------------------------------------------------"
run_k8s_cmd get clusterissuer
run_k8s_cmd get certificate -A
run_k8s_cmd get ingress,ingressroute -A

echo ""
echo "[5/6] Checking DNS Accessibility for Cluster Domains..."
echo "----------------------------------------------------------"
python3 - << 'EOF'
import urllib.request, json, sys

domains = [
    "headlamp.dara.lifestyle",
    "argocd.dara.lifestyle",
    "react.dara.lifestyle"
]

print(f"{'DOMAIN':<30} | {'RESOLVED IP(S)':<30} | STATUS")
print("-" * 75)

for domain in domains:
    url = f"https://dns.google/resolve?name={domain}&type=A"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode())
            ips = [a["data"] for a in data.get("Answer", []) if a.get("type") == 1]
            if ips:
                print(f"{domain:<30} | {', '.join(ips):<30} | OK")
            else:
                print(f"{domain:<30} | {'NO RECORD FOUND':<30} | PENDING DNS")
    except Exception as e:
        print(f"{domain:<30} | ERROR: {str(e):<23} | FAILED")
EOF

echo ""
echo "[6/6] Probing HTTP & HTTPS Endpoints..."
echo "----------------------------------------------------------"
ENDPOINTS=(
  "https://headlamp.dara.lifestyle"
  "https://argocd.dara.lifestyle"
  "https://react.dara.lifestyle"
)

for URL in "${ENDPOINTS[@]}"; do
  echo -n "Probing $URL : "
  HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$URL" || echo "TIMEOUT/ERR")
  echo "HTTP Status Code: $HTTP_CODE"
done

echo ""
echo "=========================================================="
echo " Service Access Information:"
echo "----------------------------------------------------------"
if [ -f "$BASE_DIR/artifacts/headlamp-token.txt" ]; then
  echo "Headlamp URL   : https://headlamp.dara.lifestyle"
  echo "Headlamp token saved securely to: $BASE_DIR/artifacts/headlamp-token.txt"
fi

if [ -f "$BASE_DIR/artifacts/argocd-credentials.txt" ]; then
  echo ""
  echo "ArgoCD URL     : https://argocd.dara.lifestyle"
  echo "ArgoCD credentials saved securely to: $BASE_DIR/artifacts/argocd-credentials.txt"
fi

echo ""
echo "React App URL  : https://react.dara.lifestyle"
echo "=========================================================="
