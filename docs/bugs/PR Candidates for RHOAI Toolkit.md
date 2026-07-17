[https://github.com/gymnatics/RHOAI-Toolkit](https://github.com/gymnatics/RHOAI-Toolkit) 

[https://github.com/hyogrin/RHOAI-Toolkit](https://github.com/hyogrin/RHOAI-Toolkit)

## **PR Candidates (Useful for upstream and issue-free)**

### **PR 1: Full Automation of Observability (High Value)**

* **Resolves current upstream pain point:** After installing COO (Cluster Observability Operator), the Observability dashboard displays a "Service Unavailable" error.  
* **File Changes:**  
  * `scripts/install-rhoai-34.sh`: Added `setup_observability_uiplugins()`, `setup_observability_perses()`, `create_thanos_proxy_secret()`, and modified the main execution flow.  
  * `lib/manifests/monitoring/persesdatasource-monitoring.yaml`: Added PersesDatasource manifest.  
* **Key Components:** COO \+ UIPlugin (`monitoring.perses.enabled: true`) \+ Perses Server \+ NetworkPolicy \+ `service-ca` ConfigMap \+ Thanos proxy secret.  
* **Note:** Upstream currently suffers from the exact same issue where the dashboard fails if you only install COO using `--enable-observability`.

### **PR 2: Automatic Deployment of Grafana GPU/vLLM Dashboards (High Value)**

* **Enables instant viewing** of GPU and vLLM metrics right after deployment.  
* **File Changes:**  
  * `scripts/install-rhoai-34.sh`: Added `deploy_grafana_monitoring()` function.  
  * `lib/manifests/monitoring/consolelinks-grafana.yaml`: Added OpenShift Console menu link.  
  * `lib/manifests/monitoring/odhapplication-grafana.yaml`: Added RHOAI dashboard tile.  
* **Key Components:** Prometheus token → Grafana datasource → DCGM/vLLM dashboard import → Console links.  
* **Note:** The manifest exists in the upstream repository, but the actual deployment logic is missing.

### **PR 3: Automatic Integration of MLflow with PostgreSQL (Medium Value)**

* **Switches storage backend** from SQLite to PostgreSQL if a PostgreSQL instance is available.  
* **File Changes:**  
  * `scripts/install-rhoai-34.sh`: Enhanced `create_mlflow_server()`.  
* **Key Components:** If an existing MaaS PostgreSQL instance is detected, it automatically creates the MLflow database and integrates it. If not, it gracefully falls back to the upstream approach (SQLite \+ PVC).

### **PR 4: Automatic Deployment of PostgreSQL \+ MaaS DB (High Value)**

* **Eliminates the need** to manually create databases when installing MaaS.  
* **File Changes:**  
  * `lib/manifests/maas/postgres-deployment.yaml`: Added In-cluster PostgreSQL Deployment.  
  * `lib/manifests/maas/maas-db-config.yaml.tmpl`: Added `maas-db-config` secret template.  
  * `scripts/install-rhoai-34.sh`: Updated `setup_maas_database()`.

### **PR 5: Let's Encrypt TLS Automation \+ Gateway Integration (Medium Value)**

* **Streamlines the entire pipeline** from Certificate generation → Gateway TLS → MaaS endpoint in a single flow.  
* **File Changes:**  
  * `scripts/setup-letsencrypt-tls.sh`: Added Let's Encrypt \+ Route53 DNS-01 automation.  
  * `lib/manifests/tls/letsencrypt-clusterissuer.yaml.tmpl`: Added ClusterIssuer template.  
  * `lib/manifests/tls/wildcard-certificate.yaml.tmpl`: Added Wildcard certificate template.  
  * `scripts/install-rhoai-34.sh`: Added Strategy 0 to `create_gateway_tls_secret()`.

### **PR 6: MCP Server Manifests \+ Deployment Script (Medium Value)**

* **File Changes:**  
  * `lib/manifests/mcp/*.yaml`: Added manifests for 7 MCP servers.  
  * `scripts/deploy-mcp-servers.sh`: Added deployment script for MCP servers.

