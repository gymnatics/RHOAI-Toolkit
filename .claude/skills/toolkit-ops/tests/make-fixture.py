#!/usr/bin/env python3
"""Generate fixture-35.json: an RHOAI 3.5.2 cluster on OCP 4.21 with deliberate faults.

Expected findings (asserted by run-tests.sh):
  - dsc/mcplifecycleoperator-ocp FAIL  (Managed on OCP 4.21; docs need 4.22+)
  - dsc/ogx FAIL                        (ogxReady=False)
  - hwprofile/gpu-tolerations FAIL      (bad-gpu profile uses operator Equal)
  - dashboard/flag-agentsCatalog WARN   (DP flag on)
  - nb:maas-ratelimit-demo wb:rate-limit-testing-env-drift FAIL (MODEL_ID in ConfigMap, not in pod)
  - demo:open-webui-demo PASS; demo:n8n-demo SKIP (not deployed)
"""
import json
import sys


def meta(name, ns=None, **kw):
    m = {"name": name, **kw}
    if ns: m["namespace"] = ns
    return m


def cond(t, s="True", msg="", reason=""):
    return {"type": t, "status": s, "message": msg, "reason": reason}


def node(name, cpu, mem, gpu=0, worker=True):
    labels = {"node-role.kubernetes.io/worker": ""} if worker else {"node-role.kubernetes.io/master": ""}
    n = {"kind": "Node", "metadata": meta(name, labels=labels),
         "spec": {}, "status": {"capacity": {"cpu": str(cpu), "memory": f"{mem}Gi"},
                                "allocatable": {"cpu": str(cpu), "memory": f"{mem}Gi"},
                                "conditions": [cond("Ready")]}}
    if gpu:
        n["status"]["allocatable"]["nvidia.com/gpu"] = str(gpu)
        n["metadata"]["labels"]["nvidia.com/gpu.present"] = "true"
        n["spec"]["taints"] = [{"key": "nvidia.com/gpu", "effect": "NoSchedule"}]
    return n


def sub(pkg, ns, channel, csv):
    return [{"kind": "Subscription", "metadata": meta(pkg, ns), "spec": {"name": pkg, "channel": channel},
             "status": {"installedCSV": csv}},
            {"kind": "ClusterServiceVersion", "metadata": meta(csv, ns),
             "spec": {"displayName": "Red Hat OpenShift AI" if pkg == "rhods-operator" else pkg,
                      "version": csv.split(".v")[-1]}, "status": {"phase": "Succeeded"}}]


def deploy(name, ns, ready=1, replicas=1):
    return {"kind": "Deployment", "metadata": meta(name, ns), "spec": {"replicas": replicas},
            "status": {"readyReplicas": ready}}


def ns(name, **labels):
    return {"kind": "Namespace", "metadata": meta(name, labels=labels)}


R = []
R += [node("master-0", 8, 32, worker=False), node("worker-0", 16, 64), node("worker-1", 16, 64),
      node("gpu-0", 16, 64, gpu=1)]
R += [{"kind": "ClusterVersion", "metadata": meta("version"),
       "status": {"desired": {"version": "4.21.5"}, "conditions": [cond("Available"), cond("Failing", "False"), cond("Progressing", "False")]}},
      {"kind": "ClusterOperator", "metadata": meta("ingress"), "status": {"conditions": [cond("Available"), cond("Degraded", "False")]}},
      {"kind": "OAuth", "metadata": meta("cluster"), "spec": {"identityProviders": [{"name": "htpasswd"}]}},
      {"kind": "StorageClass", "metadata": meta("gp3-csi", annotations={"storageclass.kubernetes.io/is-default-class": "true"})},
      {"kind": "ConfigMap", "metadata": meta("cluster-monitoring-config", "openshift-monitoring"), "data": {"config.yaml": "enableUserWorkload: true\n"}},
      {"kind": "Ingress", "metadata": meta("cluster"), "spec": {"domain": "apps.mock.test"}}]
for n in ["redhat-ods-operator", "redhat-ods-applications", "redhat-ai-gateway-infra", "openshift-ingress",
          "kuadrant-system", "models-as-a-service", "open-webui", "seaweedfs", "openshift-monitoring"]:
    R.append(ns(n))
R.append(ns("maas-ratelimit-demo", **{"opendatahub.io/dashboard": "true"}))
R.append(ns("team-queue", **{"kueue.openshift.io/managed": "true"}))
R += sub("rhods-operator", "redhat-ods-operator", "stable-3.5", "rhods-operator.v3.5.2")
R += sub("openshift-cert-manager-operator", "cert-manager-operator", "stable-v1", "cert-manager-operator.v1.18.0")
R += sub("servicemeshoperator3", "openshift-operators", "stable", "servicemeshoperator3.v3.2.0")
R += sub("leader-worker-set", "openshift-lws-operator", "stable-v1.0", "leader-worker-set.v1.0.0")
R += sub("rhcl-operator", "openshift-operators", "stable", "rhcl-operator.v1.4.2")
R += sub("nfd", "openshift-nfd", "stable", "nfd.v4.21.0")
R += sub("gpu-operator-certified", "nvidia-gpu-operator", "v25.10", "gpu-operator-certified.v25.10.0")
R += sub("kueue-operator", "openshift-operators", "stable-v1.3", "kueue-operator.v1.3.0")
R.append({"kind": "CustomResourceDefinition", "metadata": meta("llminferenceservices.serving.kserve.io")})
for c in ["maassubscriptions", "maasauthpolicies", "maasmodelrefs", "maastenantconfigs"]:
    R.append({"kind": "CustomResourceDefinition", "metadata": meta(f"{c}.maas.opendatahub.io")})
R.append({"kind": "DSCInitialization", "metadata": meta("default-dsci"), "status": {"phase": "Ready"}})
comps = {"dashboard": "Managed", "workbenches": "Managed", "aipipelines": "Managed", "kserve": "Managed",
         "aigateway": "Managed", "kueue": "Unmanaged", "ray": "Managed", "trainer": "Removed",
         "trainingoperator": "Removed", "modelregistry": "Managed", "trustyai": "Managed",
         "feastoperator": "Managed", "ogx": "Managed", "mcplifecycleoperator": "Managed", "mlflowoperator": "Managed"}
spec_comps = {k: {"managementState": v} for k, v in comps.items()}
spec_comps["aigateway"]["modelsAsAService"] = {"managementState": "Managed"}
R.append({"kind": "DataScienceCluster", "metadata": meta("default-dsc"), "spec": {"components": spec_comps},
          "status": {"phase": "Ready",
                     "installedComponents": {k: v == "Managed" for k, v in comps.items()},
                     "conditions": [cond("ReconcileComplete"), cond("Ready"), cond("DashboardReady"),
                                    cond("OgxReady", "False", "OGXServer CRD not established"),
                                    cond("AIGatewayReady"), cond("ModelsAsAServiceReady")]}})
R.append({"kind": "Pod", "metadata": meta("rhods-operator-abc", "redhat-ods-operator"),
          "status": {"phase": "Running", "containerStatuses": [{"name": "m", "ready": True, "restartCount": 0}]}})
patch_flags = {"genAiStudio": True, "modelAsService": True, "disableModelRegistry": False, "disableModelCatalog": False,
               "disableKServeMetrics": False, "disableLMEval": False, "disableKueue": False, "mcpCatalog": True,
               "agentsCatalog": True, "agentOps": True, "agentConfigManagement": True, "gpuaas": True}
R.append({"kind": "OdhDashboardConfig", "metadata": meta("odh-dashboard-config", "redhat-ods-applications"),
          "spec": {"dashboardConfig": patch_flags}})
R.append({"kind": "Gateway", "metadata": meta("data-science-gateway", "openshift-ingress"),
          "spec": {"listeners": [{"hostname": "rh-ai.apps.mock.test"}]}, "status": {"conditions": [cond("Programmed")]}})
R.append({"kind": "Gateway", "metadata": meta("maas-default-gateway", "openshift-ingress"),
          "spec": {"listeners": [{"hostname": "maas.apps.mock.test"}]}, "status": {"conditions": [cond("Programmed")]}})
gpu_ident = [{"identifier": "nvidia.com/gpu"}]
R.append({"kind": "HardwareProfile", "metadata": meta("gpu-profile", "redhat-ods-applications"),
          "spec": {"identifiers": gpu_ident, "scheduling": {"node": {"tolerations": [{"key": "nvidia.com/gpu", "operator": "Exists", "effect": "NoSchedule"}]}}}})
R.append({"kind": "HardwareProfile", "metadata": meta("bad-gpu", "redhat-ods-applications"),
          "spec": {"identifiers": gpu_ident, "scheduling": {"node": {"tolerations": [{"key": "nvidia.com/gpu", "operator": "Equal", "value": "true"}]}}}})
R += [deploy("seaweedfs", "seaweedfs"), deploy("maas-api", "redhat-ai-gateway-infra"), deploy("open-webui", "open-webui")]
R.append({"kind": "Route", "metadata": meta("open-webui", "open-webui"), "spec": {"host": "open-webui.ok.test"}})
# NeMo Guardrails (selfcheck) + lemonade-stand whose chat fails with 401 (expired token)
R.append(ns("nemo-guardrails-demo"))
R.append({"kind": "NemoGuardrails", "metadata": meta("nemo-quickstart", "nemo-guardrails-demo"), "status": {"phase": "Ready"}})
R.append({"kind": "Secret", "metadata": meta("api-token-secret", "nemo-guardrails-demo"), "data": {"token": "dA=="}})
R.append({"kind": "ConfigMap", "metadata": meta("nemo-quickstart-config", "nemo-guardrails-demo"),
          "data": {"config.yaml": "models:\n  - type: main\n    parameters:\n      model_name: \"qwen3-8b\"\n"}})
R.append({"kind": "Route", "metadata": meta("nemo-quickstart", "nemo-guardrails-demo"), "spec": {"host": "nemo.ok.test"}})
R.append(deploy("lemonade-stand", "nemo-guardrails-demo"))
R.append({"kind": "Route", "metadata": meta("lemonade-stand", "nemo-guardrails-demo"), "spec": {"host": "lemonade.ok.test"}})
R.append({"kind": "Secret", "metadata": meta("maas-db-config", "redhat-ai-gateway-infra"), "data": {"DB_CONNECTION_URL": "cG9zdGdyZXM="}})
R.append({"kind": "MaasTenantConfig", "metadata": meta("default-tenant", "models-as-a-service"), "status": {"conditions": [cond("Ready")]}})
R.append({"kind": "Kuadrant", "metadata": meta("kuadrant", "kuadrant-system"), "status": {"conditions": [cond("Ready")]}})
R.append({"kind": "Authorino", "metadata": meta("authorino", "kuadrant-system"), "spec": {"listener": {"tls": {"enabled": True}}}})
R.append({"kind": "MaaSModelRef", "metadata": meta("simulator", "maas-models"), "status": {"conditions": [cond("Ready")]}})
R.append({"kind": "LLMInferenceService", "metadata": meta("simulator", "maas-models", labels={"maas.opendatahub.io/model": "true"}),
          "spec": {"model": {"name": "facebook/opt-125m"}}, "status": {"conditions": [cond("Ready")], "url": "https://maas.apps.mock.test/maas-models/simulator"}})
# Workbench with env drift
R.append({"kind": "Notebook", "metadata": meta("rate-limit-testing", "maas-ratelimit-demo",
          annotations={"opendatahub.io/hardware-profile-name": "default-profile"}),
          "spec": {"template": {"spec": {"containers": [{"image": "image-registry.openshift-image-registry.svc:5000/redhat-ods-applications/s2i-generic-data-science-notebook:3.4"}]}}}})
R.append({"kind": "Pod", "metadata": meta("rate-limit-testing-0", "maas-ratelimit-demo"), "status": {"phase": "Running", "conditions": [cond("Ready")]}})
R.append({"kind": "ConfigMap", "metadata": meta("notebook-env", "maas-ratelimit-demo"),
          "data": {"NAMESPACE": "maas-ratelimit-demo", "MAAS_ENDPOINT": "maas.apps.mock.test", "MODEL_ID": "facebook/opt-125m",
                   "MODEL_NAME": "simulator", "MODEL_NAMESPACE": "maas-models", "MAAS_ROUTING": "path"}})

# Live-cluster regressions (2026-11-10): stopped GPU instance, stopped model, restart-only pod, DSPA condition
stopped = node("gpu-1", 16, 64, gpu=1)
stopped["status"]["conditions"] = [cond("Ready", "Unknown", "Kubelet stopped posting node status.", "NodeStatusUnknown")]
R.append(stopped)
R.append({"kind": "Machine", "metadata": meta("gpu-1-machine", "openshift-machine-api",
          annotations={"machine.openshift.io/instance-state": "stopped"}), "status": {"nodeRef": {"name": "gpu-1"}}})
R.append({"kind": "InferenceService", "metadata": meta("bge-m3", "maas-models", annotations={"serving.kserve.io/stop": "true"}),
          "status": {"conditions": [cond("Ready", "False", "Stopped", "Stopped")]}})
R.append({"kind": "Pod", "metadata": meta("dashboard-abc", "redhat-ods-applications"),
          "status": {"phase": "Running", "containerStatuses": [{"name": "d", "ready": True, "restartCount": 42,
                     "lastState": {"terminated": {"reason": "OOMKilled"}}}]}})
R.append({"kind": "Pod", "metadata": meta("qwen-new", "maas-models"), "spec": {"containers": [{"resources": {"requests": {"nvidia.com/gpu": "1"}}}]},
          "status": {"phase": "Pending"}})
R.append({"kind": "Pod", "metadata": meta("model-training-0", "financial-loan-demo"), "spec": {"nodeName": "gpu-0", "containers": [{"resources": {"limits": {"nvidia.com/gpu": "1"}}}]},
          "status": {"phase": "Running"}})
R.append({"kind": "Pod", "metadata": meta("qwen-old", "maas-models"), "spec": {"nodeName": "gpu-0", "containers": [{}]},
          "status": {"phase": "Running", "containerStatuses": [{"name": "c", "state": {"terminated": {"reason": "ContainerStatusUnknown"}}}]}})
R.append(ns("pipeline-demo"))
R.append({"kind": "DataSciencePipelinesApplication", "metadata": meta("pipelines-definition", "pipeline-demo"),
          "status": {"conditions": [cond("Ready", "False", "Could not connect to minio", "MinimumReplicasAvailable")]}})

# Feast workbench: healthy, env complete -> safe notebooks executable
R.append(ns("feast-demo", **{"opendatahub.io/dashboard": "true"}))
R.append({"kind": "Notebook", "metadata": meta("feature-store", "feast-demo"),
          "spec": {"template": {"spec": {"containers": [{"image": "x/jupyter-datascience:2025.2"}]}}}})
R.append({"kind": "Pod", "metadata": meta("feature-store-0", "feast-demo"), "status": {"phase": "Running", "conditions": [cond("Ready")]}})
R.append({"kind": "ConfigMap", "metadata": meta("notebook-env", "feast-demo"),
          "data": {"NAMESPACE": "feast-demo", "FEAST_PROJECT": "banking", "FEAST_NAME": "banking"}})
R.append({"kind": "FeatureStore", "metadata": meta("banking", "feast-demo", labels={"feature-store-ui": "enabled"}),
          "spec": {"services": {"registry": {"local": {"server": {"restAPI": True}}}}}})

fixture = {
    "whoami": "admin", "can_i": "yes", "resources": R,
    "exec": {"maas-ratelimit-demo/rate-limit-testing-0": {
        "env": "NAMESPACE=maas-ratelimit-demo\nMAAS_ENDPOINT=maas.apps.mock.test\nMODEL_NAME=simulator\nMODEL_NAMESPACE=maas-models\nMAAS_ROUTING=path",
        "git": "4de6f4a 2026-10-20", "missing_modules": [], "missing_files": [], "url_code": "401"},
        "feast-demo/feature-store-0": {"env": "NAMESPACE=feast-demo\nFEAST_PROJECT=banking\nFEAST_NAME=banking",
        "git": "4de6f4a 2026-10-20", "exec_rc": 0}},
}
json.dump(fixture, open(sys.argv[1] if len(sys.argv) > 1 else "fixture-35.json", "w"), indent=1)
print(f"{len(R)} resources")
