# Red_Hat_OpenShift_AI_Self-Managed-3.5-Creating_distributed_data_processing_applications_with_the_Kubeflow_Spark_Operator-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Creating distributed data processing applications with the Kubeflow Spark Operator

Creating distributed data processing applications with KSO Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Creating distributed data processing applications with the Kubeflow Spark Operator

Creating distributed data processing applications with KSO Red Hat OpenShift AI Self-Managed

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

As a cluster administrator, you can use the Kubeflow Spark Operator to create data processing applications in distributed environments

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. THE KUBEFLOW SPARK OPERATOR (KSO) 1.1. KUBEFLOW SPARK OPERATOR (KSO) ARCHITECTURE 1.2. IBM POWER (PPC64LE) CONSIDERATIONS 

CHAPTER 2 ACTIVATE THE KUBEFLOW SPARK OPERATOR 

CHAPTER 3 USE THE KUBEFLOW SPARK OPERATOR 3.1. USING THE KUBEFLOW SPARK OPERATOR IN A CUSTOM NAMESPACE 

CHAPTER 4 RUN SPARK WORKLOADS FROM OPENSHIFT AI WORKBENCHES 4.1. SPARK CONNECT ON OPENSHIFT AI 

4.1.1. How the Kubeflow Spark Operator manages Spark Connect 4.2. CONFIGURE SPARK CONNECT FOR A NON-DEFAULT NAMESPACE 4.3. DEPLOY A SPARK CONNECT SERVER ON OPENSHIFT AI 4.4. RUN PYSPARK WORKLOADS FROM AN OPENSHIFT AI WORKBENCH 4.5. TROUBLESHOOT SPARK CONNECT WORKBENCH CONNECTIVITY 4.6. SPARKCONNECT CUSTOM RESOURCE AND INFRASTRUCTURE REFERENCE 

4.6.1. SparkConnect custom resource fields 4.6.2. SparkConnect custom resource example 4.6.3. RBAC resources 4.6.4. NetworkPolicy 4.6.5. Auto-created Service 4.6.6. PySpark client dependencies 

3 

4 4 4 

5 

6 8 

10 10 10 10 14 16 17 19 19 21 22 22 23 23 

### PREFACE

You can use the Kubeflow Spark Operator to run distributed data processing applications on Red Hat OpenShift AI. 

### CHAPTER 1. THE KUBEFLOW SPARK OPERATOR (KSO)

The Kubeflow Spark Operator allows you to run Spark data processing applications in a distributed environment on Red Hat OpenShift AI. You can create custom resources (CRs) for specifying, running and surfacing Spark applications. 

KSO for Apache Spark currently supports the following: 

Spark versions 4.0.1 and above. 

**When a SparkApplication custom resource is created, the operator creates and runs a sparksubmit job that starts Spark driver and executor pods. **

Native Cron support for running scheduled applications. 

Customization of Spark pods, including: mounting ConfigMaps/volumes and setting pod affinity. 

Automatic application restart with custom policies. 

Collecting and exporting application metrics and driver metrics to Prometheus. 

1.1. KUBEFLOW SPARK OPERATOR (KSO) ARCHITECTURE 

The Spark operator consists of the following: 

**SparkApplication Controller: A job that watches Create, Update and Delete events in SparkApplication resources. **

**Submission Runner: When a SparkApplication custom resource is created, the operator creates and runs a spark-submit job that starts Spark driver and executor pods. **

**Spark Pod Monitor: Observes the Driver and Executor pods and updates the .status field of the SparkApplication CR. **

Mutating Admission Webhook: A component that intercepts pod creation requests and injects **ConfigMap mounts or Volumes into the Driver and Executor pods before they are scheduled. **

**1.2. IBM POWER (PPC64LE) CONSIDERATIONS **

**When deploying the Kubeflow Spark Operator on IBM Power (ppc64le) systems, ensure that both the Spark runtime image used by SparkApplication resources and the Spark Operator image are built for **the target architecture. 

**The Spark Operator controller manages SparkApplication resources and launches Spark driver and executor pods using the image specified in the SparkApplication custom resource. If architecture-**compatible images are not available, Spark runtime and Spark Operator images must be built from **source for ppc64le. **

For more information about building architecture-specific images, refer to the upstream Apache Spark and Kubeflow Spark Operator repositories: 

Apache Spark: https://github.com/apache/spark 

Kubeflow Spark Operator: https://github.com/kubeflow/spark-operator 

### CHAPTER 2. ACTIVATE THE KUBEFLOW SPARK OPERATOR

You can activate the Kubeflow Spark Operator on your OpenShift cluster by setting its **managementState to Managed in the OpenShift AI Operator DataScienceCluster custom resource **(CR). 

Prerequisites 

You have installed OpenShift 4.19 or newer. 

You have cluster administrator privileges. 

**You have installed the OpenShift CLI (oc). **

You have installed the Red Hat OpenShift AI Operator on your cluster. 

You have an existing Spark image that you can import to you OpenShift AI cluster. 

Procedure 

1. Log in to the OpenShift web console as a cluster administrator. 

2. Go to the Installed Operators page. The navigation path depends on your OpenShift version: 

On OpenShift 4.20 and later, click Ecosystem → Installed Operators. 

On OpenShift 4.19, click Operators → Installed Operators. 

3. Click the Red Hat OpenShift AI Operator to open its details. 

4. Click the DataScienceCluster tab. 

5. Click the YAML tab. **An embedded YAML editor opens, displaying the configuration for the DataScienceCluster **custom resource. 

**6. In the YAML editor, locate the spec.components section, navigate the kubeflowsparkoperator parameter and update the field. **

7. Click Save to apply your changes. 

Verification 

After you activate the Kubeflow Spark Operator, you can verify that it is running in your cluster: 

1. In the OpenShift web console, click Workloads → Pods. 

**2. From the Project list, select the redhat-ods-applications namespace. **

**3. Confirm that a pod with the label app.kubernetes.io/name=kubeflow-spark-operator is **displayed and has a status of Running. 

spec:   components:     kubeflowsparkoperator:       managementState: Managed 

### CHAPTER 3. USE THE KUBEFLOW SPARK OPERATOR

You can run Spark data processing applications in a distributed environment on Red Hat OpenShift AI by using the Kubeflow Spark Operator. You can create custom resources (CRs) for specifying, running and surfacing Spark applications. 

**The following procedure explain how to create a custom Spark image and a SparkApplication custom **resource (CR) application. 

Prerequisites 

You have installed OpenShift 4.19 or newer. 

You have cluster administrator privileges. 

You have installed the Kubeflow Spark Operator on your OpenShift AI instance. 

Procedure 

**1. Create a ContainerFile called spark-image with the following parameters: **

2. Build and tag the image for your registry with the following command: 

**3. Push your spark-image to the registry: **

**4. The SparkApplication custom resource definition (CRD) allows you to define Spark **applications using YAML manifests. 

FROM apache/spark:4.0.1 

LABEL description="Apache Spark image compatible with OpenShift restricted-v2 SCC" 

USER root 

RUN chgrp -R 0 /opt/spark && \     chmod -R g=u /opt/spark && \     mkdir -p /opt/spark/work-dir /opt/spark/logs && \     chgrp -R 0 /opt/spark/work-dir /opt/spark/logs && \     chmod -R 775 /opt/spark/work-dir /opt/spark/logs 

RUN chmod 1777 /tmp 

ENV HOME=/home/spark 

RUN mkdir -p /home/spark && \     chgrp -R 0 /home/spark && \     chmod -R g=u /home/spark && \     chmod 775 /home/spark 

$ podman build -t quay.io//spark-image:4.0.1 -f spark-image 

$ podman push quay.io//spark-image:4.0.1 

$ oc apply -f sparkapplication-example.yaml 

**Example SparkApplication custom resource (CR) **

**Table 3.1. SparkApplication CR reference **

Field Description 

**namespace The namespace to run the Spark application, the default is the redhat-ods-applications namespace. If you want to run a Spark application on a **custom namespace, you need to adjust the role binding to match the roles of the default namespace. For more information 

**type **The language of the application. For example, Python, Scala, etc. 

**mode Deployment mode, example fields include, cluster or client. In cluster **mode, the driver runs in a pod. 

**image **The container image to use for the driver and executors. This image must include the Spark v4.0.1 runtime. 

apiVersion: sparkoperator.k8s.io/v1beta2 kind: SparkApplication metadata:   name: ${APP_NAME}   namespace: ${APP_NAMESPACE} spec:   type: Scala   mode: cluster   image: <your-custom-spark-image>   imagePullPolicy: IfNotPresent   mainClass: org.apache.spark.examples.SparkPi   mainApplicationFile: local:///opt/spark/examples/jars/spark-examples.jar   arguments:     - "1000"   sparkVersion: "4.0.1"   restartPolicy:     type: Never   driver:     cores: 1     coreLimit: "1200m"     memory: "512m"     labels:       version: 4.0.1     serviceAccount: spark-operator-spark     securityContext: {}   executor:     cores: 1     instances: 1     memory: "512m"     labels:       version: 4.0.1     securityContext: {} 

**mainApplicationFil e **

The entry point path. For example, **local:///app/scripts/run_spark_job.py. **

**sparkVersion **The version of Spark to use, the version included must match the image. 

**restartPolicy Handling of failures. Example fields include: Never, OnFailure, Always. **

**driver/executor **Resource requests (cores, memory), labels, service accounts, and security contexts. 

**volumes/volumeM ounts **

PVCs for input and output data. 

**serviceAccount **The spark-operator-spark service account is created automatically by the Spark Operator installation and includes the necessary RBAC permissions for Spark drivers to create and manage executor pods. 

Field Description 

NOTE 

**When using Spark example YAMLs in OpenShift AI, the runAsGroup and runAsUser **parameters must be removed, they may cause jobs crashed in your environment. 

3.1. USING THE KUBEFLOW SPARK OPERATOR IN A CUSTOM NAMESPACE 

You can utilize the Kubeflow Spark Operator in a custom namespace. The following documentation **explains how to view the Role, RoleBinding, and ServiceAccount resources in the default redhat-ods-applications and add them to a custom namespace. **

Prerequisite 

You have installed OpenShift 4.19 or newer. 

You have cluster administrator privileges. 

You have installed the Kubeflow Spark Operator on your OpenShift AI instance. 

**You have installed the OpenShift CLI (oc). **

Procedure 

**1. To get the ServiceAccount resource YAML, run the following command: **

**Then, update the namespace: field to your custom namespace. **

$ oc get serviceaccount spark-operator-spark -n redhat-ods-applications -o yaml 

**2. To get the Role resource YAML, run the following command: **

**Then, update the namespace: field to your custom namespace. **

**3. To get the RoleBinding resource YAML, run the following command: **

**Then, update the two namespace: fields to your custom namespace. **

**4. If you are creating a SparkConnect resource in the custom namespace, also get the NetworkPolicy resource YAML by running the following command: **

**Then, update the namespace: field to your custom namespace. **

5. Save the new resources to a file or multiple files. 

6. Apply the changes to your custom namespace with the following command: 

$ oc get role spark-operator-role -n redhat-ods-applications -o yaml 

$ oc get rolebinding spark-operator-rolebinding -n redhat-ods-applications -o yaml 

$ oc get networkpolicy spark-operator-allow-internal -n redhat-ods-applications -o yaml 

$ oc apply -f <resources-file(s).yaml> -n <custom-namespace> 

### CHAPTER 4. RUN SPARK WORKLOADS FROM OPENSHIFT AI WORKBENCHES

This section describes how to deploy a Spark Connect server on OpenShift AI and run PySpark workloads from Jupyter workbenches without managing Spark infrastructure. 

IMPORTANT 

Spark Connect on OpenShift AI is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

4.1. SPARK CONNECT ON OPENSHIFT AI 

You can run distributed Apache Spark workloads directly from OpenShift AI Jupyter workbenches by using Spark Connect and the Kubeflow Spark Operator. Spark Connect provides a gRPC-based client/server architecture that decouples the PySpark client in your notebook from the Spark driver, so you can submit and monitor Spark jobs without managing Spark infrastructure or requiring cluster-level permissions. 

4.1.1. How the Kubeflow Spark Operator manages Spark Connect 

The Kubeflow Spark Operator automates the lifecycle of Spark Connect servers on OpenShift AI. When **you create a SparkConnect custom resource, the Operator provisions the following resources **automatically: 

**A ConfigMap with the executor pod template. **

A server pod that runs the Spark Connect driver process. 

**A ClusterIP Service that exposes the server with a stable DNS name, including ports for Spark **internal communication (7078, 7079, 4040) and the gRPC endpoint (15002). 

**The auto-created Service follows the naming convention _<connect_name>_-server, where _<connect_name>_ is the metadata.name value from your SparkConnect custom resource. The full DNS name is _<connect_name>_-server._<namespace>_.svc.cluster.local. **

**You do not need to create a Service manually. The Operator creates and manages it as part of the SparkConnect resource reconciliation. **

4.2. CONFIGURE SPARK CONNECT FOR A NON-DEFAULT NAMESPACE 

**You can deploy a Spark Connect server in a namespace other than {dbd-config-default-namespace} **to isolate workloads by team or project. Because the Spark Operator creates RBAC and NetworkPolicy **resources only in {dbd-config-default-namespace} during initial deployment, you must manually create these resources in the target namespace before deploying the SparkConnect custom resource. **

IMPORTANT 

Spark Connect on OpenShift AI is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

**A Spark Connect server is deployed successfully in {dbd-config-default-namespace}, **confirming that the Spark Operator is working correctly. 

You have cluster administrator privileges for the OpenShift cluster. 

The OpenShift CLI (`oc`) is installed. 

You know the target namespace where you want to deploy the Spark Connect server. 

Procedure 

**1. Create the ServiceAccount in the target namespace. In the following command, replace _<target_namespace>_ with the name of your namespace: **

**2. Create the Role with the required permissions in the target namespace. The Spark driver needs permissions to create and manage executor pods, ConfigMaps, PersistentVolumeClaims, and Services: **

$ cat <<EOF | oc apply -f -apiVersion: v1 kind: ServiceAccount metadata:   name: spark-operator-spark   namespace: <target_namespace> EOF 

$ cat <<EOF | oc apply -f -apiVersion: rbac.authorization.k8s.io/v1 kind: Role metadata:   name: spark-role   namespace: <target_namespace> rules: - apiGroups:   - ""   resources:   - pods   - configmaps   - persistentvolumeclaims   - services   verbs: 

**3. Create the RoleBinding to connect the ServiceAccount to the Role: **

**4. Create the NetworkPolicy to allow Spark internal communication and workbench connectivity: **

  - get   - list   - watch   - create   - update   - patch   - delete   - deletecollection EOF 

$ cat <<EOF | oc apply -f -apiVersion: rbac.authorization.k8s.io/v1 kind: RoleBinding metadata:   name: spark-role-binding   namespace: <target_namespace> subjects: - kind: ServiceAccount   name: spark-operator-spark roleRef:   kind: Role   name: spark-role   apiGroup: rbac.authorization.k8s.io EOF 

$ cat <<EOF | oc apply -f -apiVersion: networking.k8s.io/v1 kind: NetworkPolicy metadata:   name: spark-operator-allow-internal   namespace: <target_namespace> spec:   podSelector:     matchLabels:       sparkoperator.k8s.io/launched-by-spark-operator: "true"   policyTypes:     - Ingress   ingress:     - ports:         - port: 7078           protocol: TCP         - port: 7079           protocol: TCP         - port: 4040           protocol: TCP       from:         - podSelector: {}         - namespaceSelector:             matchLabels:               network.openshift.io/policy-group: ingress     - ports: 

Ports 7078 and 7079 enable remote procedure call (RPC) and block manager communication between the Spark driver and executor pods. 

Port 4040 enables the Spark UI. 

Port 15002 enables gRPC connectivity from workbench pods in namespaces managed by the OpenShift AI dashboard. 

**5. Deploy the SparkConnect custom resource in the target namespace. Create a YAML file with the metadata.namespace field set to your target namespace and **apply it: 

**For the complete SparkConnect custom resource example, see SparkConnect custom **resource and infrastructure reference. 

Verification 

1. Verify that the server pod is running in the target namespace: 

**The output shows a pod with a Running status. **

**2. Verify that the auto-created Service exists: **

**The output shows a ClusterIP Service exposing port 15002. **

3. Verify that the RBAC resources are created correctly: 

**4. Verify that the NetworkPolicy was created in the target namespace: **

        - port: 15002           protocol: TCP       from:         - podSelector: {}         - namespaceSelector:             matchLabels:               opendatahub.io/dashboard: "true"           podSelector:             matchLabels:               opendatahub.io/workbenches: "true" EOF 

$ oc apply -f spark-connect-server.yaml 

$ oc get pods -n <target_namespace> -l sparkoperator.k8s.io/launched-by-spark-operator=true 

$ oc get svc -n <target_namespace> -l sparkoperator.k8s.io/connect-name=spark-connect 

$ oc get serviceaccount spark-operator-spark -n <target_namespace> $ oc get role spark-role -n <target_namespace> $ oc get rolebinding spark-role-binding -n <target_namespace> 

$ oc get networkpolicy spark-operator-allow-internal -n <target_namespace> 

4.3. DEPLOY A SPARK CONNECT SERVER ON OPENSHIFT AI 

**You can deploy a Spark Connect server on OpenShift AI by creating a SparkConnect custom resource **in a namespace that an administrator has configured with the required RBAC resources. After you deploy the server, the Kubeflow Spark Operator automatically creates a ClusterIP Service that provides a stable DNS endpoint for workbench connectivity. 

Prerequisites 

Red Hat OpenShift AI 3.5 or later is installed. 

**The DataScienceCluster resource is configured with the sparkoperator component set to Managed. **

**The DataScienceCluster resource is configured with the workbenches component set to Managed. **

An administrator has configured a namespace with the required ServiceAccount, Role, RoleBinding, and NetworkPolicy resources for Spark Connect. 

You have access to the configured namespace. 

The OpenShift CLI (`oc`) is installed. 

Procedure 

**1. Create a YAML file for the SparkConnect resource. The following example shows a basic SparkConnect configuration: **

apiVersion: sparkoperator.k8s.io/v1alpha1 kind: SparkConnect metadata:   name: spark-connect   namespace: <your_namespace> spec:   sparkVersion: 4.0.1   server:     template:       spec:         containers:         - name: spark-kubernetes-driver           image: quay.io/opendatahub/data-processing:Spark-v4.0.1           imagePullPolicy: Always           resources:             requests:               cpu: 1               memory: 1Gi             limits:               cpu: 1               memory: 1Gi         serviceAccountName: spark-operator-spark         securityContext: {}   executor:     instances: 2     cores: 1 

NOTE 

**The securityContext: {} field at the pod level is intentionally empty. On **OpenShift, the restricted-v2 Security Context Constraint (SCC) automatically **enforces security restrictions such as runAsNonRoot, capability dropping, and **seccomp profiles. Do not add explicit security context fields to the **SparkConnect custom resource. **

**2. Apply the SparkConnect custom resource: **

3. Verify that the Spark Connect server pod is running: 

**The output shows a pod named spark-connect-server with a Running status: **

**4. Verify that the Operator has created the ClusterIP Service automatically: **

**The output shows the auto-created Service exposing ports for Spark internal communication **and gRPC connectivity: 

NOTE 

**The Operator creates this Service automatically. You do not need to create a Service manually. The Service DNS name follows the convention _<connect_name>_-server._<namespace>_.svc.cluster.local. For example, the DNS name is spark-connect-server.<your_namespace>.svc.cluster.local. **

**5. Record the Service DNS name for use in the workbench connection string: **

    memory: 512m     template:       spec:         containers:         - name: spark-kubernetes-executor           image: quay.io/opendatahub/data-processing:Spark-v4.0.1           imagePullPolicy: Always         securityContext: {} 

$ oc apply -f spark-connect-server.yaml 

$ oc get pods -n <your_namespace> -l sparkoperator.k8s.io/launched-by-spark-operator=true 

NAME                     READY   STATUS    RESTARTS   AGE spark-connect-server     1/1     Running   0          30s 

$ oc get svc -n <your_namespace> -l sparkoperator.k8s.io/connect-name=spark-connect 

NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                   AGE spark-connect-server     ClusterIP   172.30.x.x      <none>        7078/TCP,7079/TCP,4040/TCP,15002/TCP      30s 

**Workbench users use this DNS name with port 15002 to construct the sc:// connection URL in **their workbench notebooks. 

4.4. RUN PYSPARK WORKLOADS FROM AN OPENSHIFT AI WORKBENCH 

You can connect to a Spark Connect server from an OpenShift AI Jupyter workbench and run distributed PySpark workloads directly from your notebook. Spark Connect supports DataFrame operations and Spark SQL, so you can process large datasets without managing Spark infrastructure. 

Prerequisites 

A Spark Connect server is deployed and running on your OpenShift AI cluster. For instructions, see Deploy a Spark Connect server on OpenShift AI . 

The ClusterIP Service for the Spark Connect server is available, and you know the Service DNS name. 

An OpenShift AI Jupyter workbench is running. A minimal Jupyter image with CPU support is sufficient for Spark Connect workloads, such as "Jupyter | Minimal | CPU | Python 3.12". 

Procedure 

1. In your Jupyter notebook, install PySpark and the required dependencies by running the following command in a notebook cell: 

IMPORTANT 

The PySpark version must match the Spark version used in the Spark Connect server container image. A version mismatch causes connection failures. After the installation completes, restart the notebook kernel so that the new packages take effect. 

2. Construct the Spark Connect URL by using the Service DNS name and port 15002. The URL follows this format: 

**For a SparkConnect resource named spark-connect deployed in {dbd-config-default-namespace}, the URL is: **

**3. Create a SparkSession by using the sc:// connection URL. **Run the following code in a notebook cell: 

spark-connect-server.<namespace>.svc.cluster.local 

!pip install -q pyspark==4.0.1 pandas pyarrow grpcio grpcio-status zstandard 

sc://<connect_name>-server.<namespace>.svc.cluster.local:15002 

sc://spark-connect-server.redhat-ods-applications.svc.cluster.local:15002 

from pyspark.sql import SparkSession 

NOTE 

**Replace the Service DNS name and namespace if your Spark Connect server is **deployed in a different namespace. 

4. Run a PySpark DataFrame workload to verify the connection. The following example creates a DataFrame, applies a filter, and displays the results: 

The expected output is as follows: 

4.5. TROUBLESHOOT SPARK CONNECT WORKBENCH CONNECTIVITY 

If you cannot connect to the Spark Connect server from your OpenShift AI workbench, you can diagnose the problem by checking the server pod status, verifying the Service endpoint, and confirming that NetworkPolicy rules allow gRPC traffic on port 15002. 

Prerequisites 

A Spark Connect server has been deployed. For instructions, see Deploy a Spark Connect server on OpenShift AI. 

The OpenShift CLI (`oc`) is installed. 

You have access to the namespace where the Spark Connect server is deployed. 

PROCEDURE 

**The following commands use spark-connect-server as the pod and Service name. The Operator derives these names from the metadata.name of your SparkConnect custom resource by appending -server. If your SparkConnect resource uses a different name, replace spark-connect-server with _<your_connect_name>_-server in all commands. **

1. Check the Spark Connect server pod status and logs. **In the following commands, replace _<namespace>_ with the namespace where the **SparkConnect resource is deployed: 

spark = SparkSession.builder.remote(     "sc://spark-connect-server.redhat-ods-applications.svc.cluster.local:15002" ).getOrCreate() 

data = [("Alice", 34), ("Bob", 45), ("Claire", 66)] df = spark.createDataFrame(data, ["Name", "Age"]) df.filter(df.Age > 40).show() 

+------+---+ |  Name|Age| +------+---+ |   Bob| 45| |Claire| 66| +------+---+ 

**If the pod is not in Running status, inspect the pod events for startup failures: **

Check the server logs for error messages: 

**2. Verify that the ClusterIP Service exists and has the correct selector labels. **

**If no Service is returned, verify that the SparkConnect custom resource has been applied correctly. The Operator creates the Service automatically during reconciliation. **

**Inspect the Service details to confirm that the selector labels and port match: **

**The Service should select pods with labels sparkoperator.k8s.io/launched-by-spark-operator: true, sparkoperator.k8s.io/connect-name: _<connect_name>_, spark-role: connect-server, and spark-version: _<spark_version>_. The Service exposes ports 7078, **7079, 4040, and 15002. 

**3. Verify that the Service DNS name resolves from inside the workbench pod. **Find the workbench pod name: 

Test DNS resolution from inside the workbench pod. In the following command, replace **_<workbench_pod>_ and _<workbench_namespace>_ with your workbench pod name and **namespace: 

**If DNS resolution fails, verify that the Service exists in the expected namespace. **

**4. Verify that the NetworkPolicy allows traffic on port 15002 from your workbench. **Check that the workbench pod has the required label: 

Check that the workbench namespace has the required label: 

$ oc get pods -n <namespace> -l sparkoperator.k8s.io/launched-by-spark-operator=true 

$ oc describe pod spark-connect-server -n <namespace> 

$ oc logs spark-connect-server -n <namespace> 

$ oc get svc -n <namespace> -l sparkoperator.k8s.io/connect-name=spark-connect 

$ oc describe svc spark-connect-server -n <namespace> 

$ oc get pods --all-namespaces -l opendatahub.io/workbenches=true 

$ oc exec -n <workbench_namespace> <workbench_pod> -- nslookup spark-connect-server. <namespace>.svc.cluster.local 

$ oc get pod <workbench_pod> -n <workbench_namespace> --show-labels | grep opendatahub.io/workbenches 

$ oc get namespace <workbench_namespace> --show-labels | grep opendatahub.io/dashboard 

**If either label is missing, the spark-operator-allow-internal NetworkPolicy blocks the gRPC traffic. The workbench pod must have the opendatahub.io/workbenches: "true" label, and the workbench namespace must have the opendatahub.io/dashboard: "true" label. **

5. Test gRPC connectivity from the workbench pod. Open a remote shell on the workbench pod and attempt a PySpark connection: 

Inside the shell, run a basic connection test: 

If this command succeeds but the notebook cell fails, restart the notebook kernel to reload the installed packages. 

Additional resources 

Apache Spark Connect Overview 

4.6. SPARKCONNECT CUSTOM RESOURCE AND INFRASTRUCTURE REFERENCE 

**You can use the following reference tables to understand the fields in the SparkConnect custom resource, the RBAC resources required by the Spark Operator, the NetworkPolicy rules for workbench **connectivity, and the PySpark client dependencies. 

IMPORTANT 

The SparkConnect custom resource is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

4.6.1. SparkConnect custom resource fields 

**The SparkConnect custom resource uses the sparkoperator.k8s.io/v1alpha1 API version. The **following table describes the key fields. 

Table 4.1. SparkConnect custom resource fields 

Field Type Description 

$ oc rsh -n <workbench_namespace> <workbench_pod> 

python -c "from pyspark.sql import SparkSession; spark = SparkSession.builder.remote('sc://spark-connect-server. <namespace>.svc.cluster.local:15002').getOrCreate(); print(spark.version)" 

**metadata.name **String The name of the SparkConnect resource. The Operator uses this value to derive the server pod **name and Service name by appending -server. **

**metadata.namespace **String The namespace where the SparkConnect server is **deployed. If you use a namespace other than {dbd-config-default-namespace}, you must manually create RBAC and NetworkPolicy resources. **

**spec.sparkVersion **String The version of Apache Spark that the Spark Connect server uses. This value must match the version in the container image. 

**spec.image **String Optional. The default container image for the server and executor containers. Per-container images in **spec.server.template or spec.executor.template take precedence. **

**spec.sparkConf **Map Optional. Spark configuration properties, equivalent **to --conf options in spark-submit. **

**spec.hadoopConf **Map Optional. Hadoop configuration properties. The **Operator automatically adds the spark.hadoop. **prefix. 

**spec.server.template **PodTemplateS pec 

The pod template for the Spark Connect server. Use this to configure the container image, resource requests, limits, security context, and service account. Set the service account at **spec.server.template.spec.serviceAccountNa me. **

**spec.server.service **Service **Optional. Custom Service specification for the **Spark Connect server. If omitted, the Operator **creates a default ClusterIP Service with ports 7078 **(driver-rpc), 7079 (blockmanager), 4040 (web-ui), and 15002 (gRPC). 

**spec.executor.instances **Integer The number of executor instances to run. Minimum value is 0. 

**spec.executor.cores **Integer The number of CPU cores per executor. Minimum value is 1. 

**spec.executor.memory **String **The amount of memory per executor, such as 512m or 1Gi. **

Field Type Description 

**spec.executor.template **PodTemplateS pec 

The pod template for executor pods. Use this to configure the executor container image and resources. 

**spec.dynamicAllocation **Object Optional. Configures dynamic allocation of executors, available since Spark 3.0 with the Kubernetes scheduler backend. 

Field Type Description 

4.6.2. SparkConnect custom resource example 

**The following example creates a SparkConnect server with two executor instances in the {dbd-config-default-namespace} namespace: **

**securityContext: {} at the pod level delegates security enforcement to the OpenShift **restricted-v2 Security Context Constraint. Do not add explicit security context fields such as **runAsNonRoot or capabilities.drop, because OpenShift applies these constraints **

apiVersion: sparkoperator.k8s.io/v1alpha1 kind: SparkConnect metadata:   name: spark-connect   namespace: redhat-ods-applications spec:   sparkVersion: 4.0.1   server:     template:       spec:         containers:         - name: spark-kubernetes-driver           image: quay.io/opendatahub/data-processing:Spark-v4.0.1           imagePullPolicy: Always           resources:             requests:               cpu: 1               memory: 1Gi             limits:               cpu: 1               memory: 1Gi         serviceAccountName: spark-operator-spark         securityContext: {}   executor:     instances: 2     cores: 1     memory: 512m     template:       spec:         containers:         - name: spark-kubernetes-executor           image: quay.io/opendatahub/data-processing:Spark-v4.0.1           imagePullPolicy: Always         securityContext: {} 

automatically. 

**spec.server.template.spec.serviceAccountName must reference a service account with **sufficient RBAC permissions to manage executor pods. 

4.6.3. RBAC resources 

**The Spark Operator creates the following RBAC resources in the {dbd-config-default-namespace} **namespace during initial deployment. If you deploy a SparkConnect server in a different namespace, you must recreate these resources manually. 

Table 4.2. ServiceAccount 

Field Value 

Name **spark-operator-spark **

Purpose Identity for the Spark Connect server pod and Spark driver, which creates and manages executor pods. 

Table 4.3. Role permissions 

API group Resources Verbs 

**"" (core) pods, configmaps, persistentvolumeclaims, services **

**get, list, watch, create, update, patch, delete, deletecollection **

Table 4.4. RoleBinding 

Field Value 

Name **spark-role-binding **

Role reference **spark-role **

Subject **ServiceAccount spark-operator-spark **

4.6.4. NetworkPolicy 

**The Spark Operator creates a NetworkPolicy named spark-operator-allow-internal in the {dbd-config-default-namespace} namespace. This policy controls ingress traffic to pods launched by the **Operator. 

Table 4.5. NetworkPolicy ingress rules 

Port Protocol Purpose 

7078 TCP Spark driver remote procedure call (RPC) communication between driver and executor pods. 

7079 TCP Spark block manager data transfer between pods. 

4040 TCP Spark UI for monitoring running applications. 

15002 TCP Spark Connect gRPC endpoint for workbench connectivity. 

The port 15002 ingress rule allows traffic from: 

**Any pod in the same namespace through podSelector: {}. **

**Workbench pods labeled opendatahub.io/workbenches: "true" in namespaces labeled opendatahub.io/dashboard: "true". This combination enables workbenches running in rhods-**notebooks or other dashboard-managed namespaces to reach the Spark Connect server. 

4.6.5. Auto-created Service 

**When you create a SparkConnect custom resource, the Operator automatically creates a ClusterIP Service. **

Table 4.6. Auto-created Service details 

Field Value 

Name **_<connect_name>_-server, where _<connect_name>_ is the metadata.name of the SparkConnect resource. **

Type ClusterIP 

Ports 7078 (driver-rpc), 7079 (blockmanager), 4040 (web-ui), 15002 (gRPC) 

Selector labels **sparkoperator.k8s.io/launched-by-spark-operator: true, sparkoperator.k8s.io/connect-name: _<connect_name>_, spark-role: connect-server, and spark-version: _<spark_version>_ **

DNS name **_<connect_name>_-server._<namespace>_.svc.cluster.local **

4.6.6. PySpark client dependencies 

Install the following Python packages in your workbench to connect to the Spark Connect server. The PySpark version must match the Spark version used in the server container image. 

Table 4.7. PySpark client dependencies 

Package Version Purpose 

**pyspark **4.0.1 PySpark client library with Spark Connect support. Must match the server image Spark version. 

**pandas **Latest compatible **Required for DataFrame interoperability and toPandas() result **collection. 

**pyarrow **Latest compatible Columnar data interchange between PySpark and pandas. 

**grpcio **Latest compatible **gRPC client library for the sc:// protocol connection. **

**grpcio-status **Latest compatible gRPC status code handling for error reporting. 

**zstandard **Latest compatible Zstandard compression support for Spark Connect protocol communication. 