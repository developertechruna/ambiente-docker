#!/usr/bin/env bash
# ==============================================================================
# Script 01: Instalación de K3s (Kubernetes ligero) en el servidor
# Obtiene la IP del nodo de forma dinámica y no utiliza IPs en duro.
# Pasa versión explícita para evitar fallos de certificado SSL en update.k3s.io.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

# Cargar configuración si existe
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

# Detectar nombre del host sin depender del comando 'hostname' (compatible con Arch Linux mínimo)
NODE_NAME="$(uname -n 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "servidor")"

# Detectar la IP del nodo de forma dinámica en la máquina local/servidor
SERVER_IP="${REMOTE_HOST:-}"
if [[ -z "${SERVER_IP}" ]] || type get_dynamic_ip &>/dev/null; then
    SERVER_IP="$(get_dynamic_ip 2>/dev/null || ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' || ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1 || echo "")"
fi

# Versión de K3s (evita consultar update.k3s.io cuyo certificado puede fallar)
DESIRED_K3S_VERSION="${K3S_VERSION:-}"
if [[ -z "${DESIRED_K3S_VERSION}" ]]; then
    DESIRED_K3S_VERSION="$(curl -fsSL https://api.github.com/repos/k3s-io/k3s/releases 2>/dev/null | grep -m 1 -oP '"tag_name":\s*"\K(v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+)' || echo "v1.31.5+k3s1")"
fi

echo "============================================================"
echo " 🚀 Iniciando instalación de K3s en ${NODE_NAME}"
echo " 🌐 IP dinámica para TLS/SAN: ${SERVER_IP:-auto}"
echo " 📦 Versión de K3s a instalar: ${DESIRED_K3S_VERSION}"
echo "============================================================"

# Verificar si se ejecuta con sudo o root
if [[ "$(id -u)" -ne 0 ]]; then
    echo "⚠️  Este script requiere permisos de superusuario."
    echo "    Re-ejecutando con sudo..."
    exec sudo REMOTE_HOST="${SERVER_IP}" K3S_VERSION="${DESIRED_K3S_VERSION}" bash "$0" "$@"
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

    # Definir INSTALL_K3S_VERSION explícitamente evita la consulta a update.k3s.io
    export INSTALL_K3S_VERSION="${DESIRED_K3S_VERSION}"
    export INSTALL_K3S_EXEC="${INSTALL_ARGS}"

    if ! curl -sfL https://get.k3s.io | sh -; then
        echo "⚠️  Reintentando con script espejo de GitHub..."
        curl -sfL https://raw.githubusercontent.com/k3s-io/k3s/master/install.sh | sh -
    fi
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
echo "    Versión instalada:"
k3s kubectl version --short 2>/dev/null || k3s kubectl version
echo ""
echo "    Estado de los nodos:"
k3s kubectl get nodes -o wide
echo "============================================================"
