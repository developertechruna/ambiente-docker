include config.env
export

# Permite sobreescribir el host destino desde el comando:
# Ejemplo: make deploy HOST=192.168.18.228
ifdef HOST
REMOTE_HOST := $(HOST)
endif

.PHONY: all help deploy token kubeconfig status deploy-sample remove-sample clean

all: help

help:
	@echo "=================================================================="
	@echo " Kubernetes (K3s) Cluster Manager"
	@echo " Host configurado dinámicamente: $(REMOTE_USER)@$(REMOTE_HOST)"
	@echo "=================================================================="
	@echo " Comandos disponibles:"
	@echo "   make deploy [HOST=x.x.x.x]   - Instala K3s y Dashboard"
	@echo "   make token [HOST=x.x.x.x]    - Muestra el token de acceso"
	@echo "   make kubeconfig [HOST=x.x.x] - Configura kubectl en esta PC local"
	@echo "   make status [HOST=x.x.x.x]   - Consulta el estado del cluster"
	@echo "   make deploy-sample           - Despliega app de prueba"
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

deploy-sample:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl apply -f ~/k8s-setup/manifests/sample-app/sample-app.yaml"
	@echo "App desplegada. Prueba en: http://$(REMOTE_HOST):30080 o http://$(REMOTE_HOST)/demo"

remove-sample:
	@ssh $(REMOTE_USER)@$(REMOTE_HOST) "k3s kubectl delete -f ~/k8s-setup/manifests/sample-app/sample-app.yaml"
