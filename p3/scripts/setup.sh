#!/usr/bin/env bash

set -Eeuo pipefail

CLUSTER_NAME="iot-cluster"
ARGOCD_NAMESPACE="argocd"
DEV_NAMESPACE="dev"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

log() {
    echo "[INFO] $*"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

if [ "${EUID}" -ne 0 ]; then
    error "Lance ce script avec sudo ou en root."
fi

export DEBIAN_FRONTEND=noninteractive

log "Installation des dépendances de base..."
apt-get update
apt-get install -y ca-certificates curl gnupg apt-transport-https

if command -v docker >/dev/null 2>&1; then
    log "Docker est déjà installé."
else
    log "Installation de Docker..."

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    . /etc/os-release

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker 2>/dev/null || true
fi

docker info >/dev/null 2>&1 || \
    error "Docker est installé mais inaccessible."

log "Docker fonctionne."

if command -v k3d >/dev/null 2>&1; then
    log "K3d est déjà installé."
else
    log "Installation de K3d..."
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if command -v kubectl >/dev/null 2>&1; then
    log "kubectl est déjà installé."
else
    log "Installation de kubectl..."

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
        | gpg --dearmor \
        -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
        > /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y kubectl
fi

if k3d cluster list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
    log "Le cluster ${CLUSTER_NAME} existe déjà."
else
    log "Création du cluster ${CLUSTER_NAME}..."
    k3d cluster create "${CLUSTER_NAME}" -p "8888:80@loadbalancer"
fi

kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || {
    log "Création du namespace ${ARGOCD_NAMESPACE}..."
    kubectl create namespace "${ARGOCD_NAMESPACE}"
}

kubectl get namespace "${DEV_NAMESPACE}" >/dev/null 2>&1 || {
    log "Création du namespace ${DEV_NAMESPACE}..."
    kubectl create namespace "${DEV_NAMESPACE}"
}

log "Installation d'Argo CD..."
kubectl apply \
    -n "${ARGOCD_NAMESPACE}" \
    --server-side \
    --force-conflicts \
    -f "${ARGOCD_MANIFEST}"

log "Attente du démarrage des pods Argo CD..."
kubectl wait \
    --for=condition=Ready \
    pod \
    --all \
    -n "${ARGOCD_NAMESPACE}" \
    --timeout=300s

echo
echo "===== Installation terminée ====="

echo
echo "===== Docker ====="
docker ps

echo
echo "===== Kubernetes nodes ====="
kubectl get nodes

echo
echo "===== Namespaces ====="
kubectl get namespaces

echo
echo "===== Argo CD pods ====="
kubectl get pods -n "${ARGOCD_NAMESPACE}"
echo
echo "===== Argo CD credentials ====="
echo "Username: admin"
echo -n "Password: "
kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d
echo
echo "Pour ouvrir l'interface Argo CD :"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Puis ouvrir https://localhost:8080"
