#!/bin/bash
# ==============================================================================
# Generador de Certificado SSL/TLS Autofirmado con SAN para el Clúster K3s
# Válido para IPs y Nombres de Dominio del Servidor
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_IP="${1:-192.168.18.228}"
DAYS_VALID=3650 # 10 años

echo "🔐 Generando clave privada y certificado TLS para IP: ${SERVER_IP}..."

openssl req -x509 -nodes -days ${DAYS_VALID} -newkey rsa:2048 \
  -keyout "${SCRIPT_DIR}/tls.key" \
  -out "${SCRIPT_DIR}/tls.crt" \
  -subj "/CN=${SERVER_IP}/O=Ambiente Docker/OU=K3s Cluster/C=PE" \
  -addext "subjectAltName = IP:${SERVER_IP},IP:127.0.0.1,DNS:archlinux,DNS:localhost,DNS:*.${SERVER_IP}.nip.io,DNS:${SERVER_IP}.nip.io,DNS:*.local,DNS:*.k8s.local"

chmod 600 "${SCRIPT_DIR}/tls.key"
chmod 644 "${SCRIPT_DIR}/tls.crt"

echo "✅ Certificado generado exitosamente en ${SCRIPT_DIR}:"
openssl x509 -in "${SCRIPT_DIR}/tls.crt" -noout -subject -issuer -dates
