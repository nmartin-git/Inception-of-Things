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

if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != "--reset" ]; }; then
    error "Usage : $0 [--reset]"
fi

RESET_CLUSTER=false
if [ "${1:-}" = "--reset" ]; then
    RESET_CLUSTER=true
fi

export DEBIAN_FRONTEND=noninteractive

log "Installation des dépendances de base..."
apt-get update
apt-get install -y ca-certificates curl

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

if [ "${RESET_CLUSTER}" = true ] && \
    k3d cluster list | awk 'NR > 1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
    log "Suppression du cluster ${CLUSTER_NAME} pour une installation propre..."
    k3d cluster delete "${CLUSTER_NAME}"
    if k3d cluster list | awk 'NR > 1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
        error "Le cluster ${CLUSTER_NAME} existe encore après la suppression."
    fi
fi

if command -v kubectl >/dev/null 2>&1 && \
    [[ "$(kubectl version --client --output=yaml 2>/dev/null | awk '$1 == "gitVersion:" {print $2; exit}')" == v1.36.* ]]; then
    log "kubectl v1.36 est déjà installé."
else
    log "Installation de kubectl v1.36..."
    arch="$(dpkg --print-architecture)"
    case "${arch}" in
        amd64|arm64) ;;
        *) error "Architecture non prise en charge pour kubectl : ${arch}" ;;
    esac

    release="$(curl -fsSL https://dl.k8s.io/release/stable-1.36.txt)"
    [[ "${release}" =~ ^v1\.36\.[0-9]+$ ]] || error "Version kubectl inattendue : ${release}"

    kubectl_binary="$(mktemp)"
    kubectl_url="https://dl.k8s.io/release/${release}/bin/linux/${arch}/kubectl"
    curl -fsSL "${kubectl_url}" -o "${kubectl_binary}"
    kubectl_sha="$(curl -fsSL "${kubectl_url}.sha256")"
    printf '%s  %s\n' "${kubectl_sha}" "${kubectl_binary}" | sha256sum --check --status \
        || error "La vérification de kubectl a échoué."
    install -m 0755 "${kubectl_binary}" /usr/local/bin/kubectl
    rm -f "${kubectl_binary}"
fi

if k3d cluster list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
    log "Le cluster ${CLUSTER_NAME} existe déjà."
else
    log "Création du cluster ${CLUSTER_NAME}..."
    k3d cluster create "${CLUSTER_NAME}" -p "8888:80@loadbalancer"
fi

log "Sélection du contexte Kubernetes de ${CLUSTER_NAME}..."
k3d kubeconfig merge "${CLUSTER_NAME}" \
    --kubeconfig-merge-default \
    --kubeconfig-switch-context

if [ "$(kubectl config current-context)" != "k3d-${CLUSTER_NAME}" ]; then
    error "Le contexte Kubernetes actif n'est pas k3d-${CLUSTER_NAME}."
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
kubectl rollout status \
    deployment/argocd-server \
    -n "${ARGOCD_NAMESPACE}" \
    --timeout=300s

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
echo "Si le script a été lancé avec sudo, lance également kubectl avec sudo."
echo "Puis ouvrir https://localhost:8080"
