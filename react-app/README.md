# ⚛️ React.js Web Application & GitOps CI/CD Pipeline

Production-ready frontend application for `dara.lifestyle`, packaged with a multi-stage Docker build, Nginx web server, Traefik Ingress routing with Let's Encrypt TLS, and automated ArgoCD GitOps continuous deployment.

---

## 🏗️ Architecture & Pipeline Flow

```text
[ Developer Push ]
       │ (git push origin main)
       ▼
[ GitHub Actions / Jenkins ]
  ├─ 1. Lint & Test (npm test)
  ├─ 2. Build Assets (npm run build)
  ├─ 3. Multi-stage Docker Build (Node.js -> Nginx)
  ├─ 4. Push Image to Registry (ghcr.io / Docker Hub)
  └─ 5. Update image tag in GitOps repository manifests
       │
       ▼
[ ArgoCD GitOps Engine ]
  ├─ Polls repository (or receives webhook)
  ├─ Detects diff between Git and Kubernetes cluster
  └─ Automated Sync & Canary/Rolling Update on Cluster
       │
       ▼
[ Traefik Ingress Controller ]
  └─ Routes https://react.dara.lifestyle to Pods with SSL/TLS
```

---

## 🛠️ Local Development

### 1. Run with Node.js & Vite
```bash
npm install
npm run dev
```
Open `http://localhost:3000` in your browser.

### 2. Build and Run with Docker
```bash
# Build multi-stage image
docker build -t dara-lifestyle-react:latest .

# Run container locally
docker run -d -p 8080:80 --name react-app dara-lifestyle-react:latest

# Open http://localhost:8080
```

---

## ☸️ Kubernetes Manifests

All Kubernetes resources are located in `./k8s/`:
- `deployment.yaml`: Replicas, health probes (`/healthz`), resource limits
- `service.yaml`: ClusterIP service exposing port 80
- `ingress.yaml`: Ingress with `cert-manager.io/cluster-issuer: letsencrypt-prod`
- `ingress-route.yaml`: Native Traefik IngressRoute CRD
- `argocd-application.yaml`: ArgoCD Application CRD targeting the `production` namespace

Apply directly with:
```bash
kubectl apply -f k8s/
```
