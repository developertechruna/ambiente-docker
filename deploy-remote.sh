#!/usr/bin/env bash
# ==============================================================================
# Script Maestro: Despliegue Automatizado en Servidor Remoto
# Lee la configuración de config.env y obtiene la IP de forma dinámica.
# Utiliza SSH multiplexing para evitar pedir la contraseña repetidamente.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# Cargar configuración base si existe
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

TARGET_USER="${REMOTE_USER:-p3lud3v}"
TARGET_HOST=""

# 1. Si se pasó argumento en línea de comandos (ej: ./deploy-remote.sh 192.168.18.228 o ./deploy-remote.sh p3lud3v@192.168.18.228)
if [[ $# -ge 1 ]]; then
    ARG_TARGET="$1"
    if [[ "${ARG_TARGET}" == *"@"* ]]; then
        TARGET_USER="${ARG_TARGET%%@*}"
        TARGET_HOST="${ARG_TARGET##*@}"
    else
        TARGET_HOST="${ARG_TARGET}"
    fi
elif [[ -n "${REMOTE_HOST:-}" ]]; then
    TARGET_HOST="${REMOTE_HOST}"
fi

# 2. Si aún no está definida la IP remota, solicitarla interactivamente
if [[ -z "${TARGET_HOST}" ]]; then
    echo "================================================================================"
    echo " 🌐 Despliegue de Kubernetes en Servidor Remoto"
    echo "================================================================================"
    read -rp "👉 Ingrese la IP o Hostname del servidor remoto a instalar: " TARGET_HOST
fi

if [[ -z "${TARGET_HOST}" ]]; then
    echo "❌ Error: Debe especificar la IP del servidor remoto."
    exit 1
fi

SSH_PORT="${REMOTE_SSH_PORT:-22}"
NODEPORT="${DASHBOARD_NODEPORT:-30443}"
REMOTE_DIR="/home/${TARGET_USER}/k8s-setup"
DESIRED_VERSION="${K3S_VERSION:-}"

# Socket para reutilizar conexión SSH (ControlMaster) y no pedir contraseña múltiples veces
SSH_SOCKET="/tmp/ssh_k8s_mux_${TARGET_USER}_${TARGET_HOST//./_}"
SSH_OPTS=(-o "ControlMaster=auto" -o "ControlPath=${SSH_SOCKET}" -o "ControlPersist=10m" -o "StrictHostKeyChecking=accept-new" -p "${SSH_PORT}")
SCP_OPTS=(-o "ControlPath=${SSH_SOCKET}" -o "StrictHostKeyChecking=accept-new" -P "${SSH_PORT}")

cleanup_ssh() {
    ssh -O exit -o "ControlPath=${SSH_SOCKET}" "${TARGET_USER}@${TARGET_HOST}" 2>/dev/null || true
    rm -f "${SSH_SOCKET}" 2>/dev/null || true
}
trap cleanup_ssh EXIT INT TERM

echo "================================================================================"
echo " 🚀 Despliegue de Kubernetes (K3s) + Dashboard en Servidor Remoto"
echo " 🎯 Destino: ${TARGET_USER}@${TARGET_HOST} (Puerto SSH: ${SSH_PORT})"
echo "================================================================================"

# 1. Comprobar conectividad básica por ping
echo "📡 Verificando ping a ${TARGET_HOST}..."
if ! ping -c 1 -W 2 "${TARGET_HOST}" &>/dev/null; then
    echo "❌ Error: No se puede alcanzar el host ${TARGET_HOST} en la red local."
    exit 1
fi
echo "✅ Servidor alcanzable."

# 2. Iniciar sesión SSH y preparar carpeta remota (pedirá la contraseña una sola vez)
echo ""
echo "📦 Conectando al servidor y copiando archivos de instalación a ${TARGET_USER}@${TARGET_HOST}:${REMOTE_DIR}..."
ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" "mkdir -p ${REMOTE_DIR}"
scp "${SCP_OPTS[@]}" -r \
    "${SCRIPT_DIR}/config.env" \
    "${SCRIPT_DIR}/scripts" \
    "${SCRIPT_DIR}/manifests" \
    "${TARGET_USER}@${TARGET_HOST}:${REMOTE_DIR}/"

# 3. Dar permisos de ejecución a los scripts en el servidor
ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" "chmod +x ${REMOTE_DIR}/scripts/*.sh"

# 4. Ejecutar instalación de K3s (requiere sudo en el servidor)
echo ""
echo "🔧 Paso 1/4: Instalando K3s en el servidor..."
ssh -t "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" "sudo REMOTE_HOST='${TARGET_HOST}' K3S_VERSION='${DESIRED_VERSION}' bash ${REMOTE_DIR}/scripts/01-install-k3s.sh"

# 5. Desplegar Dashboard
echo ""
echo "📊 Paso 2/4: Desplegando Kubernetes Dashboard (NodePort ${NODEPORT})..."
ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" "REMOTE_HOST='${TARGET_HOST}' bash ${REMOTE_DIR}/scripts/02-install-dashboard.sh"

# 6. Crear usuario administrador y obtener token
echo ""
echo "🔑 Paso 3/4: Configurando usuario administrador y token RBAC..."
ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" "bash ${REMOTE_DIR}/scripts/03-create-admin-user.sh"

# 7. Desplegar aplicación de prueba
echo ""
echo "🚀 Paso 4/4: Desplegando aplicación de prueba (NodePort 30080 e Ingress)..."
ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" "k3s kubectl apply -f ${REMOTE_DIR}/manifests/sample-app/sample-app.yaml"

# 8. Configurar kubectl local
echo ""
echo "💻 Configurando acceso kubectl local..."
bash "${SCRIPT_DIR}/scripts/05-setup-local-kubectl.sh" "${TARGET_HOST}" || true

# 9. Obtener token para mostrar al final
TOKEN=$(ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" "bash ${REMOTE_DIR}/scripts/04-get-token.sh 2>/dev/null" | grep -oE 'eyJ[a-zA-Z0-9._-]+' | head -n 1 || true)

echo ""
echo "================================================================================"
echo " 🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!"
echo "================================================================================"
echo " 🌐 1. KUBERNETES DASHBOARD (Monitorización de Nodos y Cargas):"
echo "    👉 https://${TARGET_HOST}:${NODEPORT}"
echo ""
echo " 🔑 Tu Token de autenticación:"
echo "--------------------------------------------------------------------------------"
if [[ -n "${TOKEN}" ]]; then
    echo "${TOKEN}"
else
    echo "Consulta tu token con: make token"
fi
echo "--------------------------------------------------------------------------------"
echo ""
echo " 🌐 2. APLICACIÓN DE EJEMPLO DESPLEGADA:"
echo "    👉 http://${TARGET_HOST}:30080"
echo "    👉 http://${TARGET_HOST}/demo"
echo ""
echo " 📋 Instrucciones de acceso al Dashboard:"
echo " 1. Abre https://${TARGET_HOST}:${NODEPORT} en tu navegador web (IMPORTANTE: con https://)."
echo " 2. Acepta el certificado SSL autofirmado (Avanzado -> Continuar)."
echo " 3. Selecciona la opción 'Token' y pega el token mostrado arriba."
echo " 4. ¡Listo! Verás el estado del nodo, memoria, CPU y cargas de trabajo."
echo "================================================================================"
