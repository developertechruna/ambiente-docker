#!/usr/bin/env bash
# ==============================================================================
# Script Maestro: Despliegue Automatizado en Servidor Remoto
# Lee la configuración de config.env y obtiene la IP de forma dinámica.
# Sin IPs en duro.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# Cargar configuración base
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

# Detectar IP de la máquina local actual (para no confundirla con el servidor remoto)
LOCAL_CLIENT_IP="$(get_dynamic_ip 2>/dev/null || ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' || true)"

TARGET_USER="${REMOTE_USER:-p3lud3v}"
TARGET_HOST="${REMOTE_HOST:-}"

# 1. Prioridad: Argumento de línea de comandos (ej: ./deploy-remote.sh p3lud3v@192.168.18.228 o ./deploy-remote.sh 192.168.18.228)
if [[ $# -ge 1 ]]; then
    ARG_TARGET="$1"
    if [[ "${ARG_TARGET}" == *"@"* ]]; then
        TARGET_USER="${ARG_TARGET%%@*}"
        TARGET_HOST="${ARG_TARGET##*@}"
    else
        TARGET_HOST="${ARG_TARGET}"
    fi
fi

# 2. Si la IP remota está vacía o coincide con la IP de este equipo local, pedirla interactivamente
if [[ -z "${TARGET_HOST}" || "${TARGET_HOST}" == "${LOCAL_CLIENT_IP}" ]]; then
    echo "================================================================================"
    echo " 🌐 Despliegue de Kubernetes en Servidor Remoto"
    echo "================================================================================"
    echo " IP de este equipo local: ${LOCAL_CLIENT_IP:-Desconocida}"
    read -rp "👉 Ingrese la IP o Hostname del servidor remoto a instalar: " INPUT_HOST
    TARGET_HOST="${INPUT_HOST}"
fi

if [[ -z "${TARGET_HOST}" ]]; then
    echo "❌ Error: Debe especificar la IP del servidor remoto."
    exit 1
fi

SSH_PORT="${REMOTE_SSH_PORT:-22}"
NODEPORT="${DASHBOARD_NODEPORT:-30443}"
REMOTE_DIR="/home/${TARGET_USER}/k8s-setup"

echo "================================================================================"
echo " 🚀 Despliegue de Kubernetes (K3s) + Dashboard en Servidor Remoto"
echo " 🎯 Destino: ${TARGET_USER}@${TARGET_HOST} (Puerto SSH: ${SSH_PORT})"
echo "================================================================================"

# 1. Comprobar conectividad básica por ping
echo "📡 Verificando ping a ${TARGET_HOST}..."
if ! ping -c 1 -W 2 "${TARGET_HOST}" &>/dev/null; then
    echo "❌ Error: No se puede alcanzar el host ${TARGET_HOST} en la red."
    exit 1
fi
echo "✅ Servidor alcanzable."

# 2. Copiar scripts y manifiestos al servidor
echo ""
echo "📦 Copiando archivos de instalación a ${TARGET_USER}@${TARGET_HOST}:${REMOTE_DIR}..."
ssh -p "${SSH_PORT}" "${TARGET_USER}@${TARGET_HOST}" "mkdir -p ${REMOTE_DIR}"
scp -P "${SSH_PORT}" -r \
    "${SCRIPT_DIR}/config.env" \
    "${SCRIPT_DIR}/scripts" \
    "${SCRIPT_DIR}/manifests" \
    "${TARGET_USER}@${TARGET_HOST}:${REMOTE_DIR}/"

# 3. Dar permisos de ejecución a los scripts en el servidor
ssh -p "${SSH_PORT}" "${TARGET_USER}@${TARGET_HOST}" "chmod +x ${REMOTE_DIR}/scripts/*.sh"

# 4. Ejecutar instalación de K3s (requiere sudo en el servidor)
echo ""
echo "🔧 Paso 1/3: Instalando K3s en el servidor..."
ssh -t -p "${SSH_PORT}" "${TARGET_USER}@${TARGET_HOST}" "sudo REMOTE_HOST='${TARGET_HOST}' bash ${REMOTE_DIR}/scripts/01-install-k3s.sh"

# 5. Desplegar Dashboard
echo ""
echo "📊 Paso 2/3: Desplegando Kubernetes Dashboard (NodePort ${NODEPORT})..."
ssh -p "${SSH_PORT}" "${TARGET_USER}@${TARGET_HOST}" "REMOTE_HOST='${TARGET_HOST}' bash ${REMOTE_DIR}/scripts/02-install-dashboard.sh"

# 6. Crear usuario administrador y obtener token
echo ""
echo "🔑 Paso 3/3: Configurando usuario administrador y token RBAC..."
ssh -p "${SSH_PORT}" "${TARGET_USER}@${TARGET_HOST}" "bash ${REMOTE_DIR}/scripts/03-create-admin-user.sh"

# 7. Configurar kubectl local
echo ""
echo "💻 Configurando acceso kubectl local..."
bash "${SCRIPT_DIR}/scripts/05-setup-local-kubectl.sh" "${TARGET_HOST}" || true

# 8. Obtener token para mostrar al final
TOKEN=$(ssh -p "${SSH_PORT}" "${TARGET_USER}@${TARGET_HOST}" "bash ${REMOTE_DIR}/scripts/04-get-token.sh 2>/dev/null" | grep -A 1 "TOKEN DE ACCESO:" | tail -n 1 || true)

echo ""
echo "================================================================================"
echo " 🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!"
echo "================================================================================"
echo " 🌐 Kubernetes Dashboard URL:"
echo "    https://${TARGET_HOST}:${NODEPORT}"
echo ""
echo " 🔑 Tu Token de autenticación:"
echo "--------------------------------------------------------------------------------"
if [[ -n "${TOKEN}" ]]; then
    echo "${TOKEN}"
else
    echo "Ejecuta './scripts/04-get-token.sh' desde el servidor para consultar tu token."
fi
echo "--------------------------------------------------------------------------------"
echo ""
echo " 📋 Instrucciones de acceso:"
echo " 1. Abre https://${TARGET_HOST}:${NODEPORT} en tu navegador web."
echo " 2. Acepta el certificado SSL autofirmado (Avanzado -> Continuar)."
echo " 3. Selecciona la opción 'Token' y pega el token mostrado arriba."
echo " 4. ¡Listo! Verás el estado de los nodos, memoria, CPU y cargas de trabajo."
echo ""
echo " 🚀 Para probar el despliegue de una aplicación de ejemplo:"
echo "    kubectl apply -f manifests/sample-app/sample-app.yaml"
echo "    Acceso: http://${TARGET_HOST}:30080"
echo "================================================================================"
