SHELL := /bin/bash

# Leer variables evaluadas dinámicamente por bash desde config.env
REMOTE_HOST ?= $(shell bash -c 'source ./config.env 2>/dev/null && echo $$REMOTE_HOST')
REMOTE_USER ?= $(shell bash -c 'source ./config.env 2>/dev/null && echo $$REMOTE_USER')

# Permite sobreescribir el host destino desde el comando:
# Ejemplo: make deploy HOST=192.168.18.228 o make deploy-postgres HOST=192.168.18.228
ifdef HOST
REMOTE_HOST := $(HOST)
endif

.PHONY: all help deploy token kubeconfig status deploy-sample remove-sample \
        deploy-postgres status-postgres remove-postgres \
        deploy-oracle status-oracle logs-oracle remove-oracle \
        deploy-viniplay status-viniplay logs-viniplay stop-viniplay start-viniplay remove-viniplay \
        deploy-app deploy-backend deploy-frontend deploy-ingress \
        status-app logs-backend logs-frontend remove-app \
        build-and-deploy-app build-and-deploy-backend build-and-deploy-frontend clean \
        generate-cert deploy-tls status-tls

all: help

help:
	@echo "=================================================================="
	@echo " Kubernetes (K3s) Cluster Manager"
	@echo " Host destino: $(REMOTE_USER)@$(REMOTE_HOST)"
	@echo "=================================================================="
	@echo " Comandos disponibles:"
	@echo "   make deploy [HOST=x.x.x.x]   - Instala K3s y Dashboard"
	@echo "   make token [HOST=x.x.x.x]    - Muestra el token de acceso"
	@echo "   make kubeconfig [HOST=x.x.x] - Configura kubectl en esta PC local"
	@echo "   make status [HOST=x.x.x.x]   - Consulta el estado general del cluster"
	@echo ""
	@echo " Bases de Datos (Databases):"
	@echo "   make deploy-postgres         - Despliega PostgreSQL con PVC (10GB) y puerto 5432"
	@echo "   make status-postgres         - Consulta estado, Pods y PVC de Postgres"
	@echo "   make stop-postgres           - Detiene el pod de PostgreSQL (libera RAM)"
	@echo "   make start-postgres          - Enciende el pod de PostgreSQL"
	@echo "   make remove-postgres         - Elimina el despliegue de Postgres"
	@echo "   make deploy-oracle           - Despliega Oracle 19c con PVC (20GB) y puerto 1521"
	@echo "   make status-oracle           - Consulta estado, Pod y PVC de Oracle 19c"
	@echo "   make logs-oracle             - Ver logs de arranque de Oracle 19c"
	@echo "   make stop-oracle             - Detiene el pod de Oracle (libera 4GB RAM)"
	@echo "   make start-oracle            - Enciende el pod de Oracle"
	@echo "   make remove-oracle           - Elimina el despliegue de Oracle 19c"
	@echo ""
	@echo " Streaming IPTV & Multimedia:"
	@echo "   make build-viniplay          - Construye la imagen personalizada viniplay:custom con parches en k3s"
	@echo "   make deploy-viniplay         - Despliega ViniPlay (Web IPTV/DVR) en http://$(REMOTE_HOST)/viniplay"
	@echo "   make status-viniplay         - Consulta estado, Pod, PVC, Service e Ingress de ViniPlay"
	@echo "   make logs-viniplay           - Ver logs en vivo del contenedor ViniPlay"
	@echo "   make stop-viniplay           - Detiene el pod de ViniPlay (libera RAM/CPU)"
	@echo "   make start-viniplay          - Enciende el pod de ViniPlay"
	@echo "   make remove-viniplay         - Elimina el despliegue de ViniPlay"
	@echo ""
	@echo " Aplicativos Desacoplados (Frontend y Backend):"
	@echo "   make deploy-app              - Despliega Frontend + Backend + Ingress"
	@echo "   make deploy-backend          - Despliega solo el Backend (Spring Boot 3)"
	@echo "   make deploy-frontend         - Despliega solo el Frontend (Angular 18 / Nginx)"
	@echo "   make status-app              - Consulta Pods, Services e Ingress de tasks-app"
	@echo "   make logs-backend            - Logs en vivo del Pod de Backend"
	@echo "   make logs-frontend           - Logs en vivo del Pod de Frontend"
	@echo "   make build-and-deploy-app    - Compila y despliega ambos aplicativos"
	@echo "   make build-and-deploy-backend- Compila y despliega solo Backend"
	@echo "   make build-and-deploy-frontend Compila y despliega solo Frontend"
	@echo "   make remove-app              - Elimina aplicativo tasks-app"
	@echo ""
	@echo " Seguridad y Certificados SSL/TLS (HTTPS):"
	@echo "   make generate-cert           - Genera certificado autofirmado con SAN (IP + Dominios)"
	@echo "   make deploy-tls              - Despliega certificados y configura Traefik TLSStore"
	@echo "   make status-tls              - Verifica el estado de HTTPS y certificados en el servidor"
	@echo ""
	@echo " Aplicación de prueba:"
	@echo "   make deploy-sample           - Despliega app de prueba (NodePort/Ingress)"
	@echo "   make remove-sample           - Elimina app de prueba"
	@echo "=================================================================="

deploy:
	@chmod +x deploy-remote.sh scripts/*.sh
	@./deploy-remote.sh $(REMOTE_USER)@$(REMOTE_HOST)

token:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "bash ~/k8s-setup/scripts/04-get-token.sh"

kubeconfig:
	@chmod +x scripts/05-setup-local-kubectl.sh
	@./scripts/05-setup-local-kubectl.sh $(REMOTE_HOST)

status:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl get nodes -o wide && echo '' && k3s kubectl get pods -A"

deploy-postgres:
	@echo "📦 Copiando y aplicando manifiesto de PostgreSQL en $(REMOTE_HOST)..."
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p ~/k8s-setup/manifests/postgres"
	@scp -r manifests/postgres/* $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/postgres/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/postgres/postgres.yaml"
	@echo "✅ PostgreSQL desplegado en el namespace 'databases'."
	@echo "   Puerto expuesto: $(REMOTE_HOST):5432"

status-postgres:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n databases get statefulset,pods,svc,pvc"

stop-postgres:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n databases scale statefulset postgres --replicas=0"
	@echo "🛑 Pod de PostgreSQL detenido (RAM liberada, datos preservados)."

start-postgres:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n databases scale statefulset postgres --replicas=1"
	@echo "▶️  Pod de PostgreSQL encendido."

remove-postgres:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl delete -f ~/k8s-setup/manifests/postgres/postgres.yaml"

# ==============================================================================
# Oracle Database 19c
# ==============================================================================
deploy-oracle:
	@echo "📦 Copiando y aplicando manifiesto de Oracle 19c en $(REMOTE_HOST)..."
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p ~/k8s-setup/manifests/oracle19c"
	@scp -r manifests/oracle19c/* $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/oracle19c/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/oracle19c/oracle19c.yaml"
	@echo "✅ Oracle 19c desplegado en el namespace 'databases'."
	@echo "   Puerto TNS expuesto: $(REMOTE_HOST):1521"
	@echo "   SID: ORCLCDB  |  PDB: ORCLPDB1"
	@echo "   Usuario: system  |  Contraseña: REDACTED_ORACLE_PASSWORD"

status-oracle:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n databases get statefulset,pods,svc,pvc -l app=oracle19c"

logs-oracle:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n databases logs -f oracle19c-0"

stop-oracle:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n databases scale statefulset oracle19c --replicas=0"
	@echo "🛑 Pod de Oracle 19c detenido (RAM y CPU liberados, datos preservados en PVC)."

start-oracle:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n databases scale statefulset oracle19c --replicas=1"
	@echo "▶️  Pod de Oracle 19c encendido."

remove-oracle:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl delete -f ~/k8s-setup/manifests/oracle19c/oracle19c.yaml"

# ==============================================================================
# ViniPlay - IPTV Streaming Web Player & TV Guide & DVR
# ==============================================================================
build-viniplay:
	@echo "🔨 Construyendo imagen viniplay:custom en $(REMOTE_HOST)..."
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p ~/k8s-setup/manifests/viniplay"
	@scp manifests/viniplay/Dockerfile manifests/viniplay/viniplay-subpath.patch $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/viniplay/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "podman build -t viniplay:custom -f ~/k8s-setup/manifests/viniplay/Dockerfile ~/k8s-setup/manifests/viniplay && podman save localhost/viniplay:custom | sudo k3s ctr images import -"
	@echo "✅ Imagen viniplay:custom construida e importada en k3s containerd."

deploy-viniplay:
	@echo "📦 Copiando y aplicando manifiesto de ViniPlay en $(REMOTE_HOST)..."
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p ~/k8s-setup/manifests/viniplay"
	@scp -r manifests/viniplay/* $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/viniplay/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/viniplay/viniplay.yaml"
	@echo "✅ ViniPlay desplegado en el namespace 'viniplay'."
	@echo "   Acceso Web:   http://$(REMOTE_HOST)/viniplay"
	@echo "   Persistencia: PVC /data (SQLite/Config) y PVC /dvr (Grabaciones)"
	@echo "   Primer uso:   Crear la cuenta de administrador al ingresar por primera vez."

status-viniplay:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n viniplay get deployment,pods,svc,ingress,pvc"

logs-viniplay:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n viniplay logs -l app=viniplay -c viniplay --tail=100 -f"

stop-viniplay:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n viniplay scale deployment viniplay --replicas=0"
	@echo "🛑 Pod de ViniPlay detenido (RAM y CPU liberados, datos preservados en PVC)."

start-viniplay:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n viniplay scale deployment viniplay --replicas=1"
	@echo "▶️  Pod de ViniPlay encendido."

remove-viniplay:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl delete -f ~/k8s-setup/manifests/viniplay/viniplay.yaml"

# ==============================================================================
# Aplicativos Desacoplados (Frontend y Backend)
# ==============================================================================
deploy-app:
	@echo "📦 Sincronizando y aplicando manifiestos de tasks-app en $(REMOTE_HOST)..."
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p ~/k8s-setup/manifests/app-task"
	@scp -r manifests/app-task/* $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/app-task/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/app-task/"
	@echo "✅ Aplicativos desplegados en namespace 'tasks-app'."
	@echo "   Frontend Web: http://$(REMOTE_HOST)/"
	@echo "   Backend REST: http://$(REMOTE_HOST)/api/"
	@echo "   NodePort:     http://$(REMOTE_HOST):30080"

deploy-backend:
	@scp manifests/app-task/01-namespace.yaml manifests/app-task/02-backend.yaml $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/app-task/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/app-task/01-namespace.yaml -f ~/k8s-setup/manifests/app-task/02-backend.yaml"

deploy-frontend:
	@scp manifests/app-task/01-namespace.yaml manifests/app-task/03-frontend.yaml $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/app-task/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/app-task/01-namespace.yaml -f ~/k8s-setup/manifests/app-task/03-frontend.yaml"

deploy-ingress:
	@scp manifests/app-task/04-ingress.yaml $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/app-task/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/app-task/04-ingress.yaml"

status-app:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n tasks-app get pods,svc,ingress -o wide"

logs-backend:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n tasks-app logs -l app=app-backend --tail=50 -f"

logs-frontend:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n tasks-app logs -l app=app-frontend --tail=50 -f"

remove-app:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl delete -f ~/k8s-setup/manifests/app-task/"

build-and-deploy-app:
	@cd ../scraping-outlook-web && ./desplegar-k8s.sh all

build-and-deploy-backend:
	@cd ../scraping-outlook-web && ./desplegar-k8s.sh backend

build-and-deploy-frontend:
	@cd ../scraping-outlook-web && ./desplegar-k8s.sh frontend

# ==============================================================================
# Aplicación de Prueba
# ==============================================================================
deploy-sample:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/sample-app/sample-app.yaml"
	@echo "App desplegada. Prueba en: http://$(REMOTE_HOST):30080 o http://$(REMOTE_HOST)/demo"

remove-sample:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl delete -f ~/k8s-setup/manifests/sample-app/sample-app.yaml"

# ==============================================================================
# Seguridad y Certificados SSL/TLS (HTTPS)
# ==============================================================================
generate-cert:
	@chmod +x manifests/tls/generate-cert.sh
	@manifests/tls/generate-cert.sh $(REMOTE_HOST)

deploy-tls:
	@echo "🔐 Desplegando configuración SSL/TLS en $(REMOTE_HOST)..."
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "mkdir -p ~/k8s-setup/manifests/tls"
	@scp -r manifests/tls/* $(REMOTE_USER)@$(REMOTE_HOST):~/k8s-setup/manifests/tls/
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/tls/traefik-tls.yaml"
	@echo "✅ Certificado TLS y Traefik TLSStore desplegados."
	@echo "   HTTPS activo en https://$(REMOTE_HOST)/viniplay"
	@echo "   HTTPS activo en https://$(REMOTE_HOST)/tasks"
	@echo "   HTTPS activo en https://$(REMOTE_HOST)/demo"

status-tls:
	@echo "🔍 Verificando TLSStore y Secret en $(REMOTE_HOST)..."
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl -n kube-system get tlsstores.traefik.io default && k3s kubectl -n kube-system get secret cluster-default-tls"
	@echo ""
	@echo "🌐 Probando conexión HTTPS a $(REMOTE_HOST)..."
	@curl -k -s -o /dev/null -w "   Status /viniplay/ : %{http_code}\n" https://$(REMOTE_HOST)/viniplay/ || true
	@curl -k -s -o /dev/null -w "   Status /tasks/    : %{http_code}\n" https://$(REMOTE_HOST)/tasks/ || true
	@curl -k -s -o /dev/null -w "   Status /demo      : %{http_code}\n" https://$(REMOTE_HOST)/demo || true
	@echo ""
	@echo "📜 Información del certificado en el puerto 443:"
	@echo | openssl s_client -connect $(REMOTE_HOST):443 -servername $(REMOTE_HOST) 2>/dev/null | openssl x509 -noout -subject -issuer -dates


