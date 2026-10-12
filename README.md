# 🚀 Ambiente Kubernetes (K3s) + Kubernetes Dashboard (IP Dinámica)

Este repositorio contiene los scripts y manifiestos automatizados para desplegar un entorno de **Kubernetes (K3s)** completo y un **Kubernetes Dashboard** con métricas en un servidor remoto o local, **sin IPs fijas en código (hardcoded)**.

La IP del host y las configuraciones de red se resuelven de forma **dinámica**.

---

## 📋 Arquitectura del Entorno

```
                     +---------------------------------------+
                     |   Tu PC Local (Estación de trabajo)   |
                     |   - kubectl local                     |
                     |   - deploy-remote.sh <IP_DEL_HOST>    |
                     +-------------------+-------------------+
                                         |
                       SSH / Red LAN     | (IP Dinámica / DHCP)
                                         v
+--------------------------------------------------------------------------------+
| Servidor Remoto (IP resuelta dinámicamente)                                    |
|                                                                                |
|  +--------------------------------------------------------------------------+  |
|  | K3s Kubernetes Engine                                                    |  |
|  |  • Control Plane + Worker en nodo único (Ligero y optimizado)            |  |
|  |  • Certificados TLS auto-configurados con la IP dinámica del servidor   |  |
|  |  • Metrics Server integrado (gráficas CPU / RAM en tiempo real)          |  |
|  |  • Ingress Controller (Traefik) integrado (Puertos 80 / 443)             |  |
|  |  • Storage Provisioner (Local-path) para volúmenes persistentes         |  |
|  +--------------------------------------------------------------------------+  |
|                                                                                |
|  +-----------------------------------+  +-----------------------------------+  |
|  | Kubernetes Dashboard              |  | Tus Aplicativos (Microservicios)  |  |
|  | • Web UI de monitorización        |  | • Backend / Frontend / DBs        |  |
|  | • Estado del nodo y cargas        |  | • NodePort o Ingress              |  |
|  | • https://<SERVER_IP>:30443       |  | • http://<SERVER_IP>:30080        |  |
|  +-----------------------------------+  +-----------------------------------+  |
+--------------------------------------------------------------------------------+
```

---

## ⚙️ ¿Cómo funciona la resolución dinámica de IP?

En [config.env](file:///home/johnny/Projects/desktop/ambiente-docker/config.env), la función `get_dynamic_ip` consulta dinámicamente la ruta de red de la interfaz principal activa (`ip route get 1.1.1.1` y `hostname -I`).

Puedes definir la IP del servidor de cualquiera de estas formas, **sin modificar el código fuente**:

1. **Parámetro por línea de comando:**
   ```bash
   ./deploy-remote.sh 192.168.18.228
   # O con make:
   make deploy HOST=192.168.18.228
   ```
2. **Variable de entorno:**
   ```bash
   REMOTE_HOST=192.168.18.228 ./deploy-remote.sh
   ```
3. **Interactivo:** Si ejecutas `./deploy-remote.sh` sin argumentos, el script te preguntará la IP en el momento.
4. **En el propio servidor:** Si ejecutas los scripts directamente en el servidor, este detecta su propia IP de red automáticamente y configura los certificados TLS (`--tls-san`) sin que tengas que escribir nada.

---

## 📁 Estructura del Proyecto

```text
ambiente-docker/
├── config.env                      # Configuración central y detección dinámica de IP
├── deploy-remote.sh                # Script maestro de despliegue remoto
├── docker-compose.oracle.yml       # Docker Compose para Oracle 19c
├── docker-compose.viniplay.yml     # Docker Compose para ViniPlay
├── Makefile                        # Automatización: make deploy-*, status-*, etc.
├── scripts/
│   ├── 01-install-k3s.sh           # Instalación de K3s con IP dinámica para TLS/SAN
│   ├── 02-install-dashboard.sh     # Despliegue de Kubernetes Dashboard (NodePort 30443)
│   ├── 03-create-admin-user.sh     # Creación de usuario administrador y token permanente
│   ├── 04-get-token.sh             # Consulta rápida del token de acceso
│   ├── 05-setup-local-kubectl.sh   # Configuración de kubectl en tu máquina local
│   └── uninstall-k3s.sh            # Desinstalador limpio de K3s
└── manifests/
    ├── dashboard/                  # Kubernetes Dashboard y RBAC
    ├── postgres/                   # PostgreSQL 16 con PVC y LoadBalancer
    ├── oracle19c/                  # Oracle Database 19c con PVC y LoadBalancer
    ├── app-task/                   # Backend Spring Boot 3 + Frontend Angular 18
    ├── viniplay/                   # ViniPlay IPTV Player, TV Guide & DVR
    └── sample-app/                 # Aplicación de prueba sin IPs fijas
```

---

## ⚡ Instalación

### Opción A: Despliegue desde tu PC hacia el servidor

```bash
cd /home/johnny/Projects/desktop/ambiente-docker
chmod +x deploy-remote.sh scripts/*.sh

# Desplegar pasando la IP de tu servidor (ej. 192.168.18.228):
./deploy-remote.sh 192.168.18.228
```

O si tu usuario SSH es diferente:

```bash
./deploy-remote.sh p3lud3v@192.168.18.228
```

El script realizará de forma automática:

1. Copia de scripts y manifiestos al servidor.
2. Instalación de K3s configurando la IP en los certificados TLS.
3. Despliegue del Dashboard en el puerto `30443`.
4. Creación del usuario `admin-user` con rol `cluster-admin` y generación de su token permanente.
5. Descarga de `kubeconfig` a tu máquina local para que puedas usar `kubectl` directamente.
6. Muestra en pantalla la URL del Dashboard y el token de acceso.

---

### Opción B: Ejecución Directa en el Servidor

Si prefieres conectarte por SSH al servidor y ejecutarlo allí:

```bash
# 1. En el servidor destino:
cd ~/ambiente-docker
chmod +x scripts/*.sh

# 2. Instalar K3s (detectará su propia IP automáticamente):
sudo ./scripts/01-install-k3s.sh

# 3. Instalar Dashboard:
./scripts/02-install-dashboard.sh

# 4. Crear usuario administrador y obtener token:
./scripts/03-create-admin-user.sh
```

---

## 🌐 Acceso al Kubernetes Dashboard

1. Abre tu navegador web e ingresa a:
   ```text
   https://<IP_DEL_SERVIDOR>:30443
   ```
2. **Aviso de Certificado:** Al ser un certificado autofirmado interno, el navegador mostrará una advertencia de seguridad. Haz clic en **Avanzado** -> **Continuar**.
3. **Autenticación:** Selecciona la opción **Token** y pega la clave generada.
4. Para volver a consultar el token en cualquier momento:
   ```bash
   ./scripts/04-get-token.sh
   # O desde tu PC local:
   make token
   ```

---

## 💻 Controlar el Cluster desde tu PC Local con `kubectl`

El instalador descarga y configura el archivo en tu PC local:

```bash
export KUBECONFIG=~/.kube/config-k3s-<IP_DEL_SERVIDOR>

# Probar comandos directamente:
kubectl get nodes -o wide
kubectl get pods -A
```

---

## 🚀 Desplegar y Consumir tus Aplicativos

### Desplegar aplicativo de prueba:

```bash
kubectl apply -f manifests/sample-app/sample-app.yaml
```

Formas de consumo:

- **NodePort:** `http://<IP_DEL_SERVIDOR>:30080`
- **Ingress Traefik:** `http://<IP_DEL_SERVIDOR>/demo`

---

## 🗄️ Bases de Datos Disponibles (Namespace `databases`)

### 1. PostgreSQL 16
- **Despliegue rápido:** `make deploy-postgres`
- **Puerto:** `5432`
- **Host LAN:** `192.168.18.228:5432`
- **Host Interno:** `postgres-svc.databases:5432`
- **Base de datos:** `app_task` | **Usuario:** `app_task` | **Password:** `REDACTED_POSTGRES_PASSWORD`
- **Volumen Persistente:** 10 GB (`local-path`)

### 2. Oracle Database 19c Enterprise
- **Despliegue rápido:** `make deploy-oracle`
- **Puerto TNS:** `1521` (y EM Express en `5500`)
- **Host LAN:** `192.168.18.228:1521`
- **Host Interno:** `oracle-svc.databases:1521`
- **SID:** `ORCLCDB` | **PDB / Service:** `ORCLPDB1`
- **Usuario:** `system` (o `sys as sysdba`) | **Password:** `REDACTED_ORACLE_PASSWORD`
- **JDBC Thin URL:** `jdbc:oracle:thin:@192.168.18.228:1521/ORCLPDB1`
- **Volumen Persistente:** 20 GB (`local-path` en `/opt/oracle/oradata`)
- **Memoria compartida /dev/shm:** 2 GB tmpfs configurados automáticamente.

---

## 📺 Streaming IPTV & Multimedia: ViniPlay (Namespace `viniplay`)

[ViniPlay](https://github.com/ardoviniandrea/ViniPlay) es un reproductor web IPTV avanzado con guía de programación EPG virtualizada, vista múltiple simultánea (Multi-View), grabación de emisiones en vivo (DVR / Timeshift con FFMPEG) y panel de administración.

- **Despliegue rápido:** `make deploy-viniplay`
- **Puerto Web:** `80` (vía Ingress Traefik)
- **Acceso LAN:** `http://192.168.18.228/viniplay` (o la IP dinámica de tu servidor)
- **Host Interno Kubernetes:** `viniplay-svc.viniplay:80`
- **Volúmenes Persistentes (PVC local-path):**
  - `/data` (5 GB): Base de datos SQLite (`viniplay.db`), configuración, perfiles de transcodificación y fuentes M3U/EPG.
  - `/dvr` (10 GB): Almacenamiento de grabaciones y reproducción retrasada (Timeshift).
- **Configuración Inicial:** Al abrir `http://192.168.18.228/viniplay` por primera vez, el sistema solicitará crear las credenciales del **Administrador inicial**. Luego, en la pestaña **Settings**, se añaden las listas M3U / EPG o credenciales XC.
- **Gestión mediante Makefile:**
  - Construir imagen personalizada con parches en K3s: `make build-viniplay`
  - Desplegar / actualizar en K3s: `make deploy-viniplay`
  - Ver estado: `make status-viniplay`
  - Ver logs en vivo: `make logs-viniplay`
  - Pausar pod (liberar CPU/RAM): `make stop-viniplay`
  - Reanudar pod: `make start-viniplay`
  - Desinstalar: `make remove-viniplay`
- **Alternativa Docker Compose:**
  ```bash
  docker compose -f docker-compose.viniplay.yml up -d
  ```
