# Red_Hat_OpenShift_AI_Self-Managed-3.5-Working_in_your_data_science_IDE-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Working in your data science IDE

Working in your data science IDE from Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Working in your data science IDE

Working in your data science IDE from Red Hat OpenShift AI Self-Managed

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

Prepare your data science integrated development environment (IDE) for developing machine learning models.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. ACCESS YOUR WORKBENCH IDE 

CHAPTER 2 WORKING IN JUPYTERLAB 2.1. CREATE AND IMPORT JUPYTER NOTEBOOKS 

2.1.1. Create a Jupyter notebook 2.1.2. Upload an existing notebook file to JupyterLab from local storage 2.1.3. Additional resources 

2.2. COLLABORATE ON JUPYTER NOTEBOOKS BY USING GIT 2.2.1. Uploading an existing notebook file from a Git repository by using JupyterLab 2.2.2. Uploading an existing notebook file to JupyterLab from a Git repository by using the CLI 2.2.3. Updating your project with changes from a remote Git repository 2.2.4. Pushing project changes to a Git repository 

2.3. MANAGE PYTHON PACKAGES 2.3.1. Viewing Python packages installed on your workbench 2.3.2. Installing Python packages on your workbench 

2.4. TROUBLESHOOTING REFERENCE: WORKBENCHES FOR USERS 

CHAPTER 3 WORKING IN CODE-SERVER 3.1. CREATE CODE-SERVER WORKBENCHES 

3.1.1. Create a workbench 3.1.2. Upload an existing notebook file to code-server from local storage 

3.2. COLLABORATE ON WORKBENCHES IN CODE-SERVER BY USING GIT 3.2.1. Uploading an existing notebook file from a Git repository by using code-server 3.2.2. Uploading an existing notebook file to code-server from a Git repository by using the CLI 3.2.3. Updating your project in code-server with changes from a remote Git repository 3.2.4. Pushing project changes in code-server to a Git repository 

3.3. MANAGE PYTHON PACKAGES IN CODE-SERVER 3.3.1. Viewing Python packages installed on your code-server workbench 3.3.2. Installing Python packages on your code-server workbench 

3.4. INSTALL EXTENSIONS WITH CODE-SERVER 

CHAPTER 4 R-LANGUAGE WORKFLOWS AFTER RSTUDIO REMOVAL 4.1. POST-UPGRADE BEHAVIOR OF EXISTING RSTUDIO WORKBENCHES 4.2. ALTERNATIVE IDES FOR R WORKFLOWS 4.3. SET UP R DEVELOPMENT IN CODE-SERVER OR JUPYTERLAB 4.4. BUILD UNSUPPORTED RSTUDIO SERVER WORKBENCH IMAGES 4.5. RSTUDIO SELF-BUILD SOURCE FILES 

3 

4 

5 5 5 5 6 6 6 7 7 8 9 9 9 11 

13 13 13 17 18 18 18 19 

20 20 21 21 22 

24 24 25 26 28 30 

### PREFACE

In Red Hat OpenShift AI, when you create a workbench, you select a workbench image that includes an integrated development environment (IDE) for developing your machine learning (ML) models. 

You can use the following data science IDEs for developing ML models with OpenShift AI: 

JupyterLab 

code-server 

NOTE 

Starting with OpenShift AI 3.5, the RStudio Server and CUDA - RStudio Server workbench images have been removed. For more information, see Support removals. 

### CHAPTER 1. ACCESS YOUR WORKBENCH IDE

To access a workbench IDE, use the link provided in the OpenShift AI interface. 

Prerequisite 

You have created a project and a workbench. 

Procedure 

1. From the OpenShift AI dashboard, click Projects. 

2. Click the name of the project that contains the workbench. 

3. Click the Workbenches tab. 

4. If the status of the workbench is Running, skip to the next step. If the status of the workbench is Stopped, in the Status column for the workbench, click Start. 

The Status column changes from Stopped to Starting when the workbench server is starting, and then to Running when the workbench has successfully started. 

5. Click the open icon (  ) next to the workbench. 

Verification 

A new browser window opens for the workbench IDE. 

### CHAPTER 2. WORKING IN JUPYTERLAB

JupyterLab is a web-based interactive development environment for Jupyter notebooks, code, and data. You can configure and arrange workflows in data science and machine learning. JupyterLab is an open source web application that supports over 40 programming languages, including Python and R. 

2.1. CREATE AND IMPORT JUPYTER NOTEBOOKS 

You can create a blank Jupyter notebook or import a Jupyter notebook in JupyterLab from several different sources. 

2.1.1. Create a Jupyter notebook 

You can create a Jupyter notebook from an existing notebook container image to access its resources and properties. The Workbench control panel contains a list of available container images that you can run as a single-user workbench. 

Prerequisites 

Ensure that you have logged in to Red Hat OpenShift AI. 

Ensure that you have launched your workbench and logged in to JupyterLab. 

The workbench image exists in a registry, image stream, and is accessible. 

Procedure 

1. Click File → New → Notebook. 

2. If prompted, select a kernel for your Jupyter notebook from the list. If you want to use a kernel, click Select. If you do not want to use a kernel, click No Kernel. 

Verification 

Check that the notebook file is visible in the JupyterLab interface. 

2.1.2. Upload an existing notebook file to JupyterLab from local storage 

You can load an existing notebook file from local storage into JupyterLab to continue work, or adapt a project for a new use case. 

Prerequisites 

Credentials for logging in to JupyterLab. 

You have a launched and running workbench based on a JupyterLab image. 

A notebook file exists in your local storage. 

Procedure 

1. In the File Browser in the left sidebar of the JupyterLab interface, click Upload Files (  ). 

2. Locate and select the notebook file and then click Open. The file is displayed in the File Browser. 

Verification 

The notebook file is displayed in the File Browser in the left sidebar of the JupyterLab interface. 

You can open the notebook file in JupyterLab. 

2.1.3. Additional resources 

Collaborating on Jupyter notebooks by using Git 

2.2. COLLABORATE ON JUPYTER NOTEBOOKS BY USING GIT 

If your files are stored in Git version control, you can clone a Git repository to work with them in JupyterLab. When you are ready, you can push your changes back to the Git repository so that others can review or use your models. 

2.2.1. Uploading an existing notebook file from a Git repository by using JupyterLab 

You can use the JupyterLab user interface to clone a Git repository into your workspace to continue your work or integrate files from an external project. 

Prerequisites 

You have a launched and running workbench based on a JupyterLab image. 

Read access for the Git repository you want to clone. 

Procedure 

1. Copy the HTTPS URL for the Git repository. 

In GitHub, click   Code → HTTPS and then click the Copy URL to clipboard icon. 

In GitLab, click Code and then click the Copy URL icon under Clone with HTTPS. 

2. In the JupyterLab interface, click the Git Clone button (  ). 

You can also click Git → Clone a repository in the menu, or click the Git icon (  ) and click the Clone a repository button. 

The Clone a repo dialog opens. 

3. Enter the HTTPS URL of the repository that contains your notebook file. 

4. Click CLONE. 

5. If prompted, enter your username and password for the Git repository. 

Verification 

Check that the contents of the repository are visible in the file browser in JupyterLab, or run **the ls command in the terminal to verify that the repository shows as a directory. **

2.2.2. Uploading an existing notebook file to JupyterLab from a Git repository by using the CLI 

You can use the command line interface to clone a Git repository into your workspace to continue your work or integrate files from an external project. 

Prerequisites 

You have a launched and running workbench based on a JupyterLab image. 

Procedure 

1. Copy the HTTPS URL for the Git repository. 

In GitHub, click   Code → HTTPS and then click the Copy URL to clipboard icon. 

In GitLab, click Code and then click the Copy URL icon under Clone with HTTPS. 

2. In JupyterLab, click File → New → Terminal to open a terminal window. 

**3. Enter the git clone command: **

*git clone <git-clone-URL> *

**Replace git-clone-URL> with the HTTPS URL, for example: **

[1234567890@jupyter-nb-jdoe ~]$ git clone https://github.com/example/myrepo.git *Cloning into myrepo... *remote: Enumerating objects: 11, done. remote: Counting objects: 100% (11/11), done. remote: Compressing objects: 100% (10/10), done. remote: Total 2821 (delta 1), reused 5 (delta 1), pack-reused 2810 Receiving objects: 100% (2821/2821), 39.17 MiB | 23.89 MiB/s, done. Resolving deltas: 100% (1416/1416), done. 

Verification 

Check that the contents of the repository are visible in the file browser in JupyterLab, or run **the ls command in the terminal to verify that the repository shows as a directory. **

2.2.3. Updating your project with changes from a remote Git repository 

You can pull changes made by other users into your project from a remote Git repository. 

Prerequisites 

You have configured the remote Git repository. 

You have already imported the Git repository into JupyterLab, and the contents of the repository are visible in the file browser in JupyterLab. 

You have permissions to pull files from the remote Git repository to your local repository. 

You have credentials for logging in to Jupyter. 

You have a launched and running Jupyter server. 

Procedure 

1. In the JupyterLab interface, click the Git button (  ). 

2. Click the Pull latest changes button (  ). 

Verification 

You can view the changes pulled from the remote repository in the History tab of the Git pane. 

2.2.4. Pushing project changes to a Git repository 

To build and deploy your application in a production environment, upload your work to a remote Git repository. 

Prerequisites 

You have opened a Jupyter notebook in the JupyterLab interface. 

You have added the relevant Git repository to your workbench. 

You have permission to push changes to the relevant Git repository. 

You have installed the Git version control extension. 

Procedure 

1. Click File → Save All to save any unsaved changes. 

2. Click the Git icon (  ) to open the Git pane in the JupyterLab interface. 

3. Confirm that your changed files appear under Changed. If your changed files appear under Untracked, click Git → Simple Staging to enable a simplified Git process. 

4. Commit your changes. 

a. Ensure that all files under Changed have a blue checkmark beside them. 

b. In the Summary field, enter a brief description of the changes you made. 

c. Click Commit. 

5. Click Git → Push to Remote to push your changes to the remote repository. 

6. When prompted, enter your Git credentials and click OK. 

Verification 

Your most recently pushed changes are visible in the remote Git repository. 

2.3. MANAGE PYTHON PACKAGES 

In JupyterLab, you can view the Python packages that are installed on your workbench image and install additional packages. 

2.3.1. Viewing Python packages installed on your workbench 

You can check which Python packages are installed on your workbench and which version of the package **you have by running the pip tool in a notebook cell. **

Prerequisites 

Log in to JupyterLab and open a Jupyter notebook. 

Procedure 

1. Enter the following in a new cell in your Jupyter notebook: 

!pip list 

2. Run the cell. 

Verification 

The output shows an alphabetical list of all installed Python packages and their versions. For **example, if you use the pip list command immediately after creating a workbench that uses the **Minimal image, the first packages shown are similar to the following: 

Package                           Version --------------------------------- ----------aiohttp                           3.7.3 alembic                           1.5.2 appdirs                           1.4.4 argo-workflows                    3.6.1 argon2-cffi                       20.1.0 async-generator                   1.10 async-timeout                     3.0.1 attrdict                          2.0.1 attrs                             20.3.0 backcall                          0.2.0 

Additional resources 

Installing Python packages on your workbench 

2.3.2. Installing Python packages on your workbench 

You can install Python packages that are not part of the default workbench by adding the package and **the version to a requirements.txt file and then running the pip install command in a notebook cell. **

NOTE 

Although you can install packages directly, it is recommended that you use a **requirements.txt file so that the packages stated in the file can be easily re-used across **different workbenches. 

Prerequisites 

Log in to JupyterLab and open a Jupyter notebook. 

Procedure 

1. Create a new text file using one of the following methods: 

Click + to open a new launcher and then click Text file. 

Click File → New → Text File. 

**2. Rename the text file to requirements.txt. **

a. Right-click the name of the file and then click Rename Text. The Rename File dialog opens. 

**b. Enter requirements.txt in the New Name field and then click Rename. **

**3. Add the packages to install to the requirements.txt file. **

altair 

**You can specify the exact version to install by using the == (equal to) operator, for example: **

altair==4.1.0 

NOTE 

Red Hat recommends specifying exact package versions to enhance the stability of your workbench over time. New package versions can introduce undesirable or unexpected changes in your environment’s behavior. 

To install multiple packages at the same time, place each package on a separate line. 

**4. Install the packages in requirements.txt to your server by using a notebook cell. **

a. Create a new notebook cell and enter the following command: 

!pip install -r requirements.txt 

b. Run the cell by pressing Shift and Enter. 

IMPORTANT 

**The pip install command installs the package on your workbench. However, you must run the import statement in a code cell to use the package in your code. **

import altair 

Verification 

**Confirm that the packages in the requirements.txt file appear in the list of packages installed **on the workbench. See Viewing Python packages installed on your workbench  for details. 

2.4. TROUBLESHOOTING REFERENCE: WORKBENCHES FOR USERS 

If you are seeing errors in Red Hat OpenShift AI related to Jupyter, your Jupyter notebooks, or your workbench, review the following troubleshooting scenarios to identify the cause and resolve the issue. 

If you cannot see your problem here or in the release notes, contact Red Hat Support. 

I see a 403: Forbidden error when I log in to Jupyter 

Problem 

If your cluster administrator has configured OpenShift AI user groups, your username might not be added to the default user group or the default administrator group for OpenShift AI. 

Resolution 

Contact your cluster administrator so that they can add you to the correct group/s. 

My workbench does not start 

Problem The OpenShift cluster that hosts your workbench might not have access to enough resources, or the workbench pod might have failed. 

Resolution 

Check the logs in the Events section in OpenShift for error messages associated with the problem. For example: 

Server requested 2021-10-28T13:31:29.830991Z [Warning] 0/7 nodes are available: 2 Insufficient memory, 2 node(s) had taint {node-role.kubernetes.io/infra: }, that the pod didn't tolerate, 3 node(s) had taint {node-role.kubernetes.io/master: }, that the pod didn't tolerate. 

Contact your cluster administrator with details of any relevant error messages so that they can perform further checks. 

Workbench fails to start after a referenced secret is deleted 

Problem A Kubernetes Secret that was referenced as an environment variable was deleted from the project namespace. The workbench container specification still references the deleted secret, **causing a CreateContainerConfigError in the Events section. **

Resolution Open the workbench edit form, locate the danger alert for the missing secret in the Environment variables section, and click Remove this reference to remove the broken reference. Then click Update workbench. 

For more information, see Troubleshooting existing secret references in workbenches . 

I see a database or disk is full error or a no space left on device error when I run my notebook cells 

Problem 

You might have run out of storage space on your workbench. 

Resolution 

Contact your cluster administrator so that they can perform further checks. 

### CHAPTER 3. WORKING IN CODE-SERVER

Code-server is a web-based interactive development environment supporting multiple programming languages, including Python, for working with Jupyter notebooks. With the code-server workbench image, you can customize your workbench environment to meet your needs using a variety of extensions to add new languages, themes, debuggers, and connect to additional services. For more information, see code-server in GitHub . 

NOTE 

Elyra-based pipelines are not available with the code-server workbench image. 

3.1. CREATE CODE-SERVER WORKBENCHES 

You can create a blank Jupyter notebook or import a Jupyter notebook in code-server from several different sources. 

3.1.1. Create a workbench 

When you create a workbench, you specify an image (an IDE, packages, and other dependencies). You can also configure connections, cluster storage, and add container storage. 

Prerequisites 

You have logged in to Red Hat OpenShift AI. 

You have created a project. 

If you created a Simple Storage Service (S3) account outside of Red Hat OpenShift AI and want to connect to your existing S3 storage buckets, you have the following credential information: 

Endpoint URL 

Access key 

Secret key 

Region 

Bucket name 

For more information, see Working with data in an S3-compatible object store . 

Procedure 

1. From the OpenShift AI dashboard, click Projects, click the name of the project that you want to add the workbench to, and then click the Workbenches tab. 

2. Click Create workbench. The Create workbench page opens. 

3. In the Name field, enter a unique name for your workbench. Optional: Click Edit resource name to change the default resource name for your workbench. The resource name is used to identify your resource in Kubernetes. Valid characters include lowercase letters, numbers, and hyphens (-). The resource name cannot exceed 250 

characters, and it must start with a letter and end with a letter or number. 

NOTE 

You cannot change the resource name after the workbench is created. You can edit only the display name and the description. 

Optional: In the Description field, enter a description for your workbench. 

4. In the Workbench image section, complete the fields to specify the workbench image to use with your workbench. From the Image selection list, select a workbench image that suits your use case. A workbench image includes an IDE and Python packages (reusable code). If project-scoped images exist, the Image selection list includes subheadings to distinguish between global images and project-scoped images. 

NOTE 

The Image selection list shows only workbench images that have been enabled by an administrator. If an expected workbench image is not visible, contact your OpenShift AI administrator. 

Optional: Click View package information to view a list of packages that are included in the image that you selected. 

If the workbench image has multiple versions available, select the version to use from the Version selection list. Red Hat recommends that you use the latest version. 

NOTE 

You can change the workbench image after you create the workbench. 

5. In the Deployment size section, from the Hardware profile list, select a suitable hardware profile for your workbench. If project-scoped hardware profiles exist, the Hardware profile list includes subheadings to distinguish between global hardware profiles and project-scoped hardware profiles. 

The hardware profile specifies the CPU and memory requests and limits for the container. 

a. Optional: To change the default values, click Customize resource requests and limits. 

6. Optional: In the Environment variables section, add environment variables to provide credentials or configuration values to the workbench. Setting environment variables during workbench configuration means you do not need to define them in the body of your notebooks or with the IDE command line interface. Environment variables set here are available in the workbench container when it starts. 

a. Click Add environment variable. 

b. From the Variable type list, select the type of environment variable to add: 

Select Secret to create a new Kubernetes Secret with key-value pairs entered directly or uploaded from a file. 

Select Config Map to create a new ConfigMap for non-sensitive configuration values. 

Select Existing secret to reference a pre-existing Kubernetes Secret already present in the project namespace. Use this option for credentials managed outside OpenShift AI by your platform team or external tools. 

c. If you selected Secret, choose a data entry method: 

Select Key / value to enter key-value pairs manually. 

Select Upload to import key-value pairs from an environment file. 

d. If you selected Existing secret, complete the following steps: 

i. From the Secrets dropdown, search for and select one or more secrets by name. **Only Kubernetes Secrets of type Opaque that are not managed by the connections **framework appear in this dropdown. 

ii. For each selected secret, expand the secret entry to view its keys. Choose Select all to inject all keys, or select individual key checkboxes to inject specific keys. A badge displays the number of selected keys out of the total keys available. 

iii. Required: Review any environment variable name conflict warnings. If the same key name exists in multiple sources, such as across existing secrets and inline secrets, the form displays a warning that lists the conflicting key names and their sources. To resolve a conflict, clear the conflicting key from one source, remove a secret reference, or rename an inline key. 

NOTE 

Environment variables from existing secrets are set at workbench startup. If secret values change after the workbench starts, for example during a credential rotation, restart the workbench to pick up the new values. 

e. Optional: To add another environment variable, click Add environment variable and repeat the preceding steps. For more information about environment variable types and secret eligibility, see Environment variable types for workbenches . For detailed reference information about the existing secret interface, see Existing secret reference details for workbenches . 

7. In the Cluster storage section, configure the storage for your workbench. Select one of the following options: 

Create new persistent storage to create storage that is retained after you shut down your workbench. Complete the relevant fields to define the storage: 

a. Enter a name for the cluster storage. 

b. Enter a description for the cluster storage. 

c. Select a storage class for the cluster storage. 

NOTE 

You cannot change the storage class after you add the cluster storage to the workbench. 

d. For storage classes that support multiple access modes, select an Access mode to define how the volume can be accessed. For more information, see About persistent storage. Only the access modes that have been enabled for the storage class by your cluster and OpenShift AI administrators are visible. 

e. Under Persistent storage size, enter a new size in gibibytes or mebibytes. 

Use existing persistent storage to reuse existing storage and select the storage from the Persistent storage list. 

8. Optional: You can add a connection to your workbench. A connection is a resource that contains the configuration parameters needed to connect to a data source or sink, such as an object storage bucket. You can use storage buckets for storing data, models, and pipeline artifacts. You can also use a connection to specify the location of a model that you want to deploy. In the Connections section, use an existing connection or create a new connection: 

Use an existing connection as follows: 

a. Click Attach existing connections. 

b. From the Connection list, select a connection that you previously defined. 

Create a new connection as follows: 

a. Click Create connection. The Add connection dialog opens. 

b. From the Connection type drop-down list, select the type of connection. The Connection details section is displayed. 

c. If you selected S3 compatible object storage in the preceding step, configure the connection details: 

i. In the Connection name field, enter a unique name for the connection. 

ii. Optional: In the Description field, enter a description for the connection. 

iii. In the Access key field, enter the access key ID for the S3-compatible object storage provider. 

iv. In the Secret key field, enter the secret access key for the S3-compatible object storage account that you specified. 

v. In the Endpoint field, enter the endpoint of your S3-compatible object storage bucket. 

vi. Optional: In the Region field, enter the default region of your S3-compatible object storage account. 

vii. Optional: In the Bucket field, enter the name of your S3-compatible object storage bucket. 

viii. Click Create. 

d. If you selected URI in the preceding step, configure the connection details: 

i. In the Connection name field, enter a unique name for the connection. 

ii. Optional: In the Description field, enter a description for the connection. 

iii. In the URI field, enter the Uniform Resource Identifier (URI). 

iv. Click Create. 

9. Click Create workbench. 

Verification 

The workbench that you created is visible on the Workbenches tab for the project. 

Any cluster storage that you associated with the workbench during the creation process is displayed on the Cluster storage tab for the project. 

The Status column on the Workbenches tab displays a status of Starting when the workbench server is starting, and Ready when the workbench has successfully started. 

Optional: Click the open icon (  ) to open the IDE in a new window. 

Additional resources 

Working with data in an S3-compatible object store 

About persistent storage 

3.1.2. Upload an existing notebook file to code-server from local storage 

You can load an existing notebook file from local storage into code-server to continue work, or adapt a project for a new use case. 

Prerequisites 

You have a running code-server workbench. 

You have a notebook file in your local storage. 

Procedure 

1. In your code-server window, from the Activity Bar, select the menu icon (  ) → File → Open File. 

2. In the Open File dialog, click the Show Local button. 

3. Locate and select the notebook file and then click Open. The file is displayed in the code-server window. 

4. Save the file and then push the changes to your repository. 

Verification 

The notebook file is displayed in the code-server Explorer view. 

You can open the notebook file in the code-server window. 

3.2. COLLABORATE ON WORKBENCHES IN CODE-SERVER BY USING GIT 

If your files are stored in Git version control, you can clone a Git repository to work with them in codeserver. When you are ready, you can push your changes back to the Git repository so that others can review or use your models. 

3.2.1. Uploading an existing notebook file from a Git repository by using code-server 

You can use the code-server user interface to clone a Git repository into your workspace to continue your work or integrate files from an external project. 

Prerequisites 

You have a running code-server workbench. 

You have read access for the Git repository you want to clone. 

Procedure 

1. Copy the HTTPS URL for the Git repository. 

In GitHub, click   Code → HTTPS and then click the Copy URL to clipboard icon. 

In GitLab, click Code and then click the Copy URL icon under Clone with HTTPS. 

2. In your code-server window, from the Activity Bar, select the menu icon (  ) → View → Command Palette. 

**3. In the Command Palette, enter Git: Clone, and then select Git: Clone from the list. **

4. Paste the HTTPS URL of the repository that contains your notebook file, and then press Enter. 

5. If prompted, enter your username and password for the Git repository. 

6. Select a folder to clone the repository into, and then click OK. 

7. When the repository is cloned, a dialog opens asking if you want to open the cloned repository. Click Open in the dialog. 

Verification 

Check that the contents of the repository are visible in the code-server Explorer view, or run the **ls command in the terminal to verify that the repository shows as a directory. **

3.2.2. Uploading an existing notebook file to code-server from a Git repository by using the CLI 

You can use the command line interface to clone a Git repository into your workspace to continue your work or integrate files from an external project. 

Prerequisites 

You have a running code-server workbench. 

Procedure 

1. Copy the HTTPS URL for the Git repository. 

In GitHub, click   Code → HTTPS and then click the Copy URL to clipboard icon. 

In GitLab, click Code and then click the Copy URL icon under Clone with HTTPS. 

2. In your code-server window, from the Activity Bar, select the menu icon (  ) → Terminal → New Terminal to open a terminal window. 

**3. Enter the git clone command: **

*git clone <git-clone-URL> *

**Replace <git-clone-URL> with the HTTPS URL, for example: **

$ git clone https://github.com/example/myrepo.git *Cloning into myrepo... *remote: Enumerating objects: 11, done. remote: Counting objects: 100% (11/11), done. remote: Compressing objects: 100% (10/10), done. remote: Total 2821 (delta 1), reused 5 (delta 1), pack-reused 2810 Receiving objects: 100% (2821/2821), 39.17 MiB | 23.89 MiB/s, done. Resolving deltas: 100% (1416/1416), done. 

Verification 

Check that the contents of the repository are visible in the code-server Explorer view, or run the **ls command in the terminal to verify that the repository shows as a directory. **

3.2.3. Updating your project in code-server with changes from a remote Git repository 

You can pull changes made by other users into your workbench from a remote Git repository. 

Prerequisites 

You have configured the remote Git repository. 

You have imported the Git repository into code-server, and the contents of the repository are visible in the Explorer view in code-server. 

You have permissions to pull files from the remote Git repository to your local repository. 

You have a running code-server workbench. 

Procedure 

1. In your code-server window, from the Activity Bar, click the Source Control icon (  ). 

2. Click the Views and More Actions button (…), and then select Pull. 

Verification 

You can view the changes pulled from the remote repository in the Source Control pane. 

3.2.4. Pushing project changes in code-server to a Git repository 

To build and deploy your application in a production environment, upload your work to a remote Git repository. 

Prerequisites 

You have a running code-server workbench. 

You have added the relevant Git repository in code-server. 

You have permission to push changes to the relevant Git repository. 

You have installed the Git version control extension. 

Procedure 

1. In your code-server window, from the Activity Bar, select the menu icon (  ) → File → Save All to save any unsaved changes. 

2. Click the Source Control icon (  ) to open the Source Control pane. 

3. Confirm that your changed files appear under Changes. 

4. Next to the Changes heading, click the Stage All Changes button (+). The staged files move to the Staged Changes section. 

5. In the Message field, enter a brief description of the changes you made. 

6. Next to the Commit button, click the More Actions…​ button, and then click Commit & Sync. 

7. If prompted, enter your Git credentials and click OK. 

Verification 

Your most recently pushed changes are visible in the remote Git repository. 

3.3. MANAGE PYTHON PACKAGES IN CODE-SERVER 

In code-server, you can view the Python packages that are installed on your workbench image and install additional packages. 

3.3.1. Viewing Python packages installed on your code-server workbench 

You can check which Python packages are installed on your workbench and which version of the package **you have by running the pip tool in a terminal window. **

Prerequisites 

You have a running code-server workbench. 

Procedure 

1. In your code-server window, from the Activity Bar, select the menu icon (  ) → Terminal → New Terminal to open a terminal window. 

**2. Enter the pip list command. **

pip list 

Verification 

The output shows an alphabetical list of all installed Python packages and their versions. For **example, if you use the pip list command immediately after creating a workbench that uses the **Minimal image, the first packages shown are similar to the following: 

Package                  Version ------------------------ ----------asttokens                2.4.1 boto3                    1.34.162 botocore                 1.34.162 cachetools               5.5.0 certifi                  2024.8.30 charset-normalizer       3.4.0 comm                     0.2.2 contourpy                1.3.0 cycler                   0.12.1 debugpy                  1.8.7 

3.3.2. Installing Python packages on your code-server workbench 

You can install Python packages that are not part of the default workbench image by adding the **package and the version to a requirements.txt file and then running the pip install command in a **terminal window. 

NOTE 

Although you can install packages directly, it is recommended that you use a **requirements.txt file so that the packages stated in the file can be easily re-used across **different workbenches. 

Prerequisites 

You have a running code-server workbench. 

Procedure 

1. In your code-server window, from the Activity Bar, select the menu icon (  ) → File → New Text File to create a new text file. 

2. Add the packages to install to the text file. 

altair 

**You can specify the exact version to install by using the == (equal to) operator, for example: **

altair==4.1.0 

NOTE 

Red Hat recommends specifying exact package versions to enhance the stability of your workbench over time. New package versions can introduce undesirable or unexpected changes in your environment’s behavior. 

To install multiple packages at the same time, place each package on a separate line. 

**3. Save the text file as requirements.txt. **

4. From the Activity Bar, select the menu icon (  ) → Terminal → New Terminal to open a terminal window. 

**5. Install the packages in requirements.txt to your server by using the following command: **

pip install -r requirements.txt 

IMPORTANT 

**The pip install command installs the package on your workbench. However, you must run the import statement to use the package in your code. **

import altair 

Verification 

**Confirm that the packages in the requirements.txt file appear in the list of packages installed **on the workbench. See Viewing Python packages installed on your code-server workbench  for details. 

3.4. INSTALL EXTENSIONS WITH CODE-SERVER 

With the code-server workbench image, you can customize your code-server environment by using extensions to add new languages, themes, and debuggers, and to connect to additional services. You can also enhance the efficiency of your data science work with extensions for syntax highlighting, autoindentation, and bracket matching. 

For details about the third-party extensions that you can install with code-server, see the Open VSX Registry. 

Prerequisites 

You are logged in to Red Hat OpenShift AI. 

You have created a project that has a code-server workbench. 

Procedure 

1. From the OpenShift AI dashboard, click Projects. The Projects page opens. 

2. Click the name of the project containing the code-server workbench you want to start. A project details page opens. 

3. Click the Workbenches tab. 

4. If the status of the workbench that you want to use is Running, skip to the next step. If the status of the workbench is Stopped, in the Status column for the workbench, click Start. 

The Status column changes from Stopped to Starting when the workbench server is starting, and then to Running when the workbench has successfully started. 

5. Click the open icon (  ) next to the workbench. The code-server window opens. 

6. In the Activity Bar, click the Extensions icon (  ). 

7. Search for the name of the extension you want to install. 

8. Click Install to add the extension to your code-server environment. 

Verification 

In the Browser - Installed list on the Extensions panel, confirm that the extension you installed is listed. 

### CHAPTER 4. R-LANGUAGE WORKFLOWS AFTER RSTUDIO REMOVAL

Starting with OpenShift AI 3.5, the RStudio Server workbench images have been removed due to licensing compliance requirements. You can continue R-language data science workflows by migrating to a supported IDE or by building your own unsupported RStudio images. 

4.1. POST-UPGRADE BEHAVIOR OF EXISTING RSTUDIO WORKBENCHES 

When you upgrade to OpenShift AI 3.5, several RStudio-related resources are removed from your cluster. Understanding the upgrade impact helps you plan communications to your users and avoid disruption to R-language workloads. 

After you upgrade to OpenShift AI 3.5, the OpenShift AI Operator reconciliation process removes the **following Kubernetes resources from the {dbd-config-default-namespace} namespace: **

**rstudio-rhel9 ImageStream **

**cuda-rstudio-rhel9 ImageStream **

**rstudio-server-rhel9 BuildConfig **

**cuda-rstudio-server-rhel9 BuildConfig **

**rhel-subscription-secret Secret, if it was created for RStudio builds **

Running RStudio workbench pods are not affected by the upgrade because they reference container images by SHA digest. Removing the ImageStream does not terminate or modify already-running containers. However, after the upgrade, the following restrictions apply: 

You cannot create new RStudio workbenches from the OpenShift AI dashboard. 

Stopped RStudio workbenches that referenced the removed ImageStream cannot be restarted from the dashboard. 

**The in-cluster BuildConfig-based build process for RStudio images is no longer available. **

NOTE 

The operator reconciliation behavior removes RStudio resources as part of the standard manifest drift process. If RStudio resources existed in a previous version and are absent from the 3.5 manifests, the operator removes them during reconciliation. 

To prepare for the upgrade, consider the following steps: 

Inventory existing RStudio workbenches on the cluster by listing workbenches in the **{workbench-default-namespace} namespace. **

Communicate the deprecation timeline and available alternatives to affected users. 

Optionally, build and deploy self-built RStudio images before upgrading so that users who cannot immediately migrate have a continuity path. For more information, see Build unsupported RStudio Server workbench images. 

Additional resources 

Alternative IDEs for R workflows 

Set up R development in code-server or JupyterLab 

4.2. ALTERNATIVE IDES FOR R WORKFLOWS 

After the removal of RStudio Server workbench images in OpenShift AI 3.5, you can continue R-language data science workflows by using code-server with the vscode-R extension or JupyterLab with the IRkernel R kernel. Evaluating the capabilities of each IDE helps you select the replacement for your use case. 

Neither code-server nor JupyterLab with R kernel is a direct feature-for-feature replacement for the RStudio IDE. Code-server and JupyterLab approximate many of these capabilities through extensions and packages, but the experience differs. 

The following table compares the R development capabilities of each integrated development environment (IDE). 

Table 4.1. R development feature comparison 

Feature RStudio (removed) 

code-server with vscode-R 

JupyterLab with IRkernel 

R script editing with syntax highlighting Yes Yes Yes 

Interactive R console (REPL) Yes Yes, with radian 

Yes 

Inline plot viewing Yes Yes Yes 

R package management Yes, built-in Yes, through R console 

Yes, through R console 

R Markdown and Quarto rendering Yes, native Yes, with extensions 

Partial, with IRdisplay 

R debugging Yes, built-in Yes, with vscode-R 

Limited 

Shiny application viewer Yes, built-in No built-in viewer 

No built-in viewer 

Environment and data browser Yes, built-in Yes, with vscode-R 

No 

Git integration Yes Yes Yes, with JupyterLab Git extension 

Elyra-based pipeline support No No Yes 

NOTE 

Elyra-based pipelines are not available with the code-server workbench image. If your workflow requires Elyra pipelines with R, use JupyterLab with IRkernel. 

If neither code-server nor JupyterLab meets your R development requirements, you can build and deploy your own unsupported RStudio images. For more information, see Build unsupported RStudio Server workbench images. 

Additional resources 

Set up R development in code-server or JupyterLab 

vscode-R extension 

IRkernel: R kernel for Jupyter 

4.3. SET UP R DEVELOPMENT IN CODE-SERVER OR JUPYTERLAB 

You can set up an R development environment in a code-server or JupyterLab workbench to continue R-language workflows after the removal of RStudio Server in OpenShift AI 3.5. Choose the IDE that best fits your workflow based on the comparison in Alternative IDEs for R workflows . 

Prerequisites 

You have access to a OpenShift AI project. 

A code-server or JupyterLab workbench is created with persistent storage. 

R is available in your workbench. Standard workbench images do not include R and do not have the RHEL repositories required to install it. Use a custom workbench image with R pre-installed. *For more information about creating and importing custom workbench images, see Managing custom workbench images. *

Procedure 

To set up R development in code-server: 

1. Open your code-server workbench from the OpenShift AI dashboard. 

2. Install the vscode-R extension from the Open VSX Registry: 

a. Open the Extensions view by clicking the Extensions icon in the Activity Bar. 

**b. Search for R by REditorSupport. **

c. Click Install. 

3. Open a terminal in code-server and install the R language server package: 

4. Install radian as an enhanced R console: 

$ R -e 'install.packages("languageserver", repos="https://cran.r-project.org")' 

$ pip install radian 

5. Configure code-server to use radian as the R terminal by adding the following setting to your user settings JSON file: 

**Adjust the path to radian based on the output of which radian in your workbench. **

6. Verify the R development environment: 

**a. Open or create an .R file. Confirm that syntax highlighting and code completion are active. **

b. Open the R terminal by running the R: Create R Terminal command from the Command Palette. 

**c. Run a test command such as print("Hello from R") in the R terminal. **

To set up R development in JupyterLab: 

1. Open your JupyterLab workbench from the OpenShift AI dashboard. 

2. Open a terminal in JupyterLab. 

3. Install the IRkernel R package: 

4. Register the R kernel with Jupyter: 

5. Refresh the JupyterLab browser tab. 

6. Verify the R kernel: 

a. Click the + button to open the Launcher. 

b. Confirm that an R option is displayed in the Notebook section. 

**c. Open a new R notebook and run a test command such as print("Hello from R"). **

IMPORTANT 

Packages installed in a workbench persist only if the workbench uses persistent storage. If your workbench does not have persistent storage, you must reinstall R packages each time the workbench restarts. 

Verification 

**In code-server, the R terminal starts successfully with radian, and .R files display syntax **highlighting with code completion. 

{   "r.bracketedPaste": true,   "r.rterm.linux": "/opt/app-root/bin/radian" } 

$ R -e 'install.packages("IRkernel", repos="https://cran.r-project.org")' 

$ R -e 'IRkernel::installspec()' 

In JupyterLab, the R kernel is displayed in the Launcher, and R notebooks run R code successfully. 

Additional resources 

Managing custom workbench images 

R in Visual Studio Code 

vscode-R extension 

IRkernel: R kernel for Jupyter 

radian: an alternative R console 

4.4. BUILD UNSUPPORTED RSTUDIO SERVER WORKBENCH IMAGES 

Starting with OpenShift AI 3.5, the RStudio Server workbench images are no longer included in Red Hat OpenShift AI. You can build your own unsupported RStudio container images from the archived source files and deploy them as custom workbench images. 

IMPORTANT 

Self-built RStudio images are not supported by Red Hat. Red Hat does not provide support for the RStudio software, and self-built images are not covered by Red Hat production service level agreements (SLAs). Review the RStudio licensing terms before you build and use these images. 

Two RStudio image variants are available for self-build: 

RStudio Server: CPU-only variant for R-language data science workflows. 

CUDA - RStudio Server: GPU-accelerated variant that includes the NVIDIA CUDA Toolkit. 

Prerequisites 

**Your build machine is a Red Hat Enterprise Linux system registered with subscriptionmanager. The Dockerfile installs packages from RHEL and CodeReady Builder repositories, **which require an active RHEL subscription on the build machine. 

**You are authenticated to registry.redhat.io on your build machine. Run podman login registry.redhat.io if you have not already authenticated. **

**A container build tool such as podman or docker is installed on your build machine. **

You have access to a container registry that is accessible from your OpenShift cluster. 

Your build environment has internet access. Disconnected or air-gapped builds are not supported. 

Your build machine has at least 1 CPU and 2 GiB memory available for the RStudio Server build, or 1.5 CPUs and 8 GiB memory for the CUDA - RStudio Server build. 

**You have the cluster-admin role in OpenShift, or permission to create ImageStream resources in the {dbd-config-default-namespace} namespace. **

Procedure 

1. Clone or download the RStudio source files from the archived repository branch: 

**The RStudio source files are in the rstudio/rhel9-python-3.11/ directory. Both the CPU and CUDA variants use this same directory, with separate Dockerfiles: Dockerfile.cpu and Dockerfile.cuda. **

For more information about the source files, see RStudio self-build source files . 

2. Build the RStudio Server container image. To build the CPU-only variant: 

To build the CUDA-enabled variant: 

where: 

**<registry> **

Specifies the hostname of your container registry. 

**<namespace> **

Specifies the namespace or organization in your registry. **Both variants use source files from the same rstudio/rhel9-python-3.11/ directory. The CPU and CUDA variants use different Dockerfiles (Dockerfile.cpu and Dockerfile.cuda). The build context must be the repository root (.) because the Dockerfiles reference files from **multiple directories in the repository. 

NOTE 

The build might take 15-30 minutes because it downloads the RStudio Server RPM and installs multiple packages. 

3. Verify that the image built successfully: 

4. Push the built image to your container registry: 

5. Import the custom workbench image into OpenShift AI by creating an ImageStream in the **{dbd-config-default-namespace} namespace. **Create the following ImageStream resource: 

$ git clone --branch rhoai-2.25 --depth 1 https://github.com/red-hat-data-services/notebooks.git 

$ podman build -t <registry>/<namespace>/rstudio-server:latest \   -f rstudio/rhel9-python-3.11/Dockerfile.cpu . 

$ podman build -t <registry>/<namespace>/cuda-rstudio-server:latest \   -f rstudio/rhel9-python-3.11/Dockerfile.cuda . 

$ podman images | grep rstudio 

$ podman push <registry>/<namespace>/rstudio-server:latest 

Apply the ImageStream: 

Alternatively, you can import the custom workbench image by using the OpenShift AI dashboard. For more information, see Managing custom workbench images. 

Verification 

In the OpenShift AI dashboard, navigate to Projects → Workbenches → Create workbench. 

Confirm that RStudio Server (Custom) is displayed in the Notebook image → Image selection dropdown list. 

Create a workbench by using the custom RStudio image and verify that the RStudio IDE loads successfully. 

Additional resources 

RStudio self-build source files 

Alternative IDEs for R workflows 

Managing custom workbench images 

4.5. RSTUDIO SELF-BUILD SOURCE FILES 

**The self-build source files for RStudio Server workbench images are archived on the rhoai-2.25 branch of the red-hat-data-services/notebooks repository. Use this reference to understand the purpose of **each source file when building your own unsupported RStudio images. 

RStudio Server source files 

apiVersion: image.openshift.io/v1 kind: ImageStream metadata:   name: rstudio-rhel9-custom   namespace: redhat-ods-applications   labels:     opendatahub.io/notebook-image: "true"   annotations:     opendatahub.io/notebook-image-name: "RStudio Server (Custom)"     opendatahub.io/notebook-image-desc: "Self-built RStudio Server workbench image (unsupported)" spec:   lookupPolicy:     local: true   tags:     - name: latest       from:         kind: DockerImage         name: <registry>/<namespace>/rstudio-server:latest       importPolicy:         importMode: Legacy 

$ oc apply -f rstudio-imagestream.yaml 

**Both the CPU-only and CUDA-enabled variants use source files from the rstudio/rhel9-python-3.11/ directory in the repository. The CPU variant uses Dockerfile.cpu and the CUDA variant uses Dockerfile.cuda. **

File or directory Description 

**Dockerfile.cpu **Multi-stage Dockerfile that builds the CPU-only RStudio Server **image. Stage cpu-base installs base dependencies. Stage cpurstudio installs the RStudio Server RPM and configures the **web server proxy. 

**Dockerfile.cuda **Multi-stage Dockerfile that builds the CUDA-enabled RStudio Server image. Extends the CPU variant with NVIDIA CUDA Toolkit packages. 

**build-args/ directory **Build argument configuration files for each variant, such as **cpu.conf and cuda.conf. Each file defines the BASE_IMAGE and other build arguments. **

**kustomize/ directory **Kustomize manifests for deploying the image. These manifests are informational for the self-build scenario. 

**nginx/ directory **NGINX reverse proxy configuration files used to route traffic to the RStudio Server process. 

**httpd/ directory **Apache HTTP Server configuration files used for the web proxy. 

**run-rstudio.sh **Entrypoint script that starts the RStudio Server process and the web proxy. 

**rsession.conf **RStudio session configuration file that sets default R session parameters. 

**setup_rstudio.py **Python script for RStudio Server setup tasks. 

**rsession.sh **Shell script for R session management. 

**run-nginx.sh **Shell script for starting the NGINX proxy. 

**pyproject.toml **Python project configuration file. 

**pylock.toml **Lock file for Python dependencies. 

Build arguments 

The Dockerfile accepts the following build arguments: 

Argument Default Description 

**SECRET_DIR /opt/app-root/src/.sec **

Specifies the directory containing RHEL subscription credentials for accessing RHEL and Extra Packages for Enterprise Linux (EPEL) repositories during the build. 

Repository reference 

Repository 

red-hat-data-services/notebooks 

Branch 

**rhoai-2.25 **

Source path 

**rstudio/rhel9-python-3.11/ **The source path contains both the CPU and CUDA variants. 

Additional resources 

Build unsupported RStudio Server workbench images 