#!/usr/bin/env bash
# ==============================================================================
# Script 03: Crear usuario administrador RBAC y generar token permanente
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests/dashboard"

export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

if command -v kubectl &>/dev/null; then
    KUBECTL="kubectl"
else
    KUBECTL="k3s kubectl"
fi

echo "============================================================"
echo " 👤 Creando usuario administrador 'admin-user' para Dashboard..."
echo "============================================================"

# 1. Aplicar manifiesto de usuario y roles
if [[ -f "${MANIFESTS_DIR}/admin-user.yaml" ]]; then
    ${KUBECTL} apply -f "${MANIFESTS_DIR}/admin-user.yaml"
else
    cat <<EOF | ${KUBECTL} apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF
fi

# 2. Esperar a que el controlador popule el token en el secret (máx 15s)
echo "⏳ Obteniendo token de autenticación..."
TOKEN=""
for i in {1..15}; do
    TOKEN=$(${KUBECTL} -n kubernetes-dashboard get secret admin-user-token -o jsonpath="{.data.token}" 2>/dev/null | base64 -d 2>/dev/null || true)
    if [[ -n "${TOKEN}" ]]; then
        break
    fi
    sleep 1
done

# Si por alguna razón el secret token no estuviera populado, generar un token largo con create token
if [[ -z "${TOKEN}" ]]; then
    TOKEN=$(${KUBECTL} -n kubernetes-dashboard create token admin-user --duration=87600h)
fi

echo "============================================================"
echo " ✅ Usuario administrador configurado con éxito!"
echo "============================================================"
echo ""
echo "🔑 COPIA ESTE TOKEN PARA INICIAR SESIÓN EN EL DASHBOARD:"
echo "--------------------------------------------------------------------------------"
echo "${TOKEN}"
echo "--------------------------------------------------------------------------------"
echo ""
echo "💡 Guarda este token o puedes consultarlo en cualquier momento ejecutando:"
echo "   ./scripts/04-get-token.sh"
echo "============================================================"
