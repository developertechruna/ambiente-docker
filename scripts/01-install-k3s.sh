#!/usr/bin/env bash
# ==============================================================================
# Script 01: Instalación de K3s (Kubernetes ligero) en el servidor
# Obtiene la IP del nodo de forma dinámica y no utiliza IPs en duro.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

# Cargar configuración si existe
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

# Detectar la IP del nodo de forma dinámica en la máquina local/servidor
SERVER_IP="${REMOTE_HOST:-}"
if [[ -z "${SERVER_IP}" ]] || type get_dynamic_ip &>/dev/null; then
    SERVER_IP="$(get_dynamic_ip 2>/dev/null || ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' || hostname -I | awk '{print $1}')"
fi

echo "============================================================"
echo " 🚀 Iniciando instalación de K3s en $(hostname)"
echo " 🌐 IP dinámica detectada para TLS/SAN: ${SERVER_IP}"
echo "============================================================"

# Verificar si se ejecuta con sudo o root
if [[ "$(id -u)" -ne 0 ]]; then
    echo "⚠️  Este script requiere permisos de superusuario."
    echo "    Re-ejecutando con sudo..."
    exec sudo bash "$0" "$@"
fi

# 1. Comprobar si K3s ya está instalado
if command -v k3s &>/dev/null && systemctl is-active --quiet k3s; then
    echo "ℹ️  K3s ya está instalado y activo."
else
    echo "📦 Descargando e instalando K3s..."
    INSTALL_ARGS="server --write-kubeconfig-mode 644"
    if [[ -n "${SERVER_IP}" ]]; then
        INSTALL_ARGS="${INSTALL_ARGS} --tls-san ${SERVER_IP}"
    fi
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="${INSTALL_ARGS}" sh -
fi

# 2. Esperar a que el servicio esté activo y el nodo esté listo
echo "⏳ Esperando a que el nodo Kubernetes esté en estado 'Ready'..."
for i in {1..30}; do
    if k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; then
        echo "✅ Nodo Kubernetes listo."
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# 3. Asegurar permisos de lectura en el archivo kubeconfig para usuarios regulares
if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
    chmod 644 /etc/rancher/k3s/k3s.yaml
    echo "✅ /etc/rancher/k3s/k3s.yaml configurado con permisos 644."
fi

# 4. Crear symlink para kubectl si no existe en /usr/local/bin
if ! command -v kubectl &>/dev/null; then
    if [[ -f /usr/local/bin/k3s ]]; then
        ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
        echo "✅ Symlink creado: kubectl -> k3s"
    fi
fi

# 5. Configurar export de KUBECONFIG en perfiles de usuario
for PROFILE in /etc/profile.d/k3s.sh; do
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' > "${PROFILE}"
    chmod +x "${PROFILE}"
done

echo "============================================================"
echo " ✅ Instalación de K3s completada exitosamente!"
echo "    Versión:"
k3s kubectl version --short 2>/dev/null || k3s kubectl version
echo ""
echo "    Estado de los nodos:"
k3s kubectl get nodes -o wide
echo "============================================================"
