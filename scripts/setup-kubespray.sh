#!/usr/bin/env bash
# ==============================================================================
# Helper Script: Setup Kubespray Environment and Dependencies (Lab 2)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
KUBESPRAY_DIR="$BASE_DIR/kubespray"
KUBESPRAY_REPO="https://github.com/kubernetes-sigs/kubespray.git"
KUBESPRAY_VERSION="v2.25.0"

echo "=========================================================="
echo " Kubespray Setup & Local Machine Preparation"
echo "=========================================================="

# 1. Check Python and Pip
echo "[1/4] Checking Python3 and Pip..."
which python3 >/dev/null || { echo "Python3 is not installed. Please install python3."; exit 1; }

# 2. Check if Kubespray already exists in repo or clone it
echo "[2/4] Ensuring Kubespray is available..."
if [ -d "$KUBESPRAY_DIR" ]; then
  echo "  Kubespray directory already present at $KUBESPRAY_DIR"
else
  # Check if shortcourse repo has 6.Kubespray
  if [ -d "$BASE_DIR/../scratch/repo/6.Kubespray" ]; then
    echo "  Linking Kubespray from course repository..."
    ln -s "$BASE_DIR/../scratch/repo/6.Kubespray" "$KUBESPRAY_DIR"
  else
    echo "  Cloning Kubespray ($KUBESPRAY_VERSION) from $KUBESPRAY_REPO..."
    git clone --branch "$KUBESPRAY_VERSION" --depth 1 "$KUBESPRAY_REPO" "$KUBESPRAY_DIR"
  fi
fi

# 3. Install Python Dependencies
echo "[3/4] Installing / Verifying Python dependencies..."
python3 -m pip install --break-system-packages --user --upgrade \
  -r "$KUBESPRAY_DIR/requirements.txt"

# 4. Link Inventory to Kubespray
echo "[4/4] Linking mycluster inventory to Kubespray..."
mkdir -p "$KUBESPRAY_DIR/inventory"
if [ ! -e "$KUBESPRAY_DIR/inventory/mycluster" ]; then
  ln -s "$BASE_DIR/inventory/mycluster" "$KUBESPRAY_DIR/inventory/mycluster"
fi

echo "=========================================================="
echo " Kubespray environment is ready!"
echo " Cluster deployment command:"
echo "   ./scripts/deploy-cluster.sh"
echo "=========================================================="
