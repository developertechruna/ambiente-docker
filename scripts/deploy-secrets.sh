#!/usr/bin/env bash
# ==============================================================================
# Script: Despliegue de Secretos de Kubernetes desde archivo seguro local
# Aplica secrets en K3s sin versionar claves ni contraseñas en Git.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SECRETS_FILE="${ROOT_DIR}/secrets.env"
CONFIG_FILE="${ROOT_DIR}/config.env"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

TARGET_USER="${1:-${REMOTE_USER:-johnny}}"
TARGET_HOST="${2:-${REMOTE_HOST:-}}"

if [[ -z "${TARGET_HOST}" ]]; then
    if [[ -f "${ROOT_DIR}/.target_host" ]]; then
        TARGET_HOST="$(cat "${ROOT_DIR}/.target_host")"
    else
        TARGET_HOST="127.0.0.1"
    fi
fi

if [[ ! -f "${SECRETS_FILE}" ]]; then
    echo "⚠️ Archivo secrets.env no encontrado. Generando a partir de secrets.env.example..."
    cp "${ROOT_DIR}/secrets.env.example" "${SECRETS_FILE}"
    chmod 600 "${SECRETS_FILE}"
fi

# Cargar variables de secretos
# shellcheck disable=SC1090
source "${SECRETS_FILE}"

echo "🔐 Aplicando secretos en el clúster (${TARGET_USER}@${TARGET_HOST})..."

# Comando de ejecución remota o local
run_cmd() {
    if [[ "${TARGET_HOST}" == "127.0.0.1" || "${TARGET_HOST}" == "localhost" ]]; then
        k3s kubectl "$@"
    else
        ssh "${TARGET_USER}@${TARGET_HOST}" "k3s kubectl $*"
    fi
}

# 1. Asegurar Namespaces
echo "📁 Verificando namespaces..."
run_cmd "create namespace databases --dry-run=client -o yaml | k3s kubectl apply -f -"
run_cmd "create namespace viniplay --dry-run=client -o yaml | k3s kubectl apply -f -"
run_cmd "create namespace tasks-app --dry-run=client -o yaml | k3s kubectl apply -f -"

# 2. PostgreSQL Secret
echo "🐘 Aplicando postgres-secret..."
run_cmd "-n databases create secret generic postgres-secret \
  --from-literal=POSTGRES_DB='${POSTGRES_DB}' \
  --from-literal=POSTGRES_USER='${POSTGRES_USER}' \
  --from-literal=POSTGRES_PASSWORD='${POSTGRES_PASSWORD}' \
  --dry-run=client -o yaml | k3s kubectl apply -f -"

# 3. Oracle 19c Secret
echo "🏛️ Aplicando oracle-secret..."
run_cmd "-n databases create secret generic oracle-secret \
  --from-literal=ORACLE_PWD='${ORACLE_PWD}' \
  --from-literal=ORACLE_SID='${ORACLE_SID}' \
  --from-literal=ORACLE_PDB='${ORACLE_PDB}' \
  --from-literal=ORACLE_CHARACTERSET='${ORACLE_CHARACTERSET}' \
  --dry-run=client -o yaml | k3s kubectl apply -f -"

# 4. ViniPlay Secret
echo "📺 Aplicando viniplay-secret..."
run_cmd "-n viniplay create secret generic viniplay-secret \
  --from-literal=SESSION_SECRET='${VINI_SESSION_SECRET}' \
  --dry-run=client -o yaml | k3s kubectl apply -f -"

# 5. Tasks App Backend Secret
echo "☕ Aplicando app-backend-secret..."
run_cmd "-n tasks-app create secret generic app-backend-secret \
  --from-literal=DB_USER='${APP_DB_USER}' \
  --from-literal=DB_PASSWORD='${APP_DB_PASSWORD}' \
  --dry-run=client -o yaml | k3s kubectl apply -f -"

# 6. TLS Secret si existen certificados locales
if [[ -f "${ROOT_DIR}/manifests/tls/tls.crt" && -f "${ROOT_DIR}/manifests/tls/tls.key" ]]; then
    echo "🔒 Aplicando cluster-default-tls en kube-system..."
    if [[ "${TARGET_HOST}" == "127.0.0.1" || "${TARGET_HOST}" == "localhost" ]]; then
        k3s kubectl -n kube-system create secret tls cluster-default-tls \
          --cert="${ROOT_DIR}/manifests/tls/tls.crt" \
          --key="${ROOT_DIR}/manifests/tls/tls.key" \
          --dry-run=client -o yaml | k3s kubectl apply -f -
    else
        ssh "${TARGET_USER}@${TARGET_HOST}" "mkdir -p ~/k8s-setup/manifests/tls"
        scp -q "${ROOT_DIR}/manifests/tls/tls.crt" "${ROOT_DIR}/manifests/tls/tls.key" "${TARGET_USER}@${TARGET_HOST}:~/k8s-setup/manifests/tls/"
        ssh "${TARGET_USER}@${TARGET_HOST}" "k3s kubectl -n kube-system create secret tls cluster-default-tls \
          --cert=~/k8s-setup/manifests/tls/tls.crt \
          --key=~/k8s-setup/manifests/tls/tls.key \
          --dry-run=client -o yaml | k3s kubectl apply -f -"
    fi
fi

echo "✅ Todos los secretos fueron aplicados correctamente de forma segura."
