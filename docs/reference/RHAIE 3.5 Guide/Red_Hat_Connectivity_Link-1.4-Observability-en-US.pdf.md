# Red_Hat_Connectivity_Link-1.4-Observability-en-US.pdf

- Red Hat Connectivity Link 1.4

# Observability

Observe and monitor Gateways, APIs, and applications on OpenShift 

Last Updated: 2026-08-24

### Red Hat Connectivity Link 1.4 Observability

Observe and monitor Gateways, APIs, and applications on OpenShift

Legal Notice 

Copyright © Red Hat. 

Except as otherwise noted below, the text of and illustrations in this documentation are licensed by Red Hat under the Creative Commons Attribution–Share Alike 3.0 Unported license . If you distribute this document or an adaptation of it, you must provide the URL for the original version. 

Red Hat, as the licensor of this document, waives the right to enforce, and agrees not to assert, Section 4d of CC-BY-SA to the fullest extent permitted by applicable law. 

Red Hat, the Red Hat logo, JBoss, Hibernate, and RHCE are trademarks or registered trademarks of Red Hat, LLC. or its subsidiaries in the United States and other countries. 

Linux ® is the registered trademark of Linus Torvalds in the United States and other countries. 

XFS is a trademark or registered trademark of Hewlett Packard Enterprise Development LP or its subsidiaries in the United States and other countries. 

The OpenStack ® Word Mark and OpenStack logo are trademarks or registered trademarks of the Linux Foundation, used under license. 

All other trademarks are the property of their respective owners. 

Abstract 

This document gives you the instructions to set up observability features for Connectivity Link and the MCP gateway.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

CHAPTER 1. CONNECTIVITY LINK OBSERVABILITY 1.1. CONNECTIVITY LINK OBSERVABILITY 1.2. CONFIGURE YOUR OBSERVABILITY MONITORING STACK 1.3. ENABLE OBSERVABILITY MONITORING IN CONNECTIVITY LINK 1.4. OBSERVABILITY DASHBOARDS AND ALERTS CONFIGURATION 

1.4.1. Platform engineer Grafana dashboard 1.4.2. Application developer Grafana dashboard 1.4.3. Business user Grafana dashboard 1.4.4. Grafana dashboards available to import 1.4.5. Import dashboards in Grafana 1.4.6. About importing dashboards automatically in OpenShift Container Platform 1.4.7. About configuring Prometheus alerts 

1.5. CONNECTIVITY LINK TRACING 1.5.1. Correlating control plane and data plane traces 1.5.2. Control-plane tracing environment variables 1.5.3. Configure data plane tracing in Connectivity Link 1.5.4. Data-plane tracing configuration fields 1.5.5. Troubleshoot by using traces and logs 1.5.6. View rate-limit logging with trace IDs 

1.6. CONFIGURE ACCESS LOGS 1.6.1. Filter access logs 1.6.2. Common access log format variables 

1.7. ABOUT USING ACCESS LOGS FOR REQUEST CORRELATION 1.7.1. Set up access log and tracing correlation 

1.8. ADDITIONAL RESOURCES 

CHAPTER 2 OBSERVE MCP GATEWAY CONNECTIONS 2.1. ENABLE RED HAT BUILD OF OPENTELEMETRY FOR THE MCP GATEWAY 

2.1.1. MCP gateway router spans for observability 2.2. THE MCP GATEWAY AUDIT TRAIL 

2.2.1. Configure an AuthPolicy with identity injection 2.2.2. Verify AuthPolicy identity injection 2.2.3. Add a custom audit log provider 

2.2.3.1. Custom audit log provider fields 2.2.4. Enable the access log on the Gateway pods workload 2.2.5. Verify your audit trail 2.2.6. Use an audit trail without authentication 

2.3. ADDITIONAL RESOURCES 

3 3 3 4 5 5 6 6 6 6 7 7 8 8 8 9 

13 14 14 15 17 18 19 19 21 

22 22 24 27 27 30 31 32 33 35 36 37 

### CHAPTER 1. CONNECTIVITY LINK OBSERVABILITY

You can use the Connectivity Link observability features to observe and monitor your gateways, applications, and APIs on OpenShift Container Platform. 

1.1. CONNECTIVITY LINK OBSERVABILITY 

Connectivity Link uses component metrics, Gateway API state metrics, and standard Envoy metrics to build template dashboards and alerts. Envoy is part of OpenShift Service Mesh. In this case, it runs as a gateway deployment. 

You can download community-based templates to integrate with Grafana, Prometheus, and Alertmanager deployments. You can also use those templates as starting points that you can change for your specific needs. Use the secure images available in the Red Hat Catalog at: Red Hat Connectivity Link. 

Connectivity Link includes the following observability capabilities: 

Metrics: Prometheus metrics for monitoring gateway and policy performance 

Tracing: Distributed tracing with Red Hat build of OpenTelemetry support for request flows 

Access Logs: Envoy access logs with request correlation and structured logging 

Dashboards: Pre-built Grafana dashboards for visualization 

1.2. CONFIGURE YOUR OBSERVABILITY MONITORING STACK 

You can prepare your monitoring stack to give yourself insight into your gateways, applications, and APIs by setting up dashboards and alerts on your OpenShift Container Platform cluster. You must configure your stack on each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

The example dashboards and alerts for observing Connectivity Link functionality use low-level CPU and network metrics from the user monitoring stack in OpenShift Container Platform and resource-state metrics from Gateway API and Connectivity Link resources. The user monitoring stack in OpenShift Container Platform is based on the Prometheus open source project. 

IMPORTANT 

The following procedure is an example only and is not intended for production use. 

Prerequisites 

You installed Connectivity Link. 

**You set up metrics, such as prometheus. **

You installed and configured Grafana on your OpenShift Container Platform cluster. 

You cloned the Kuadrant Operator GitHub repository . 

Procedure 

1. Verify that the user workload monitoring is configured correctly in your OpenShift Container Platform cluster by running the following command: 

Example output 

2. Install the Connectivity Link, Gateway, and Grafana component metrics and configuration as follows: 

3. From the root directory of your Kuadrant Operator repository, configure the OpenShift **Container Platform thanos-query instance as a data source in Grafana by using the following **example: 

4. Configure the example Grafana dashboards by running the following command: 

1.3. ENABLE OBSERVABILITY MONITORING IN CONNECTIVITY LINK 

By enabling observability monitoring, you can view context, historical trends, and alerts based on the metrics you configure. After you have configured your monitoring stack, use this step to expose metrics endpoints, deploy monitoring resources, and configure the Envoy gateway. 

When you enable observability monitoring, the following events occur: 

**Connectivity Link creates ServiceMonitor and PodMonitor custom resource definitions (CRDs) **for its components in the namespace where Connectivity Link is. 

A single set of monitors is created in each gateway namespace to scrape metrics from any gateways. 

Monitors also scrape metrics from the corresponding gateway system namespace, generally the **istio-system namespace. **

You can delete and re-create monitors as required. Monitors are only ever created or deleted, and not **updated or reverted. The following procedure is optional. You can create your own ServiceMonitor or PodMonitor definitions, or configure prometheus metrics directly. **

$ oc get configmap cluster-monitoring-config -n openshift-monitoring -o jsonpath='{.data.config\.yaml}'|grep enableUserWorkload 

`enableUserWorkload: true`. 

$ oc apply -k https://github.com/Kuadrant/kuadrant-operator/config/install/configure/observability?ref=v1.2.0 

TOKEN="Bearer $(oc whoami -t)" HOST="$(oc -n openshift-monitoring get route thanos-querier -o jsonpath='https://{.status.ingress[].host}')" echo "TOKEN=$TOKEN" > config/observability/openshift/grafana/datasource.env echo "HOST=$HOST" >> config/observability/openshift/grafana/datasource.env oc apply -k config/observability/openshift/grafana 

$ oc apply -k https://github.com/Kuadrant/kuadrant-operator/examples/dashboards? ref=v1.4.1 

IMPORTANT 

To use Connectivity Link observability dashboards, you must enable observability on each OpenShift Container Platform cluster that Connectivity Link runs on. 

Prerequisites 

You installed Connectivity Link. 

You have administrator access to your OpenShift Container Platform cluster. 

You configured observability metrics. 

Procedure 

To enable default observability for Connectivity Link and any gateways, set **spec.observability.enable parameter value to true in your Kuadrant custom resource (CR): **

**Example Kuadrant CR **

**You can also set the spec.observability.enable to false and create your own ServiceMonitor or PodMonitor definitions, or configure Prometheus directly. **

Verification 

Check the created monitors by running the following command: 

Additional resources 

ServiceMonitor API reference 

PodMonitor API reference 

1.4. OBSERVABILITY DASHBOARDS AND ALERTS CONFIGURATION 

Connectivity Link includes starting points for monitoring your Connectivity Link deployment with ready-to-use example dashboards and alerts. You can customize these dashboards and alerts to fit your environment. 

Dashboards are organized with different metrics for different use cases. 

1.4.1. Platform engineer Grafana dashboard 

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant metadata:   name: kuadrant-sample spec:   observability:     enable: true *# ... *

$ oc get servicemonitor,podmonitor -A -l kuadrant.io/observability=true 

The platform engineer dashboard displays the following details: 

Policy compliance and governance. 

Resource consumption 

Error rates 

Request latency and throughput 

Multi-window, multi-burn alert templates for API error rates and latency 

Multicluster split 

1.4.2. Application developer Grafana dashboard 

The application developer dashboard is less focused on policies than the platform engineer dashboard and is more focused on APIs and applications. For example: 

Request latency and throughput per API 

Total requests and error rates by API path 

1.4.3. Business user Grafana dashboard 

The business user dashboard includes the following details: 

Requests per second per API 

Increase or decrease in rates of API usage over specified times 

1.4.4. Grafana dashboards available to import 

The Connectivity Link example dashboards are uploaded to the Grafana dashboards website. You can import the following dashboards into your Grafana deployment on OpenShift Container Platform: 

Table 1.1. Connectivity Link example dashboards in Grafana 

Name Dashboard ID 

App Developer dashboard 21538 

Platform Engineer dashboard 20982 

Business User dashboard 20981 

DNS Operator dashboard 22695 

1.4.5. Import dashboards in Grafana 

You can manually select and important dashboards to Grafana to conduct rapid prototyping or emergency troubleshooting, test community dashboards, or perfect a dashboard that you intend to automate for another team. 

IMPORTANT 

You must perform these steps on each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

Prerequisites 

You configured your monitoring stack and other observability resources as needed. 

You installed Connectivity Link. 

You have administrator access to a running OpenShift Container Platform cluster. 

Procedure 

Click Dashboards > New > Import, and use one of the following options: 

Upload a dashboard JSON file. 

Enter a dashboard ID obtained from the Grafana dashboards website. 

Enter JSON content directly. For more information, see the Grafana documentation on how to import dashboards . 

1.4.6. About importing dashboards automatically in OpenShift Container Platform 

Automating the import of observability dashboards can give you more consistency, version control, and operational velocity. Automation gives you the benefits of monitoring-as-code, and helps keep Operators updated, clusters identical, and supports multi-tenancy. 

**You can use a GrafanaDashboard resource to reference a ConfigMap. **Data sources are configured as template variables, automatically integrating with your existing data sources. The metrics for these dashboards are sourced from Prometheus. 

IMPORTANT 

**For some example dashboard panels to work correctly, HTTPRoute objects in Connectivity Link must include a service and deployment label with a value that **matches the name of the service and deployment being routed to. For example, **service=my-app and deployment=my-app. This allows low-level Istio and Envoy **metrics to be added to Gateway API state metrics. 

If you do not want to use the GUI, you can automate dashboard provisioning in Grafana by **adding JSON files to a ConfigMap object that you must mount at /etc/grafana/provisioning/dashboards. **

1.4.7. About configuring Prometheus alerts 

You can configure Prometheus alerts in OpenShift Container Platform is a proactive way to tune alerts so that you can ensure platform stability. For example, you can set alert triggers for automated incident detection, usage, and cluster health. 

**You can integrate the Connectivity Link example alerts into Prometheus as PrometheusRule **resources, and then adjust the alert thresholds to suit your specific operational needs. 

For details on how to configure Prometheus alerts, see Configuring alerts and notifications for user workload monitoring. 

Service Level Objective (SLO) alerts generated by using the Sloth GitHub project are also included. You can use these alerts to integrate with the SLO Grafana dashboard, which uses generated labels to comprehensively overview your SLOs. 

1.5. CONNECTIVITY LINK TRACING 

Connectivity Link supports tracing at both the control plane and data-plane levels. Connectivity Link exports control-plane traces to your OpenTelemetry Collector so that you can observe reconciliation loops and internal operations. This is useful for debugging controller behavior, understanding operator performance, and tracking policy lifecycle events. 

Data-plane tracing traces actual user requests through the gateway and policy enforcement **components. You can see request flows through Istio, Authorino, Limitador, and the wasm-shim **module. Data-plane tracing is useful for debugging request-level issues and policy enforcement. 

**To use tracing, you must configure both types of tracing. You must configure the kuadrant custom **resource (CR) for the data plane. For control plane tracing, you must configure each operating **component separately, such as the kuadrant-operator, authorino-operator, and limitador-operator **deployments. This configuration sends traces to the same collector, providing a complete view of your Connectivity Link system from policy reconciliation to request processing. 

1.5.1. Correlating control plane and data plane traces 

Even though control plane and data plane traces are separate, you can correlate them. For example, **create a RateLimitPolicy to understand how traces work together to show all events. **

**Create a RateLimitPolicy at 15:30:00, then view the control plane trace to see the following **events: 

**Policy reconciliation completed at 15:30:05. **

Limitador configuration updated. 

**wasm-shim configuration updated. **

**Next, send a test request at 15:30:10, then view data plane trace to see the following events: **

**Request processed through the wasm-shim module. **

Rate limit check sent to Limitador. 

Response returned. 

You can use a similar pattern of action for any events that you want to correlate manually. This type of correlation is useful in development environments. 

1.5.2. Control-plane tracing environment variables 

You can enable control tracing in Connectivity Link by setting OpenTelemetry environment variables in the deployment. The method for setting the variables depends on your deployment approach, for example, whether you used the Operator Lifecycle Manager (OLM) or YAML manifests. 

**Control plane traces appear under the service name kuadrant-operator in the Grafana dashboard. **

Table 1.2. Available OpenTelemetry environment variables 

Variable Description Default 

**OTEL_EX PORTER_ OTLP_EN DPOINT **

OTLP collector endpoint URL, for example, **rpc://tempo.tempo.svc.cluster.local:4317. The **following supported endpoint URL schemes are: 

**rpc://host:port → gRPC OTLP **

**Insecure: http://host:port → HTTP OTLP **

**Secure: https://host:port → HTTPS OTLP **

Tracing disabled 

**OTEL_EX PORTER_ OTLP_TR ACES_EN DPOINT **

Override endpoint specifically for traces Uses **OTEL_EXPORTER_OTL P_ENDPOINT **

**OTEL_EX PORTER_ OTLP_INS ECURE **

**Use insecure connection to collector; set to false when used **in production with TLS 

**true **

**OTEL_SE RVICE_NA ME **

Service name for traces **kuadrant-operator **

**OTEL_SE RVICE_VE RSION **

Service version for telemetry data Empty 

1.5.3. Configure data plane tracing in Connectivity Link 

**Enable data plane tracing in OpenShift Service Mesh with the kuadrant CR. You must perform these **steps on each OpenShift Container Platform cluster that you want to use Connectivity Link on. 

Prerequisites 

You installed Connectivity Link. 

You are logged into a running OpenShift Container Platform cluster as an administrator. 

You have Red Hat OpenShift Distributed Tracing Platform installed and configured to support OpenTelemetry. 

You installed a compatible version of OpenShift Service Mesh. 

Procedure 

**1. Enable tracing in OpenShift Service Mesh by configuring your Telemetry custom resource (CR) **as follows: 

Example OpenShift Service Mesh Telemetry CR with tracing 

2. Apply the configuration by running the following command: 

**3. Configure a tracing extension provider for OpenShift Service Mesh in your Istio CR by adding a list value to the spec.values.meshConfig.extensionProviders parameter. Ensure that you also add the otel port and service information: **

Example Istio CR with tracing extension provider 

apiVersion: telemetry.istio.io/v1alpha1 kind: Telemetry metadata:   name: mesh-default   namespace: gateway-system spec:   tracing:   - providers:     - name: tempo-otlp     randomSamplingPercentage: 100 *# ... *

$ oc apply -f mesh-default.yaml 

apiVersion: operator.istio.io/v1alpha1 kind: Istio metadata:   name: default spec:   namespace: gateway-system   values:     meshConfig:       defaultConfig:         tracing: {}       enableTracing: true       extensionProviders:       - name: tempo-otlp         opentelemetry:           port: 4317           service: tempo.tempo.svc.cluster.local *# ... *

IMPORTANT 

If you are setting the controller manually, you must set the OpenTelemetry **protocol (OTLP) in the Service CR port name and appProtocol fields. For example, when using gRPC, the port name should begin with grpc- or the appProtocol should be grpc: **

4. Apply the configuration by running the following command: 

**5. Optional. If you want to collect Authorino and Limitador traces in a different location than your Kaudrant traces, complete the following steps: **

**a. Enable request tracing in your Authorino custom resource (CR) and send authentication **and authorization traces to the central collector as follows: 

Example Authorino CR with request tracing 

**Set insecure to true to skip TLS certificate verification in development environments. Set to false for production environments. **

b. Apply the configuration by running the following command: 

**c. Enable request tracing in your Limitador CR and send rate limit traces to the central **collector as follows: 

kind: Service apiVersion: v1 metadata:   name: otel-collector spec:   ports:     - name: otlp-grpc       port: 4317       targetPort: 4317       appProtocol: grpc   selector:     app: otel-collector *# ... *

$ oc apply -f istio.yaml 

apiVersion: operator.authorino.kuadrant.io/v1beta1 kind: Authorino metadata:   name: authorino spec:   tracing:     endpoint: rpc://authorino-collector:4317     insecure: true *# ... *

$ oc apply -f authorino.yaml 

Example Limitador CR with request tracing 

**Set insecure to true to skip TLS certificate verification in development environments. Set to false for production environments. **

d. Apply the configuration by running the following command: 

IMPORTANT 

Trace IDs do not propagate to WebAssembly modules in OpenShift Service Mesh. This means that requests passed to Limitador do not have the relevant parent trace ID. However, if the trace initiation point is outside OpenShift Service Mesh, the parent trace ID is available to Limitador and included in traces. This impacts correlating traces from Limitador with traces from Authorino, the gateway, and any other components in the request path. 

**6. Configure data-plane tracing in the Kuadrant CR by providing the collector endpoint as shown **in the following example: 

**Example kuadrant CR **

**spec.observability.dataPlane.defaultLevels: Set this value to enable trace filtering at the required level, for example debug: "true" for debug-level trace filtering. **

apiVersion: limitador.kuadrant.io/v1alpha1 kind: Limitador metadata:   name: limitador spec:   tracing:     endpoint: rpc://limitador-collector:4317     insecure: true *# ... *

$ oc apply -f limitador.yaml 

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant metadata:   name: kuadrant   namespace: kuadrant-system spec:   observability:     dataPlane:       defaultLevels:         - debug: "true"       httpHeaderIdentifier: x-request-id     tracing:       defaultEndpoint: rpc://tempo.tempo.svc.cluster.local:4317       insecure: true 

 **such as the OTLP endpoint. Use rpc://, gRPC OTLP, port 4317, for full compatibility across **all components. 

**spec.observability.tracing.insecure: Set to true to skip TLS certificate verification in development environments. Set to false for production environments. **

IMPORTANT 

Point to the collector service, such as the Distributed Tracing Platform, not the query service. The collector receives traces from your applications. The query service is only for viewing traces in the GUI. 

7. Apply the configuration by running the following command: 

Verification 

**Verify that the CR applied successfully by listing the objects of that Kind by running the **following command: 

1.5.4. Data-plane tracing configuration fields 

**You can enable data-plane tracing in OpenShift Service Mesh by configuring tracing with the Kuadrant custom resource (CR). The Kuadrant CR directs traces to a central collector for improved observability and troubleshooting. To view traces, first configure defaultLevels in the Kuadrant CR, then view traces **in your tracing GUI, such as Grafana. 

Data-Plane Configuration Fields 

**defaultLevels: Controls the OpenTelemetry trace filtering level for the wasm-shim module. **This determines which trace spans are exported to your tracing collector. 

**Supported levels from the highest to lowest verbosity: DEBUG, INFO, WARN, ERROR. Default value is WARN. **

**Priority means that the highest level set wins: DEBUG > INFO > WARN > ERROR. **

**httpHeaderIdentifier: Specifies the HTTP header name used to correlate requests in traces, such as x-request-id. **

IMPORTANT 

**The defaultLevels configuration controls trace span filtering sent to your observability **backend, such as Distributed Tracing Platform, not the verbosity of logs appearing in gateway pod output. 

To see debug logs in gateway pods, you must configure the Envoy log level separately. 

$ oc apply -f kuadrant.yaml 

$ oc get kuadrant 

1.5.5. Troubleshoot by using traces and logs 

You can use a tracing user interface such Grafana to search for OpenShift Service Mesh and Connectivity Link trace information by trace ID. You can get the trace ID from logs, or from a header in a sample request that you want to troubleshoot. You can also search for recent traces, filtering by the service that you want to focus on. 

If you centrally aggregate logs by using tools such as Grafana Loki and Promtail, you can jump between trace information and the relevant logs for that service. 

By using a combination of tracing and logs, you can visualize and troubleshoot request timing issues and narrow down to specific services. This method gives you even more insight a more complete picture of your user traffic when you combine it with Connectivity Link metrics and dashboards. 

1.5.6. View rate-limit logging with trace IDs 

You can enable request logging with trace IDs to get more information about requests when you use the Limitador component of Connectivity Link for rate limiting. To do this, you must increase the log level. 

Prerequisites 

You installed Connectivity Link. 

You have administrator access to a running OpenShift Container Platform cluster. 

You configured Grafana dashboards. 

You have Red Hat OpenShift Distributed Tracing Platform installed and configured to support OpenTelemetry. 

Procedure 

**Set the verbosity to 3 or higher in your Limitador custom resource (CR) as follows: **

**Example Limitador CR **

**Example log entry with the traceparent field holding the trace ID **

apiVersion: limitador.kuadrant.io/v1alpha1 kind: Limitador metadata:   name: limitador spec:   verbosity: 3 

"Request received: Request { metadata: MetadataMap { headers: {"te": "trailers", "grpctimeout": "5000m", "content-type": "application/grpc", "traceparent": "00-4a2a933a23df267aed612f4694b32141-00f067aa0ba902b7-01", "x-envoy-internal": "true", "x-envoy-expected-rq-timeout-ms": "5000"} }, message: RateLimitRequest { domain: "default/toystore", descriptors: [RateLimitDescriptor { entries: [Entry { key: "limit.general_user__f5646550", value: "1" }, Entry { key: "metadata.filter_metadata.envoy\\.filters\\.http\\.ext_authz.identity.userid", value: "alice" }], limit: None }], hits_addend: 1 }, extensions: Extensions }" 

1.6. CONFIGURE ACCESS LOGS 

You can configure Envoy access logs in OpenShift Service Mesh so that you can to track a single request across multiple services and components by using a unique identifier. 

Prerequisites 

You installed Connectivity Link. 

You have a running OpenShift Container Platform cluster. 

You have administrator access to the OpenShift Container Platform cluster. 

Procedure 

1. Enable mesh-wide, default-format access logs by using the Istio Telemetry API. Use the following example as a starting point: 

Example Telemetry API config 

**You might also use the istio-system as your namespace, depending on your setup. **

2. For better parsing and integration with log aggregation systems, enable JSON-formatted access logs. Only log errors as shown in the following example: 

Example JSON config 

3. To enable logging for a specific workload and add filtering, use the following example: 

Example JSON workload config 

apiVersion: telemetry.istio.io/v1alpha1 kind: Telemetry metadata:   name: access-logs   namespace: gateway-system spec:   accessLogging:     - providers:       - name: envoy 

apiVersion: telemetry.istio.io/v1alpha1 kind: Telemetry metadata:   name: access-logs-json   namespace: istio-system spec:   accessLogging:     - providers:       - name: envoy     filter:       expression: "response.code >= 400" 

apiVersion: telemetry.istio.io/v1 

TIP 

**The expression field uses Common Expression Language (CEL). You can use CEL-based **filters to avoid excessive and meaningless logs. 

**4. If you are using the Sail Operator, check which Istio Operator is active in your cluster by running **the following command: 

**The expected output is a list of your mesh deployments, such as default, prod-mesh and their **current status. 

5. Configure the Istio mesh with a custom access log provider to enable JSON encoding: 

kind: Telemetry metadata:   name: selective-logging   namespace: my-app-ns spec:   selector:     matchLabels:       app: productpage   accessLogging:     - providers:         - name: access-logs-json       filter:         expression: "response.code >= 400" 

$ oc get istio -A 

apiVersion: sailoperator.io/v1 kind: Istio metadata:   name: default spec:   namespace: istio-system   values:     meshConfig:       accessLogFile: /dev/stdout       accessLogEncoding: JSON       accessLogFormat: |         {           "start_time": "%START_TIME%",           "method": "%REQ(:METHOD)%",           "path": "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",           "protocol": "%PROTOCOL%",           "response_code": "%RESPONSE_CODE%",           "response_flags": "%RESPONSE_FLAGS%",           "bytes_received": "%BYTES_RECEIVED%",           "bytes_sent": "%BYTES_SENT%",           "duration": "%DURATION%",           "upstream_service_time": "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%",           "x_forwarded_for": "%REQ(X-FORWARDED-FOR)%",           "user_agent": "%REQ(USER-AGENT)%",           "request_id": "%REQ(X-REQUEST-ID)%",           "authority": "%REQ(:AUTHORITY)%", 

Next steps 

Filter your access logs to focus on the errors you need to see. 

Enable request, log, and tracing correlation. 

1.6.1. Filter access logs 

You can filter your access logs to reduce extra messages and focus on the issues and errors that are relevant to your use case. 

Prerequisites 

You installed Connectivity Link. 

You have a running OpenShift Container Platform cluster. 

You have administrator access to the OpenShift Container Platform cluster. 

You enabled access logs. 

Procedure 

**1. Configure your Telemetry custom resource (CR) to only log errors by using the following **example: 

**2. Configure your Telemetry custom resource (CR) to only log specific routes by using the **following example: 

          "upstream_host": "%UPSTREAM_HOST%",           "upstream_cluster": "%UPSTREAM_CLUSTER%",           "route_name": "%ROUTE_NAME%"         } 

apiVersion: telemetry.istio.io/v1alpha1 kind: Telemetry metadata:   name: access-logs-errors-only   namespace: istio-system spec:   accessLogging:     - providers:       - name: envoy       filter:         expression: "response.code >= 400" 

apiVersion: telemetry.istio.io/v1alpha1 kind: Telemetry metadata:   name: access-logs-api-only   namespace: istio-system spec:   accessLogging:     - providers:       - name: envoy 

**3. Configure your Telemetry custom resource (CR) to exclude health checks by using the **following example: 

1.6.2. Common access log format variables 

You can quickly set up Envoy logs by using the most common format variables so that you get exactly the data you want. 

Example configuration snippet 

Table 1.3. Common Envoy access log format variables 

Variable Description 

**%START_TIME% **Request start time 

**%REQ(HEADER)% Request header value, such as %REQ(X-REQUEST-ID)% **

**%RESP(HEADER)% **Response header value 

**%PROTOCOL% **Protocol, such as HTTP/1.1, HTTP/2 

**%RESPONSE_CODE% **HTTP response code 

**%RESPONSE_FLAGS% **Response flags indicating issues, such as UH, UF 

**%BYTES_RECEIVED% **Bytes received from client 

**%BYTES_SENT% **Bytes sent to client 

      filter:         expression: 'request.url_path.startsWith("/api/")' 

apiVersion: telemetry.istio.io/v1alpha1 kind: Telemetry metadata:   name: access-logs-no-healthz   namespace: istio-system spec:   accessLogging:     - providers:       - name: envoy       filter:         expression: '!request.url_path.startsWith("/healthz")' 

envoyFileAccessLog:   path: /dev/stdout   logFormat:     text: "[%START_TIME%] %REQ(X-REQUEST-ID)% %RESP(HEADER)% %RESPONSE_FLAGS%\n" 

**%DURATION% **Total request duration in milliseconds 

**%UPSTREAM_HOST% **Upstream host address 

**%UPSTREAM_CLUSTER% **Upstream cluster name 

**%ROUTE_NAME% **Route name that matched 

Variable Description 

1.7. ABOUT USING ACCESS LOGS FOR REQUEST CORRELATION 

Access logs give you detailed information about each request processed by the gateway, including timing, response codes, and request identifiers. For example, you can correlate requests across gateways, Authorino, Limitador, and backend services. 

You can correlate request information with traces and application logs for a variety of uses. Request **correlation uses x-request-id headers. These headers are automatically generated by Envoy for each **incoming request. For example: 

**Access logs show the x-request-id. **

**Traces include the x-request-id as a span attribute. **

Use a dashboard to jump from logs to traces and vice versa. 

The following fields are the most important access-log fields for request correlation: 

**request_id (%REQ(X-REQUEST-ID)%): The unique request identifier generated by Envoy. **

**start_time** (%START_TIME%): The request start time for time-based correlation. **

**route_name** (%ROUTE_NAME%): The route that matched the request, which is useful for **policy debugging. 

1.7.1. Set up access log and tracing correlation 

You can use access logs and tracing together to correlate requests. When you correlate request IDs, you can search for an ID once and see the entire journey from the initial access through to an event that you are investigating. 

You can see the exact timing of a request as it entered and left each service. If you have configured user or organization-based IDs, you can also find who a problem is effecting so that you can rank your response. 

**The following configuration example tells WASM filters to log the x-request-id header value and **enables request correlation across Envoy, Authorino, Limitador, and WASM logs. 

Prerequisites 

You installed Connectivity Link. 

You have a running OpenShift Container Platform cluster. 

You have administrator access to the OpenShift Container Platform cluster. 

You enabled access logs and tracing. 

Procedure 

1. To enable request correlation across Connectivity Link components, configure the **httpHeaderIdentifier in the Kuadrant CR: **

**2. You can correlate logs across all components using the x-request-id, by using the following **examples: 

a. View the following Envoy access log entry: 

b. Correlate the following Authorino log entry with the Envoy access log: 

c. Correlate the following Limitador log entry with the Envoy and Authorino logs: 

**3. When you combine the three logs, the story of this request_id is: **

**At 15:45:12, a user named alice requested the users' API, /api/users. You can also see the request_id of a1b2c3d4-e5f6-7890-abcd-ef1234567890. **

**The request hit the toystore-route in Envoy. **

apiVersion: kuadrant.io/v1beta1 kind: Kuadrant metadata:   name: kuadrant   namespace: kuadrant-system spec:   observability:     dataPlane:       httpHeaderIdentifier: x-request-id     tracing:       defaultEndpoint: rpc://tempo.tempo.svc.cluster.local:4317       insecure: true 

{   "start_time": "2026-01-23T15:45:12.345Z",   "method": "GET",   "path": "/api/users",   "response_code": 200,   "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",   "route_name": "toystore-route" } 

{"level":"info","ts":"2026-01-23T15:45:12.350Z","request_id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890","msg":"auth check succeeded","identity":"alice"} 

Request received: ... "x-request-id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890" ... 

**Envoy paused the request and checked authentication with Authorino, see level and info. **

**Authorino verified Alice’s identity: auth check succeeded, identity, alice. **

Simultaneously, Limitador noted the request to ensure that Alice did not exceed her allowed limit. 

**Finally, Envoy allowed the traffic through, resulting in a 200 response code. **

1.8. ADDITIONAL RESOURCES 

Configuring OpenShift Monitoring with Service Mesh 

Grafana user documentation 

Observability and Service Mesh 

OpenShift Service Mesh tracing documentation 

Migrating from Jaeger to Red Hat build of OpenTelemetry 

Envoy access log documentation 

Monitoring stack for Red Hat OpenShift 4.21 

### CHAPTER 2. OBSERVE MCP GATEWAY CONNECTIONS

You can use observability in MCP gateway to debug silent failures, track destructive annotations and latencies, and configure an audit trail. 

2.1. ENABLE RED HAT BUILD OF OPENTELEMETRY FOR THE MCP GATEWAY 

The MCP gateway uses Red Hat build of OpenTelemetry throughout all components to give you consistent logging, distributed tracing, and metrics. By using observability, you can achieve the following goals: 

Discover which component generated an error, such as Envoy, an MCP gateway component, or a backend MCP server. 

Understand how requests flow through the system components. 

See which tools were called and which MCP servers executed those tools. 

Understand where to find relevant logs for each component. 

Examine metrics about tool call patterns, success rates, and error rates. 

Examine distributed tracing across the request path. 

Prerequisites 

You installed MCP gateway. 

You installed Connectivity Link. 

**You configured a Gateway object. **

**You are logged into a running OpenShift Container Platform cluster with an admin role. **

You installed Red Hat build of OpenTelemetry. 

You configured the Red Hat OpenShift Distributed Tracing Platform for traces. 

You installed the OpenShift Logging Operator (Loki). 

You configured an S3-compatible persistent storage volume for Loki to store long-term MCP tool call logs. 

Procedure 

1. Use the following example YAML to create a collector in your MCP gateway deployment namespace: 

Example OpenTelemetryCollector custom resource (CR) 

apiVersion: opentelemetry.io/v1beta1 kind: OpenTelemetryCollector metadata: *  name: <mcp_otel_collector> *

**Replace the value of metadata.name: with the name you want to assign to this collector. **

**Replace the value of metadata.namespace: with the namespace of your MCP gateway **deployment. 

**The spec.config.exporters: field value points to distributed tracing. **

**The setting, spec.config.exporters.otlp/tempo.tls.insecure: true is for internal cluster **communication without TLS. 

2. Apply the following environment variables to your OpenShift Container Platform cluster by running the following command: 

***Replace <mcp_otel_collector> with the name you used in your OpenTelemetryCollector ***CR. When Red Hat build of OpenTelemetry creates a collector, the service name is **[metadata.name]-collector. **

***Replace <mcp_gateway_system> with the namespace of your MCP gateway deployment. ***

3. Optional. If you want to send traces to one collector and logs to a different one, set the following additional environment variables: 

*  namespace: <mcp_gateway_system> *spec:   mode: deployment   config:     receivers:       otlp:         protocols:           http:             endpoint: 0.0.0.0:4318           grpc:             endpoint: 0.0.0.0:4317     exporters:       otlp/tempo:         endpoint: tempo-gateway-http.openshift-tracing.svc.cluster.local:4317         tls:           insecure: true       debug:         verbosity: basic     service:       pipelines:         traces:           receivers: [otlp]           exporters: [otlp/tempo, debug]         logs:           receivers: [otlp]           exporters: [debug] 

$ oc set env deployment/mcp-gateway \ *  OTEL_EXPORTER_OTLP_ENDPOINT="http://<mcp_otel_collector>-collector.<mcp_gateway_system>.svc.cluster.local:4318" \ *  OTEL_EXPORTER_OTLP_INSECURE="true" \   OTEL_SERVICE_NAME="mcp-gateway" 

$ oc set env deployment/mcp-gateway \ 

**Set OTEL_EXPORTER_OTLP_TRACES_ENDPOINT to override the endpoint for traces. **

**Set OTEL_EXPORTER_OTLP_LOGS_ENDPOINT to override the endpoint for logs. **

4. If you are using Red Hat OpenShift Distributed Tracing Platform, select your stack name as the **data source in the OpenShift Web Console Observe > Traces dashboard. For example, tempomcp. **

5. After you select the stack name, you can consult an attribute in your OpenShift Web Console OpenShift Observe > Traces dashboard to find where errors have occurred or to gather information for trend identification. 

**You can also filter by service.name="mcp-gateway". **

6. When using Loki, use the Observe > Logs view and toggle the Structured view to filter by **mcp.session.id. **

**7. When using Loki, use the Trace timeline view, look for the Log icon next to spans to jump **directly to the relevant logs. 

Troubleshooting 

**If you do not see any traces, check if the NetworkPolicy CR in your namespace allows traffic **from the MCP gateway to the Red Hat build of OpenTelemetry collector service. 

2.1.1. MCP gateway router spans for observability 

**When enabled, the Model Context Protocol (MCP) router, ext_proc, emits trace spans for every **request and can export structured logs through Red Hat build of OpenTelemetry. 

With traces, you can see one continuous timeline of traffic events across different pods and services. This can help you identify bottlenecks and conduct root-cause analysis. 

Spans show one part of the journey. The attributes attached to those spans give you the contextual **metadata that you need to have searchable and meaningful traces. The attributes are simple key: value **pairs attached to each span. 

The MCP gateway uses the following router spans: 

Table 2.1. MCP router spans 

Span When Description 

**mcp-router.process Every ext_proc stream **Root span. Starts when request headers arrive, ends after response headers are processed. 

**mcp-router.route-decision **

The request body is parsed 

**Routing decision: tool-call versus pass-through to **broker. 

  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="http://trace-collector.tracing-namespace.svc:4317" \   OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="http://log-collector.logging-namespace.svc:4317" 

**mcp-router.broker-passthrough **

**Non-tool-call requests Pass-through to broker: initialize, tools/list, notifications. No child spans means the broker is **not instrumented. 

**mcp-router.tool-call tools/call requests **Full tool call handling including session and server resolution. 

**mcp-router.broker.get-server-info **

**Inside tool-call **Queries the broker to resolve which backend MCP server owns the tool. 

**mcp-router.session-cache.get **

**Inside tool-call **Queries the session cache to look up an existing backend session. 

**mcp-router.session-init **

**Cache miss during toolcall **

**Hairpin initialize request through the gateway to **the backend MCP server. 

**mcp-router.session-cache.store **

**After session-init **Persists the new backend session in the session cache. 

Span When Description 

The attributes in the following tables use OpenTelemetry MCP Semantic Conventions . 

**Table 2.2. MCP router root span, mcp-router.process, attributes **

Attribute Source Description 

**http.method :method header HTTP method, POST **

**http.path :path header Request path, /mcp **

**http.request_id x-request-id header **Envoy request ID 

**mcp.method.name JSON-RPC method **field 

**MCP method, initialize, tools/call, tools/list, and **so on 

**gen_ai.tool.name **JSON-RPC **params.name **

**Tool name, only for tools/call **

**jsonrpc.request.id JSON-RPC id field **JSON-RPC request ID 

**jsonrpc.protocol.ver sion **

**JSON-RPC jsonrpc **field 

Always "2.0" 

**gen_ai.operation.na me **

**JSON-RPC method **field 

**Same as mcp.method.name **

**mcp.session.id mcp-session-id **header 

Gateway session ID 

**client.address x-forwarded-for **header 

Client IP address 

**http.status_code :status response **header 

Response status code 

Attribute Source Description 

**Table 2.3. MCP route decision span, mcp-router.route-decision, attributes **

Attribute Description 

**mcp.method.name **MCP method 

**mcp.route Routing decision: tool-call, broker, or elicitation-response **

**Table 2.4. MCP tool call span, mcp-router.tool-call, attributes **

Attribute Description 

**gen_ai.tool.name **Tool name from the request 

**mcp.session.id **Gateway session ID 

**mcp.server **Resolved backend server name 

**mcp.server.hostname **Resolved backend server hostname 

Table 2.5. MCP error attributes 

Attribute Description 

**error.type Error classification, such as tool_not_found, missing_tool_name, invalid_session, session_cache_error, session_init_error, marshal_error, path_parse_error **

**error_source **Component that generated the error, such as`ext-proc` 

**http.status_code **HTTP status code returned 

When there is an error, spans include these attributes. 

2.2. THE MCP GATEWAY AUDIT TRAIL 

You can use an audit trail for compliance and accountability that captures caller identity, tool names, and Model Context Protocol (MCP) session context through the MCP gateway. 

Users connect to backend MCP servers and run functions, for example, reading a database, running a **script, or editing files. By configuring an audit trail that comes from your AuthPolicy objects and the Istio Telemetry API, you can configure JSON access logging on your Gateway object and discover who **did what and when. 

MCP gateway sets the following routing headers on every request: 

**x-mcp-method **

**x-mcp-toolname **

**x-mcp-servername **

**mcp-session-id **

**These headers are available to any Envoy access log through %REQ(… ​)% format strings. With **configuration, you can add the following username header and structured access logs: 

**x-auth-identity: Adds caller identity. After you configure the header, the AuthPolicy object **validates JWT tokens and injects the authenticated username as the request header. 

**With an Istio Telemetry resource, you can configure JSON access logging on the Gateway **object, capturing MCP routing headers and the identity header. 

**The result is a JSON access log on the MCP Gateway object pod’s standard output ( stdout) that tells **you who called what tool, on which server, during which session, and at what time. 

2.2.1. Configure an AuthPolicy with identity injection 

To capture authenticated user identities in access logs for all request types, you must create an **AuthPolicy custom resource (CR) for each of the MCP gateway two listeners. **

The MCP gateway uses the two following listeners: 

**mcp: This listener handles client requests such as initialize and tools/list. **

**mcps: This listener handles tool call routing to the backend Model Context Protocol (MCP) **servers. 

**When you have configured the AuthPolicy CRs, after Authorino validates the JWT, it extracts the preferred_username field value from the token claims and injects it as the x-auth-identity request **header. This header is trustworthy because Authorino strips any client-supplied value and sets it from **the validated token. With both policies in place, the mcp_user_id field is displayed in access log entries **for all MCP request types. 

Prerequisites 

You installed the MCP gateway. 

You installed Connectivity Link. 

**You created a Gateway object. **

You set up an identity provider. 

You configured Istio as the Gateway API provider. 

Procedure 

**1. Create an AuthPolicy CR for the client-facing listener, mcp, by using the following example: **

Client-facing listener AuthPolicy CR 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <audit_auth_client_listener>   namespace: <gateway_namespace> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway *    name: <mcp_gateway> *    sectionName: mcp   defaults:     when:       - predicate: "!request.path.contains('/.well-known')"     rules:       authentication:         'keycloak':           jwt:             issuerUrl: https://keycloak.example.com:8002/realms/mcp       response:         success:           headers:             "x-auth-identity":               plain:                 selector: auth.identity.preferred_username         unauthenticated:           code: 401           headers:             'WWW-Authenticate':               value: Bearer resource_metadata=http://mcp.example.com:8001/.well-known/oauth-protected-resource/mcp           body:             value: |               {                 "error": "Unauthorized",                 "message": "Authentication required."               } 

***Replace <gateway_namespace> with the namespace where you applied your Gateway ***object. 

NOTE 

**This mcp listener AuthPolicy CR validates JSON web tokens (JWTs) on **client requests and injects the authenticated username as a request header. 

**2. Apply the client-listener AuthPolicy CR by running the following command: **

***Replace <audit_auth_client_listener.yaml> with the filename that you used. ***

**3. Create an AuthPolicy CR for the backend-facing listener, mcps, by using the following **example: 

**Client-facing listener AuthPolicy CR **

*$ oc apply -f <audit_auth_client_listener.yaml> *

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <audit_auth_backend_listener>   namespace: <gateway_namespace> *spec:   targetRef:     group: gateway.networking.k8s.io     kind: Gateway *    name: <mcp_gateway> *    sectionName: mcps   defaults:     rules:       authentication:         'keycloak':           jwt:             issuerUrl: https://keycloak.example.com:8002/realms/mcp       response:         success:           headers:             "x-auth-identity":               plain:                 selector: auth.identity.preferred_username         unauthenticated:           code: 401           headers:             'WWW-Authenticate':               value: Bearer resource_metadata=http://mcp.example.com:8001/.well-known/oauth-protected-resource/mcp           body:             value: |               {                 "error": "Unauthorized",                 "message": "Authentication required."               } 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

***Replace <gateway_namespace> with the namespace where you applied your Gateway ***object. 

**Replace the preferred_username field value with sub or another claim depending on both **your identity provider and what you want as the audit identity. For Red Hat build of **Keycloak, the preferred_username field value gives a human-readable username but requires the profile scope in the token request. **

NOTE 

**This mcps listener policy validates the same JWT on tool call requests **routed to backend servers and injects the identity header there, too. 

**4. Apply the backend-listener AuthPolicy CR by running the following command: **

***Replace <audit_auth_backend_listener.yaml> with the filename that you used. ***

2.2.2. Verify AuthPolicy identity injection 

**Verify that the identity header you created in your audit AuthPolicy custom resource (CR) is being **injected by calling a tool and checking what the backend receives. 

Prerequisites 

You installed the MCP gateway. 

You installed Connectivity Link. 

**You created a Gateway object. **

You set up an identity provider. 

You configured Istio as the Gateway API provider. 

**You created AuthPolicy audit CRs for both MCP gateway listeners. **

Procedure 

1. Get a token by running the following command: 

Adjust this command for your identity provider. 

2. Initialize a session by running the following command: 

*$ oc apply -f <audit_auth_backend_listener.yaml> *

$ TOKEN=$(curl -s -X POST "https://keycloak.example.com:8002/realms/mcp/protocol/openid-connect/token" \   -d "grant_type=password&client_id=mcpgateway&client_secret=secret&username=mcp&password=mcp&scope=openid+profile" \   | jq -r '.access_token') 

The expected output is the session ID returned in the response header. 

3. Call the headers tool to see which headers reach the backend by running the following command: 

**The expected output is the x-auth-identity header that lists the Keycloak username in the **response. 

2.2.3. Add a custom audit log provider 

Define the JSON format for the audit logs by adding a custom access log provider to Istio’s **MeshConfig structure that dictates all the global settings for the mesh. Istio acts as the controller that **translates your resources into Envoy configurations. 

IMPORTANT 

The approach used in the following procedures only works if you are using OpenShift Service Mesh. If you are using the OpenShift Container Platform default Ingress Operator **to manage Istio objects, changes are reconciled back to the previous settings. **

Prerequisites 

You installed the MCP gateway. 

You installed Connectivity Link. 

**You created a Gateway object. **

You set up an identity provider. 

You configured Istio as the Gateway API provider. 

**You created AuthPolicy audit CRs for both MCP gateway listeners. **

Procedure 

Edit the Istio object by using the following example: 

Example Istio custom access log provider 

$ SESSION_ID=$(curl -si http://mcp.example.com:8001/mcp \   -H "Authorization: Bearer $TOKEN" \   -H "Content-Type: application/json" \   -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"audit-test","version":"0.0.1"}}}' \   | grep -i 'mcp-session-id:' | awk '{print $2}' | tr -d '\r') 

$ curl -s http://mcp.example.com:8001/mcp \   -H "Authorization: Bearer $TOKEN" \   -H "Content-Type: application/json" \   -H "Mcp-Session-Id: $SESSION_ID" \   -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params": {"name":"test1_headers","arguments":{}}}' \   | jq '.result.content[0].text' | grep -i "x-auth-identity" 

IMPORTANT 

If you have other extension providers configured, for example, OpenTelemetry **tracing, include them in the extensionProviders array with the access log **provider. The merge of the resources replaces the array. 

2.2.3.1. Custom audit log provider fields 

Understand the MCP gateway audit log fields by using the reference table for descriptions of each field and the source and type of information that each provides. 

Table 2.6. Audit log fields 

Field Source Description 

**timestamp %START_TIME% **The start time of the session 

**method %REQ(:METHOD)% The HTTP method of the request, for example, GET, POST **

**path %REQ(:PATH)% **The HTTP request path, including any query parameters 

apiVersion: operator.istio.io/v1alpha1 kind: Istio metadata:   name: default   namespace: istio-system spec:   meshConfig:     extensionProviders:       - envoyFileAccessLog:           logFormat:             labels:               bytes_received: '%BYTES_RECEIVED%'               bytes_sent: '%BYTES_SENT%'               duration_ms: '%DURATION%'               mcp_method: '%REQ(X-MCP-METHOD)%'               mcp_server_name: '%REQ(X-MCP-SERVERNAME)%'               mcp_session_id: '%REQ(MCP-SESSION-ID)%'               mcp_tool_name: '%REQ(X-MCP-TOOLNAME)%'               mcp_user_id: '%REQ(X-AUTH-IDENTITY)%'               method: '%REQ(:METHOD)%'               path: '%REQ(:PATH)%'               request_id: '%REQ(X-REQUEST-ID)%'               response_code: '%RESPONSE_CODE%'               timestamp: '%START_TIME%'               traceparent: '%REQ(TRACEPARENT)%'               upstream_host: '%UPSTREAM_HOST%'           path: /dev/stdout         name: mcp-json-access-log *#... *

**response_code %RESPONSE_CODE % **

The HTTP response status code returned to the client 

**request_id %REQ(X-REQUEST-ID)% **

Unique string identifier for tracking the end-to-end request lifecycle 

**traceparent %REQ(TRACEPARE NT)% **

W3C Trace Context for cross-system correlation 

**mcp_method %REQ(X-MCP-METHOD)% **

**MCP method, such as tools/call, tools/list, initialize, and so on **

**mcp_tool_name %REQ(X-MCP-TOOLNAME)% **

Tool name after prefix stripping 

**mcp_server_name %REQ(X-MCP-SERVERNAME)% **

Backend MCP server name 

**mcp_session_id %REQ(MCP-SESSION-ID)% **

MCP session identifier 

**mcp_user_id %REQ(X-AUTH-IDENTITY)% **

Authenticated user identity, injected by an **AuthPolicy custom resource **

**duration_ms %DURATION% **Total duration of the request in milliseconds, from the start time to the last byte sent 

**upstream_host %UPSTREAM_HOST % **

The upstream host IP address and port that handled the request 

**bytes_sent %BYTES_SENT% **Body bytes sent downstream to the client 

**bytes_received %BYTES_RECEIVED % **

Body bytes received upstream from the client 

Field Source Description 

2.2.4. Enable the access log on the Gateway pods workload 

**After you update your Istio custom resource (CR), you must create a Telemetry CR in the namespace where your Gateway object is applied to enable the access log on the Gateway pods workload. **

***The resource created in this example scopes the access log to the <mcp_gateway> Gateway pods ***only. Other workloads in the mesh are not affected. 

Prerequisites 

You installed the MCP gateway. 

You installed Connectivity Link. 

**You created a Gateway object. **

You set up an identity provider. 

You configured Istio as the Gateway API provider. 

**You created AuthPolicy audit CRs for both MCP gateway listeners. **

You added your custom log provider. 

Procedure 

**1. Create a Telemetry CR in the namespace where your Gateway object is applied by using the **following example: 

Example Telemetry CR for audit logs 

***Replace <mcp_audit_logging> with the name of your audit logging Telemetry CR. ***

***Replace <gateway_namespace> with the namespace where you applied your Gateway ***object. 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

**2. Apply the Telemetry CR by running the following command: **

***Replace <mcp_audit_logging.yaml> with the name of your audit logging YAML. ***

Verification 

**1. Verify that your Telemetry CR is applied by running the following command: **

***Replace <gateway_namespace> with the namespace where you applied your Gateway object. ***

apiVersion: telemetry.istio.io/v1 kind: Telemetry metadata: *  name: <mcp_audit_logging>   namespace: <gateway_namespace> *spec:   selector:     matchLabels: *      gateway.networking.k8s.io/gateway-name: <mcp_gateway> *  accessLogging:     - providers:         - name: mcp-json-access-log 

*$ oc apply -f <mcp_audit_logging.yaml> *

*$ oc get telemetry -n <gateway_namespace> *

2.2.5. Verify your audit trail 

**After you have updated your Istio custom resource (CR), you must create a Telemetry CR in the namespace where your Gateway object is applied to enable the access log on the gateway’s workload. **

***The resource created in this example scopes the access log to the <mcp_gateway> Gateway object ***pods only. Other workloads in the mesh are not affected. 

Prerequisites 

You installed the MCP gateway. 

You installed Connectivity Link. 

**You created a Gateway object. **

You set up an identity provider. 

You configured Istio as the Gateway API provider. 

**You created AuthPolicy audit custom resources (CRs) for both MCP gateway listeners. **

You added your custom log provider. 

**You created your Telemetry CR. **

Procedure 

1. Make an authenticated tool call by reusing both the token and session ID from the earlier step by running the following command: 

**2. Check the Gateway object pod logs for the JSON access log entry by running the following **command: 

***Replace <gateway_namespace> with the namespace where you applied your Gateway ***object. 

***Replace <mcp_gateway> with the name of your MCP gateway deployment. ***

Example output 

$ curl -s http://mcp.example.com:8001/mcp \   -H "Authorization: Bearer $TOKEN" \   -H "Content-Type: application/json" \   -H "Mcp-Session-Id: $SESSION_ID" \   -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"test1_greet","arguments": {"name":"audit-test"}}}' 

*$ oc logs -n <gateway_namespace> -l gateway.networking.k8s.io/gateway-name=<mcp_gateway> --since=30s \ *  | grep '"mcp_method"' | tail -1 | jq . 

{   "timestamp": "2026-05-21T14:23:01.123Z",   "method": "POST", 

2.2.6. Use an audit trail without authentication 

If you do not have an authentication layer, the routing headers still offer useful audit context. 

**The mcp_user_id field is empty (-), but you can still see the following details: **

Which tool a user called 

On which server the call took place 

In which session the call took place 

At what time the call took place 

How long the interaction lasted 

**You can configure the x-auth-identity header name and the JSON web token (JWT) claim in the AuthPolicy CR. Adjust the spec.defaults.rules.response.success.headers section to match your **identity provider according to the following list: 

**Red Hat build of Keycloak: auth.identity.preferred_username or auth.identity.email. **

**Generic OIDC: auth.identity.sub; this is the subject claim, always present in JWTs. **

**Custom claims: auth.identity.<claim_name> for any claim in the JWT payload. **

IMPORTANT 

**If you change the header name, you must also update the mcp_user_id field in your *****MeshConfig extension provider to match the %REQ(<HEADER_NAME>)% format. ***

**Generic OIDC AuthPolicy CR header configuration example **

  "path": "/mcp",   "response_code": 200,   "request_id": "abc-111",   "traceparent": null,   "mcp_method": "tools/call",   "mcp_tool_name": "greet",   "mcp_server_name": "mcp-test/test-server1",   "mcp_session_id": "sess-7a3b",   "mcp_user_id": "mcp",   "duration_ms": 342,   "upstream_host": "10.0.1.5:8080",   "bytes_sent": 1024,   "bytes_received": 512 } 

apiVersion: kuadrant.io/v1 kind: AuthPolicy metadata: *  name: <audit_no_auth_client_listener>   namespace: <gateway_namespace> *spec: *#... *

2.3. ADDITIONAL RESOURCES 

Chapter 1. Configuring the Collector (OpenTelemetry documentation) 

MCP Inspector (Model Context Protocol developer tools documentation) 

  defaults: *#... *    rules: *#... *      response:         success:           headers:             "x-auth-identity":               plain:                 selector: auth.identity.sub *#... *