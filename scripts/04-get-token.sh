#!/usr/bin/env bash
# ==============================================================================
# Script 04: Consultar el token de acceso al Kubernetes Dashboard
# Obtiene la IP dinámicamente y lee parámetros desde config.env
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

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

if command -v kubectl &>/dev/null; then
    KUBECTL="kubectl"
else
    KUBECTL="k3s kubectl"
fi

TOKEN=$(${KUBECTL} -n kubernetes-dashboard get secret admin-user-token -o jsonpath="{.data.token}" 2>/dev/null | base64 -d 2>/dev/null || true)

if [[ -z "${TOKEN}" ]]; then
    TOKEN=$(${KUBECTL} -n kubernetes-dashboard create token admin-user --duration=87600h 2>/dev/null || true)
fi

if [[ -z "${TOKEN}" ]]; then
    echo "❌ Error: No se pudo obtener el token. Asegúrate de haber ejecutado 03-create-admin-user.sh"
    exit 1
fi

echo "============================================================"
echo " 🌐 URL DASHBOARD: https://${SERVER_IP}:${DASHBOARD_PORT}"
echo "============================================================"
echo " 🔑 TOKEN DE ACCESO:"
echo "--------------------------------------------------------------------------------"
echo "${TOKEN}"
echo "--------------------------------------------------------------------------------"
echo "💡 Selecciona 'Token' en la pantalla del navegador y pega la clave anterior."
echo "============================================================"
