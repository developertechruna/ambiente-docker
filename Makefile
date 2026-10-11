SHELL := /bin/bash

# Leer variables evaluadas dinámicamente por bash desde config.env
REMOTE_HOST ?= $(shell bash -c 'source ./config.env 2>/dev/null && echo $$REMOTE_HOST')
REMOTE_USER ?= $(shell bash -c 'source ./config.env 2>/dev/null && echo $$REMOTE_USER')

# Permite sobreescribir el host destino desde el comando:
# Ejemplo: make deploy HOST=192.168.18.228 o make deploy-postgres HOST=192.168.18.228
ifdef HOST
REMOTE_HOST := $(HOST)
endif

.PHONY: all help deploy token kubeconfig status deploy-sample remove-sample deploy-postgres status-postgres remove-postgres clean

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
	@echo " Base de Datos (PostgreSQL):"
	@echo "   make deploy-postgres         - Despliega PostgreSQL con PVC (10GB) y puerto 5432"
	@echo "   make status-postgres         - Consulta estado, Pods y PVC de Postgres"
	@echo "   make remove-postgres         - Elimina el despliegue de Postgres"
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

remove-postgres:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl delete -f ~/k8s-setup/manifests/postgres/postgres.yaml"

deploy-sample:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/sample-app/sample-app.yaml"
	@echo "App desplegada. Prueba en: http://$(REMOTE_HOST):30080 o http://$(REMOTE_HOST)/demo"

remove-sample:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl delete -f ~/k8s-setup/manifests/sample-app/sample-app.yaml"
