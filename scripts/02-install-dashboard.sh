#!/usr/bin/env bash
# ==============================================================================
# Script 02: Despliegue de Kubernetes Dashboard en el cluster
# Utiliza la configuración dinámica y no contiene IPs en duro.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests/dashboard"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

DASHBOARD_PORT="${DASHBOARD_NODEPORT:-30443}"
SERVER_IP="${REMOTE_HOST:-}"
if [[ -z "${SERVER_IP}" ]] && type get_dynamic_ip &>/dev/null; then
    SERVER_IP="$(get_dynamic_ip)"
fi
SERVER_IP="${SERVER_IP:-localhost}"

export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

# Comando kubectl (usa k3s kubectl si kubectl directo no está configurado)
if command -v kubectl &>/dev/null; then
    KUBECTL="kubectl"
else
    KUBECTL="k3s kubectl"
fi

echo "============================================================"
echo " 📊 Desplegando Kubernetes Dashboard..."
echo "============================================================"

# 1. Aplicar manifiesto oficial
echo "📄 Aplicando manifiesto recomendado de Kubernetes Dashboard..."
if [[ -f "${MANIFESTS_DIR}/recommended.yaml" ]]; then
    ${KUBECTL} apply -f "${MANIFESTS_DIR}/recommended.yaml"
else
    ${KUBECTL} apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
fi

# 2. Aplicar servicio NodePort
echo "🔌 Configurando servicio NodePort en el puerto ${DASHBOARD_PORT}..."
if [[ -f "${MANIFESTS_DIR}/dashboard-nodeport.yaml" ]]; then
    ${KUBECTL} apply -f "${MANIFESTS_DIR}/dashboard-nodeport.yaml"
else
    cat <<EOF | ${KUBECTL} apply -f -
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-dashboard-nodeport
  namespace: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
spec:
  type: NodePort
  ports:
    - port: 443
      targetPort: 8443
      nodePort: ${DASHBOARD_PORT}
      name: https
  selector:
    k8s-app: kubernetes-dashboard
EOF
fi

# 3. Esperar a que el deployment esté disponible
echo "⏳ Esperando a que el pod de Kubernetes Dashboard esté ejecutándose..."
${KUBECTL} -n kubernetes-dashboard rollout status deployment/kubernetes-dashboard --timeout=120s

echo "============================================================"
echo " ✅ Kubernetes Dashboard desplegado con éxito!"
echo " 🌐 URL de acceso: https://${SERVER_IP}:${DASHBOARD_PORT}"
echo "    (Acepta la advertencia de certificado autofirmado en tu navegador)"
echo "============================================================"
