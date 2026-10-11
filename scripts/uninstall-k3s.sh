#!/usr/bin/env bash
# ==============================================================================
# Script: Desinstalación limpia de K3s y Kubernetes Dashboard
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo " ⚠️  Desinstalador de K3s en el servidor"
echo "============================================================"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Re-ejecutando con sudo..."
    exec sudo bash "$0" "$@"
fi

read -rp "Está seguro que desea desinstalar K3s y eliminar todos los contenedores/volúmenes? [y/N]: " CONFIRM
if [[ "${CONFIRM}" =~ ^[Yy]$ ]]; then
    if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
        echo "🗑️  Ejecutando /usr/local/bin/k3s-uninstall.sh..."
        /usr/local/bin/k3s-uninstall.sh
    else
        echo "ℹ️  No se encontró /usr/local/bin/k3s-uninstall.sh. Limpiando procesos..."
        systemctl stop k3s 2>/dev/null || true
        systemctl disable k3s 2>/dev/null || true
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/profile.d/k3s.sh
    fi
    echo "✅ K3s ha sido desinstalado completamente."
else
    echo "❌ Cancelado."
fi
