#!/usr/bin/env bash
# ==============================================================================
# Script 05: Configurar kubectl en la máquina local para controlar el cluster remoto
# Obtiene el host y usuario desde config.env o argumentos, sin IPs en duro.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

TARGET_SERVER="${1:-${REMOTE_HOST:-}}"
TARGET_USER="${REMOTE_USER:-p3lud3v}"
SSH_PORT="${REMOTE_SSH_PORT:-22}"

# Si no se pasó argumento ni está configurado en config.env, solicitarlo
if [[ -z "${TARGET_SERVER}" ]]; then
    read -rp "Ingrese la IP o Hostname del servidor Kubernetes remoto: " TARGET_SERVER
fi

if [[ -z "${TARGET_SERVER}" ]]; then
    echo "❌ Error: Debe especificar la IP o Hostname del servidor."
    exit 1
fi

LOCAL_KUBE_DIR="${HOME}/.kube"
LOCAL_KUBECONFIG="${LOCAL_KUBE_DIR}/config-k3s-${TARGET_SERVER}"

echo "============================================================"
echo " 💻 Configurando kubectl local para el cluster ${TARGET_SERVER}..."
echo "============================================================"

mkdir -p "${LOCAL_KUBE_DIR}"

echo "📥 Descargando kubeconfig desde ${TARGET_USER}@${TARGET_SERVER}:${SSH_PORT}..."
scp -P "${SSH_PORT}" "${TARGET_USER}@${TARGET_SERVER}:/etc/rancher/k3s/k3s.yaml" "${LOCAL_KUBECONFIG}"

# Reemplazar 127.0.0.1 con la IP/Hostname del servidor remoto
sed -i "s/127.0.0.1/${TARGET_SERVER}/g" "${LOCAL_KUBECONFIG}"
chmod 600 "${LOCAL_KUBECONFIG}"

echo "✅ Kubeconfig guardado en: ${LOCAL_KUBECONFIG}"

# Verificar conectividad
echo "🔍 Probando conexión local con el cluster..."
if KUBECONFIG="${LOCAL_KUBECONFIG}" kubectl get nodes &>/dev/null; then
    echo "🎉 ¡Conexión exitosa desde tu PC local!"
    KUBECONFIG="${LOCAL_KUBECONFIG}" kubectl get nodes -o wide
else
    echo "ℹ️  Archivo configurado. Si 'kubectl' no está en tu PATH, puedes instalarlo o verificar la conexión de red."
fi

echo ""
echo "============================================================"
echo "📌 Para usar este cluster desde tu terminal local:"
echo "   export KUBECONFIG=${LOCAL_KUBECONFIG}"
echo "   kubectl get nodes"
echo ""
echo "O agrega este alias a tu ~/.bashrc o ~/.zshrc:"
echo "   alias k-remote='kubectl --kubeconfig=${LOCAL_KUBECONFIG}'"
echo "============================================================"
