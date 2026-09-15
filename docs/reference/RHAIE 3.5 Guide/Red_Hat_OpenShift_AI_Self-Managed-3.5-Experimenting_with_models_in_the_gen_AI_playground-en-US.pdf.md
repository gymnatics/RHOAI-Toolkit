# Red_Hat_OpenShift_AI_Self-Managed-3.5-Experimenting_with_models_in_the_gen_AI_playground-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Experimenting with models in the gen AI playground

Experiment with models in the gen AI playground in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Experimenting with models in the gen AI playground

Experiment with models in the gen AI playground in Red Hat OpenShift AI Self-Managed

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

As a Red Hat OpenShift AI user, you can experiment with models in the gen AI playground in Red Hat OpenShift AI Self-Managed.

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

Table of Contents 

PREFACE 

CHAPTER 1. PLAYGROUND OVERVIEW 

CHAPTER 2 PLAYGROUND PREREQUISITES 2.1. CONFIGURING MODEL CONTEXT PROTOCOL (MCP) SERVERS 2.2. MODEL AND RUNTIME REQUIREMENTS FOR THE PLAYGROUND 

2.2.1. Additional resources 2.3. ABOUT THE AI ASSETS ENDPOINTS PAGE 

CHAPTER 3 CONFIGURE A PLAYGROUND FOR YOUR PROJECT 

CHAPTER 4 ENABLE CUSTOM ENDPOINTS FOR THE PLAYGROUND 

CHAPTER 5 CREATE AND USE CUSTOM ENDPOINTS IN THE PLAYGROUND 

CHAPTER 6 HOW MODEL EXPERIMENTATION ACCELERATES MODEL SELECTION 6.1. TEST MODEL RESPONSES 

CHAPTER 7 HOW MULTIMODAL INPUT EXTENDS MODEL EVALUATION 7.1. SEND AN IMAGE TO A VISION MODEL IN THE PLAYGROUND 7.2. ADD DOCUMENT CONTEXT TO A PLAYGROUND SESSION 7.3. UPLOAD AUDIO FOR TRANSCRIPTION IN THE PLAYGROUND 

CHAPTER 8 TEST YOUR MODEL WITH RETRIEVAL AUGMENTED GENERATION (RAG) 8.1. RAG SETTINGS 8.2. CHOOSING A KNOWLEDGE SOURCE FOR PLAYGROUND RAG 8.3. USE AN EXTERNAL VECTOR STORE FOR RAG IN THE PLAYGROUND 8.4. CONFIGURE EXTERNAL VECTOR STORES FOR THE PLAYGROUND 8.5. RESOURCES CREATED WHEN YOU CREATE A PLAYGROUND 8.6. CONFIGURE A CUSTOM POSTGRESQL INSTANCE FOR PLAYGROUND RAG 

CHAPTER 9 MODEL SAFETY EVALUATION IN THE PLAYGROUND 9.1. CONFIGURE GUARDRAILS IN THE PLAYGROUND 

CHAPTER 10 HOW TRACING WORKS IN THE PLAYGROUND 

CHAPTER 11 ANALYZE TRACES FOR PLAYGROUND RESPONSES 

CHAPTER 12. INLINE CHAT METRICS 

CHAPTER 13. REUSABLE SYSTEM INSTRUCTIONS 13.1. SAVE SYSTEM INSTRUCTIONS AS A REUSABLE PROMPT 13.2. REUSE A SAVED PROMPT IN A PLAYGROUND SESSION 

CHAPTER 14. TEST WITH MODEL CONTEXT PROTOCOL (MCP) SERVERS 

CHAPTER 15. SAVED AGENTS IN THE GEN AI PLAYGROUND 15.1. SAVE A PLAYGROUND AGENT 15.2. LOAD A SAVED AGENT INTO THE PLAYGROUND 15.3. MANAGE SAVED AGENTS IN THE GEN AI PLAYGROUND 

CHAPTER 16. EXPORT YOUR PLAYGROUND CONFIGURATION 

CHAPTER 17. UPDATE YOUR PLAYGROUND CONFIGURATION 

CHAPTER 18. DELETE A PLAYGROUND FROM YOUR PROJECT 

4 

5 

7 7 8 11 11 

13 

15 

17 

20 21 

23 24 25 26 

28 29 30 32 33 36 38 

40 41 

43 

44 

46 

47 47 49 

51 

52 52 53 54 

57 

59 

60 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 

CHAPTER 19. NEXT STEPS 

CHAPTER 20. TROUBLESHOOT PLAYGROUND ISSUES 

61 

62 

### PREFACE

Use the generative AI (gen AI) feature in OpenShift AI to evaluate, test, and interact with foundation and custom models in your project. You can test prompt engineering with Retrieval-Augmented Generation (RAG) and validate model behavior before using the model in an application. 

### CHAPTER 1. PLAYGROUND OVERVIEW

The generative AI (gen AI) playground is an interactive environment within the Red Hat OpenShift AI dashboard where you can prototype and evaluate foundation models, custom models, and Model Context Protocol (MCP) servers before you use them in an application. 

IMPORTANT 

Gen AI playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

You can test different configurations, including retrieval augmented generation (RAG), to determine the right assets for your use case. After you find an effective configuration, you can retrieve a Python template that serves as a starting point for building and iterating in a local development environment. 

The playground interface consists of a chat area and a Configure panel. The Configure panel is organized into tabs: 

Model: Select a model and adjust parameters such as temperature and streaming. Optionally, select a transcription model for audio upload. 

Prompt: Write, save, and load system instructions. 

Knowledge: Upload files for RAG or select an external vector store. 

MCP: Connect to Model Context Protocol servers and authorize access to their tools. 

Guardrails: If your cluster administrator has enabled guardrails, configure input and output guardrail settings. 

NOTE 

Chat history is not preserved if you refresh your browser or end your session. However, you can save your playground configuration, including model selection, inference parameters, prompt, knowledge sources, and MCP servers, as a named reusable agent. Prompts that you save through the Prompt tab are stored in MLflow and also persist across sessions. Saving playground agents is a Developer Preview feature. For more information, see Saved agents in the gen AI playground . 

The playground supports the following workflows: 

Chat with foundation models and custom-deployed models, including models from external endpoints. 

Test prompt engineering with RAG by uploading documents or selecting external vector stores as knowledge sources. 

Compare model responses side by side by opening multiple chat panes. 

Save and version system instructions as reusable prompts. 

Upload images to vision-enabled models, upload audio files for speech-to-text transcription, and attach documents for RAG context through the attach menu. For more information, see How multimodal input extends model evaluation . 

Authorize and interact with MCP servers and their tools. 

(Technology Preview) Enable distributed tracing to view inline performance metrics and inspect traces for each chat response. 

(Developer Preview) Save and load playground configurations as named reusable agents. 

View your playground configuration as Python code that you can copy for use in a local development environment. 

### CHAPTER 2. PLAYGROUND PREREQUISITES

Before you can configure and use the gen AI playground feature, you must meet prerequisites at both the cluster and user levels. 

Before a user can configure a playground instance, a cluster administrator must complete the following setup tasks: 

Ensure that OpenShift AI is installed on an OpenShift cluster running version 4.19 or later. 

**Set the value of the spec.dashboardConfig.genAiStudio dashboard configuration option to true. For more information, see Dashboard configuration options **. 

**If using OpenShift AI groups, add users to the rhods-users and rhods-admins OpenShift **group. 

Ensure that the OGX Operator is enabled on the OpenShift cluster by setting its **managementState field to Managed in the DataScienceCluster custom resource (CR) of the **OpenShift AI Operator. For more information, see Activating the OGX Operator. 

Configure the Model Context Protocol (MCP) servers to test models with external tools. For more information, see Configuring model context protocol servers . 

After the cluster administrator completes the setup, you must complete the following tasks before you can configure your playground instance: 

You are logged in to OpenShift AI. 

If you are using OpenShift AI groups, you are a member of the appropriate user or admin group. 

Create a project. The playground instance is tied to a project context. For more information, see Creating a project . 

Add a connection to your project. For more information about creating connections, see Adding a connection to your project. 

Deploy a model in your project and make it available as an AI asset endpoint. For more information, see Deploying models on the model serving platform . 

After you complete these tasks, the project is ready for you to configure your playground instance. 

2.1. CONFIGURING MODEL CONTEXT PROTOCOL (MCP) SERVERS 

A cluster administrator must configure and enable the Model Context Protocol (MCP) servers at the platform level before users can interact with external tools in the Generative AI Playground. This **configuration is done by creating a ConfigMap in the redhat-ods-applications namespace, which holds **the necessary information for each MCP server. 

Prerequisites 

You have cluster admin privileges for your OpenShift cluster. 

**You have installed the OpenShift CLI (oc) as described in the appropriate documentation for **your cluster: 

Installing the OpenShift CLI for OpenShift Container Platform 

Procedure 

**1. Create a file named gen-ai-aa-mcp-servers.yaml with the following YAML content. You can add multiple server entries under the data: field. **

kind: ConfigMap apiVersion: v1 metadata:   name: gen-ai-aa-mcp-servers   namespace: redhat-ods-applications data:   GitHub-MCP-Server: |     {       "url": "https://api.githubcopilot.com/mcp/x/repos/readonly",       "description": "The GitHub MCP server enables exploration and interaction with repositories, code, and developer resources on GitHub. It provides programmatic access to repositories, issues, pull requests, and related project data, allowing automation and integration within development workflows. With this service, developers can query repositories, discover project metadata, and streamline code-related tasks through MCP-compatible tools."     } 

IMPORTANT 

**The ConfigMap key (GitHub-MCP-Server) is case-sensitive and must be unique. **The content provided under this key must be valid JSON format. 

**2. Apply the ConfigMap to the cluster by running the following command: **

Verification 

**Confirm that the ConfigMap was successfully applied by running the following command: **

The output should contain the key name, confirming its successful creation: 

2.2. MODEL AND RUNTIME REQUIREMENTS FOR THE PLAYGROUND 

To successfully use the retrieval augmented generation (RAG) and Model Context Protocol (MCP) features in the playground, the model you deploy must meet specific requirements. Not all models offer the same capabilities. 

Consider the following factors when selecting a model for the playground: 

Tool calling capabilities 

oc apply -f gen-ai-aa-mcp-servers.yaml 

oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o yaml | grep GitHub-MCP-Server 

GitHub-MCP-Server: | 

The model must support tool calling to interact with the playground’s RAG and MCP features. You must check the model card (for example, on Hugging Face) to verify this capability. For more information, see Tool calling in the vLLM documentation. 

Context length 

Models with larger context windows are recommended for RAG applications. A larger context window allows the model to process more retrieved documents and maintain longer conversation histories. 

vLLM version and configuration 

Tool calling functionality depends heavily on the version of vLLM used in your model serving runtime. 

Version: Use the latest vLLM version included in Red Hat OpenShift AI for optimal compatibility. 

Runtime arguments: You must configure specific runtime arguments in the model serving runtime to enable tool calling. Common arguments include (not exhaustive): 

**--enable-auto-tool-choice **

**--tool-call-parser **

**--chat-template=/opt/app-root/template/<template_file>.jinja **

IMPORTANT 

If these requirements are not met, the model might fail to search documents or run tools without returning a clear error message. 

Tool calling functionality varies by model family, such as Llama, Mistral, Qwen and so on. For a complete list of supported models, compatible parsers, and template filenames, see Tool calling in the vLLM documentation. 

**When you specify a chat template, use the absolute path /opt/app-root/template/ to locate the standard Jinja template files provided in the Red Hat OpenShift AI image. For example, /opt/app-root/template/tool_chat_template_llama3.1_json.jinja. Do not use relative paths, such as examples/. Relative paths cause model deployment to fail. **

IMPORTANT 

Multimodal input support in the Gen AI Studio Playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

To use image upload in the playground, the model must support vision input. The playground identifies **vision-capable models through the opendatahub.io/model-capabilities annotation on the deployed **model resource. 

**The playground reads the opendatahub.io/model-capabilities annotation from the InferenceService or LLMInferenceService resource. The annotation value is a JSON array of capability strings. To enable image upload, include "vision" in the array: **

If the annotation is missing, the playground treats the model as text-only. No multimodal controls are **enabled. Models without the "vision" capability do not display image upload controls. The model catalog lists vision-capable models with the image-text-to-text task type, but the catalog task type does not automatically set the playground capability. You must set the opendatahub.io/model-capabilities **annotation separately on the deployed model resource. 

**When you create an external endpoint through the UI, you can add the Vision capability by using the **capability picker in the endpoint creation dialog. 

**The following table describes an example configuration for the Qwen/Qwen3-14B-AWQ model for use **in the playground. You can use this as a reference when configuring your own model runtime arguments. 

Table 2.1. Example configuration for Qwen/Qwen3-14B-AWQ 

Field Configuration Details 

Model Qwen/Qwen3-14B-AWQ 

vLLM Runtime vLLM NVIDIA GPU ServingRuntime for KServe 

Hardware Profile NVIDIA A10G (24GB VRAM) 

Custom Runtime Arguments **--dtype=auto --max-model-len=32768 --enable-auto-tool-choice --tool-call-parser=hermes --reasoning-parser=qwen3 --gpu-memory-utilization=0.90 **

The following table describes an example configuration for a vision-enabled model for use in the playground. 

Table 2.2. Example configuration for a vision-enabled model 

Field Configuration Details 

Model **A vision-enabled model with the "vision" capability in the opendatahub.io/model-capabilities annotation **

vLLM Runtime vLLM ServingRuntime for KServe 

Hardware Profile NVIDIA A10G (24GB VRAM) 

metadata:   annotations:     opendatahub.io/model-capabilities: '["vision"]' 

Custom Runtime Arguments **--dtype=auto **

**--max-model-len=8192 **

**--gpu-memory-utilization=0.90 **

Field Configuration Details 

The playground’s audio transcription feature requires a separate Automatic Speech Recognition (ASR) model. Audio files are transcribed by the ASR model first, and the resulting text is sent to the conversation model. 

**Deploy an ASR model, such as OpenAI Whisper, as an InferenceService and annotate it with the audiotranscription capability: **

where: 

**<asr_model_name> specifies the name of the deployed ASR model InferenceService. **

**<project_namespace> specifies the namespace where the ASR model is deployed. **

The ASR model is separate from the conversation model. Your workspace can have one conversation model for chat and one ASR model for transcription deployed at the same time. The ASR model must be registered as an AI asset endpoint to be visible in the playground. 

MaaS models are not supported as ASR endpoints. Only namespace-deployed or custom-endpoint ASR models can be used for audio transcription. 

2.2.1. Additional resources 

Tool calling in the vLLM documentation 

2.3. ABOUT THE AI ASSETS ENDPOINTS PAGE 

IMPORTANT 

This feature is currently available in Red Hat OpenShift AI 3.5 as a Technology Preview feature. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

$ oc annotate inferenceservice <asr_model_name> \   opendatahub.io/model-capabilities='["audio-transcription"]' \   -n <project_namespace> 

The AI asset endpoints page is a central dashboard for managing the generative AI assets available for you to use within your project. 

The page organizes assets into the following categories: 

Models: Lists generative AI models available in your project from the following sources: 

Models deployed in your project namespace that have been designated as available assets. For a model to be available, you must select the Add as AI asset endpoint check box when deploying it. For more information, see Deploying models on the model serving platform . 

Custom endpoints created from models in other namespaces on the same cluster or from external third-party providers. Custom endpoints are available when a platform engineer enables the feature. For more information, see Create and use custom endpoints in the playground. 

MaaS models provided through the Models as a Service platform. 

Model Context Protocol (MCP) Server: Lists all available MCP servers configured in the cluster in a config map. For more information, see Configuring Model Context Protocol servers. 

The primary purpose of this page is to provide a starting point for using these assets. From here, you can perform actions such as adding a model to a playground instance for testing. 

IMPORTANT 

The assets listed on the AI assets endpoints page are scoped to your currently selected project. You only see models and servers that are deployed and available within that specific project. 

### CHAPTER 3. CONFIGURE A PLAYGROUND FOR YOUR PROJECT

Configure a generative AI (gen AI) playground for your project so that you can interact with your deployed generative AI models and connect to backend servers such as Model Context Protocol (MCP) servers. 

Prerequisites 

You have created a project. 

**You have deployed a model in your project, the model is in a Running state, and you have **added your model as an AI asset endpoint. 

If your cluster administrator has configured Model Context Protocol (MCP) servers, they are accessible within your OpenShift environment. 

If you want to enable tracing for this playground session, your cluster administrator has enabled **the platform observability stack and the genAiTracing feature flag. **

Procedure 

1. Perform one of the following actions: 

a. From the OpenShift AI dashboard side navigation menu, click Gen AI studio → Playground. 

i. Select the project containing your model deployment from the Project drop-down list. 

ii. Click Create playground. The Configure playground dialog opens. 

b. From the OpenShift AI dashboard side navigation menu, click Gen AI studio → AI asset endpoints. 

i. Select the project containing your model deployment from the Project drop-down list. 

ii. Click the Models tab. 

iii. Locate the model that you want to create a playground for, and then click Add to playground. The Configure playground dialog opens. 

2. Select the models that you want to use in this playground instance. For each model, use the Type dropdown to select Inference or Embedding. 

3. Optional: To collect distributed traces for this session, toggle Enable tracing in the dialog footer. 

NOTE 

The Enable tracing toggle is visible only if your cluster administrator has **configured the platform observability stack and enabled the genAiTracing **feature flag. 

4. Click Create. 

Wait for the playground interface to finish loading. 

Verification 

The playground interface loads successfully with a chat area and a Configure panel on the left side. 

In the Configure panel, the Model tab displays the selected model. 

The Model list in the chatbot header bar shows the name of your selected model. 

If a cluster administrator has enabled guardrails, the Guardrails tab is visible in the Configure panel. 

If you enabled tracing, inline performance metrics appear beneath each assistant response after you send a chat message. 

### CHAPTER 4. ENABLE CUSTOM ENDPOINTS FOR THE PLAYGROUND

IMPORTANT 

Custom endpoints is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

As a platform engineer or cluster administrator, you can enable the custom endpoints feature to let users create endpoints from models that are not deployed in their project namespace. The following **dashboard configuration options in the OdhDashboardConfig custom resource control this feature: **

**aiAssetCustomEndpoints controls whether users can see and use the custom endpoints **feature. When enabled, users can create endpoints from models deployed in another namespace on the same cluster. 

**externalProviders controls whether users can also create endpoints for external third-party **providers such as OpenAI, Anthropic, or AWS. When enabled, data from the responses API can be sent outside the cluster. 

**clusterDomains specifies additional domains that are considered internal to the cluster. **

WARNING 

Enabling external providers allows users to send data from the responses API, including RAG context, MCP tool results, and user input, to endpoints outside the cluster. Evaluate your organization’s data security requirements before enabling this flag. 

Prerequisites 

You have cluster administrator privileges in OpenShift. 

**You have access to the OdhDashboardConfig custom resource. **

Procedure 

1. Log in to OpenShift as a cluster administrator. 

**2. Open the OdhDashboardConfig custom resource for editing. **For more information, see Editing the dashboard configuration . 

**3. In the spec section, set the following configuration options: **

- 

where: 

aiAssetCustomEndpoints 

**Specifies whether to show the custom endpoints feature. Set to true to allow users to create custom model endpoints. The default value is false. **

externalProviders 

**Specifies whether users can create external third-party provider endpoints. Set to true to enable external providers. The default value is false. Requires aiAssetCustomEndpoints to also be set to true. **

clusterDomains 

Specifies an array of domains that are considered internal to the cluster, in addition to **.svc.cluster.local, which is always treated as internal. **

1. Save the custom resource. 

Verification 

Users can see the Create endpoint option on the AI asset endpoints page. 

If you enabled external providers, users can create endpoints for external third-party providers. 

spec:   dashboardConfig:     aiAssetCustomEndpoints: true   genAiStudioConfig:     aiAssetCustomEndpoints:       externalProviders: true       clusterDomains: [] 

### CHAPTER 5. CREATE AND USE CUSTOM ENDPOINTS IN THE PLAYGROUND

IMPORTANT 

Custom endpoints is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

You can create custom endpoints to use models that are not deployed in your project namespace. With custom endpoints, you can access models deployed in another namespace on the same cluster, or models hosted by external third-party providers such as OpenAI, Anthropic, or AWS. 

After you create a custom endpoint, the model is displayed on the AI asset endpoints page and is available for selection in the playground. 

WARNING 

When you connect to an external third-party provider, data from the responses API, including RAG context, MCP tool results, and user input, is sent outside your cluster. Ensure that your organization’s security policies allow this before creating an external endpoint. 

Prerequisites 

You have configured a playground for your project. 

Your platform engineer has enabled the custom endpoints feature for your project. For more information, see Enable custom endpoints for the playground. 

You can create configmaps and secrets in your namespace. 

If you are connecting to a model in another namespace, you have the internal API endpoint URL and an authorized access token. 

If you are connecting to an external provider, you have the provider’s API endpoint URL and a valid API key. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → AI asset endpoints. 

2. Click Create endpoint. 

- 

3. In the form, enter the following details: 

Model type 

Specifies the type of model: 

Inferencing model: Generates text responses. Used in the playground as a conversation model. 

Embedding model: Converts text to vectors. Used in RAG pipelines. 

Transcription model: Converts audio to text. Used for audio upload in the playground. **When you select this type, the audio-transcription capability is automatically added. **This model must expose an OpenAI-compatible audio/transcriptions API. 

Model capabilities 

Tag this model with its capabilities so users can identify what it supports. When you select **the Transcription model type, the audio-transcription capability is automatically added. You **can also add "Vision" or custom capabilities manually. 

Model ID 

Specifies the exact model identifier from your provider. This must match the provider’s model ID exactly. 

Display name 

Specifies a user-friendly name for the model, shown in tables and selectors instead of the model ID. 

Embedding dimensions 

For embedding models only. Specifies the output vector size for the embedding model. 

Endpoint URL 

Specifies the API endpoint for the model service. For a model in another namespace, use the **internal cluster URL, for example https://<service_name>.<namespace>.svc.cluster.local. **For an external provider, use the provider’s API URL. 

API key or token 

Specifies the API key or access token required to authenticate with the endpoint. The credential is stored as a Kubernetes Secret and is shared at the project level. 

Verify model 

Optional. Click to test connectivity and API compatibility. For transcription models, the platform sends a small silent audio clip to the endpoint and checks for a valid response. 

Use case 

Optional. Specifies what the model is best suited for, to help other users in the project identify the model’s purpose. 

4. Click Create. The custom endpoint is displayed on the AI asset endpoints page. 

5. Click Add to Playground to make the model available in the playground. 

6. To use the model, click Try in Playground, or select the model from the models dropdown in the playground. 

Verification 

The custom endpoint is displayed on the AI asset endpoints page with the correct endpoint type. 

You can select the model in the playground and receive inference responses. 

### CHAPTER 6. HOW MODEL EXPERIMENTATION ACCELERATES MODEL SELECTION

The playground provides an interactive environment for evaluating how models respond to your prompts. You can test a single model’s baseline behavior or compare two models side-by-side to find the best fit for your use case. 

IMPORTANT 

Multi-model comparison is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

You can adjust the following parameters to see how they affect response quality, tone, and latency: 

Temperature 

Controls the randomness of the model’s output. Use values between 0 and 2. The temperature value directly influences creativity: 

Values near 0: Produce deterministic and factual responses, for objective or factual tasks. 

Values around 0.7: A common default for balanced output. 

Values near 1: Increase creativity and randomness, for generative or creative tasks. 

Values over 1: Typically produce incoherent output. 

Streaming 

Shows the model’s response as it is generated. This is helpful for testing model latency and seeing the model’s progress in real time. When streaming is off, the full response does not render until it is complete. 

System instructions 

Defines the context, persona, or instructions for the model. The playground provides a default prompt that you can review or edit. 

When comparing models, multi-model comparison helps you: 

Evaluate multiple models in a single session instead of configuring separate playground instances. 

Compare response quality, tone, accuracy, and latency across models with the same prompt. 

Assess trade-offs between open source and commercial models, or between different versions of the same model. 

Select the best model for a specific domain or use case. 

Evaluate how vision-enabled models interpret image input and how Automatic Speech Recognition (ASR) models transcribe audio as additional dimensions of model evaluation. For more information, see How multimodal input extends model evaluation . 

Additional resources 

Test model responses 

About the AI assets endpoints page 

6.1. TEST MODEL RESPONSES 

Use the playground to test and evaluate your model responses. You can test a single model or compare two models side-by-side. 

Prerequisites 

You have configured a playground for your project. 

At least two models are deployed and available as AI asset endpoints in your project if you want to compare models. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. From the Model list in the chat header bar, select the model that you want to test. 

3. Adjust model parameters such as temperature, streaming, and system instructions as needed. For more information about these parameters, see How model experimentation accelerates model selection. 

4. In the chat input field, enter a query. If your system instructions contain template variables, the playground substitutes the values you entered in the variable input panel before sending the prompt to the model. 

5. Click Send. The model response is displayed in the chat area. The response header shows the name of the model that generated the response. 

NOTE 

After you send a prompt, the Send button changes to a Stop button. Click it to interrupt the model response. 

6. Optional: To clear the chat history and start a new conversation, click New Chat. Your playground configuration settings are preserved. 

7. Optional: To compare two models side-by-side, click Compare in the playground configuration panel. The playground clears your current chat history and copies your configuration to both chat panels. This action cannot be undone. 

IMPORTANT 

Multi-model comparison is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

NOTE 

In compare mode, image upload requires all compared models to have the vision capability. If any model in the comparison lacks vision, image upload is disabled. Document upload is always available in compare mode. Audio upload uses the primary model’s ASR settings. 

a. In the Model list for each comparison panel, select a model. 

b. In the chat input field, enter a prompt to test across both models. 

c. Click Send. The playground displays responses from both models simultaneously in separate panels. 

d. Optional: To remove a model from the comparison, click the X in the upper-right corner of that model’s chat panel. 

### CHAPTER 7. HOW MULTIMODAL INPUT EXTENDS MODEL EVALUATION

You can send non-text inputs with text prompts to models that support them in the gen AI playground. You can upload images for vision inference, upload audio files for speech-to-text transcription, and attach documents for retrieval augmented generation (RAG) context. This multimodal input helps you evaluate model behavior across input types without writing API calls or using external tools. 

IMPORTANT 

Multimodal input support in the Gen AI Studio Playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

The playground supports the following input types as part of this Technology Preview: 

Image upload 

You can upload a JPG or PNG image for vision inference, up to 10 MB per file. The image is sent directly to the model as visual input for interpretation. One image per conversation is supported. To upload a different image, start a new conversation. 

Document upload 

You can upload PDF, CSV, or TXT files for RAG context, up to 10 MB per file and 10 files maximum. Documents are processed as knowledge sources through vector store embeddings. They are not sent to the model as visual input. 

Audio upload 

You can upload a WAV or MP3 audio file for speech-to-text transcription, up to 10 MB per file. The audio is transcribed by a dedicated Automatic Speech Recognition (ASR) model, such as Whisper, that you configure in the playground settings. The transcription text is automatically included in your message when you click Send. One audio file per message is supported. You can transcribe audio in multiple messages across the same conversation. **Audio transcription requires a namespace-deployed or custom-endpoint ASR model with the audiotranscription capability. MaaS models are not supported as ASR endpoints. **

**The playground reads the opendatahub.io/model-capabilities annotation from the deployed InferenceService or LLMInferenceService resource. The playground recognizes two capability values **for multimodal input: 

**vision **

Enables image upload controls in the playground. 

**audio-transcription **

Enables audio upload controls and makes the model available as a transcription model in playground settings. 

Models without the relevant capability do not display the corresponding upload controls. 

If the annotation is missing, multimodal upload controls are disabled. 

Models with vision or audio transcription capabilities display badge labels in the AI assets endpoints table and the playground model selector. 

After you send an image in a conversation, the Upload image menu item is disabled for the remainder of that conversation. To upload a different image, click New Chat to start a new conversation. 

In compare mode, image upload is available when all compared models have the vision capability. If any model lacks vision, image upload is disabled. Document upload is always available in compare mode. 

Image upload and document upload serve different purposes and use different processing paths: 

Image upload sends the image directly to the model for vision inference. The model interprets the visual content and generates a text response. 

Document upload processes the document through the RAG pipeline, creating embeddings in an inline vector store. The model uses the document content as retrieved context when generating responses. 

Additional resources 

Send an image to a vision model in the playground 

Upload audio for transcription in the playground 

Add document context to a playground session 

Model and runtime requirements for the playground 

7.1. SEND AN IMAGE TO A VISION MODEL IN THE PLAYGROUND 

You can upload an image with a text prompt to test how a vision-enabled model interprets visual input. The model generates a text response based on the image content and your prompt. 

IMPORTANT 

Multimodal input support in the Gen AI Studio Playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

You have configured a playground for your project. 

A vision-enabled model is deployed and available as an AI asset endpoint in your project. The **model’s InferenceService or LLMInferenceService resource must have the opendatahub.io/model-capabilities annotation set to include "vision". For more information, **see Model and runtime requirements for the playground . 

The vision-enabled model is selected in the playground Model dropdown. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. From the Model list, select a vision-enabled model. 

3. Click Attach in the message input area. 

4. From the attach menu, select Upload image. 

5. Select a JPG or PNG file up to 10 MB. 

6. Wait for the file to upload. 

7. Enter a text prompt in the message input field. If you do not enter text, the system uses the default prompt "Describe the image." 

8. Click Send. 

9. Review the inline image and the model response in the chat transcript. 

10. To upload a different image, click New Chat to start a new conversation. 

Verification 

The image is displayed inline in the chat transcript and the model returns a text response that references the image content. 

Additional resources 

How multimodal input extends model evaluation 

Model and runtime requirements for the playground 

7.2. ADD DOCUMENT CONTEXT TO A PLAYGROUND SESSION 

You can upload documents to provide retrieval augmented generation (RAG) context to the model during your playground session. Uploaded documents are processed through the RAG pipeline, which creates an inline vector store with embeddings derived from the file content. Unlike image upload, documents are not sent as visual input to the model. 

IMPORTANT 

Multimodal input support in the Gen AI Studio Playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

You have configured a playground for your project. 

A model is deployed and available as an AI asset endpoint in your project. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. From the Model list, select the model that you want to test. 

3. Click Attach in the message input area. 

4. From the attach menu, select Upload documents. 

5. Select one or more files. The supported file formats are PDF, CSV, and TXT. You can upload up to 10 files, with a maximum size of 10 MB per file. 

6. Enter a text prompt in the message input field. If you do not enter text, the system generates a default prompt. 

7. Click Send. 

Verification 

The model response references content from the uploaded documents, indicating that the RAG pipeline retrieved relevant context. 

Additional resources 

How multimodal input extends model evaluation 

Test your model with retrieval augmented generation 

7.3. UPLOAD AUDIO FOR TRANSCRIPTION IN THE PLAYGROUND 

You can upload an audio file in the playground to convert speech to text using an Automatic Speech Recognition (ASR) model. The transcribed text is automatically included in your message when you click Send. 

IMPORTANT 

Multimodal input support in the Gen AI Studio Playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

You have configured a playground for your project. 

A model is deployed and available as an AI asset endpoint in your project. 

**At least one model in your workspace has the audio-transcription capability. For more **information, see Model and runtime requirements for the playground . 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. In the settings panel, click the Model tab. 

3. Click Add audio transcription model. 

**4. From the dropdown, select a transcription model. Models with the audio-transcription **capability are listed. 

5. In the message bar, click Attach. 

6. From the attach menu, click Upload audio. 

7. Select a WAV or MP3 audio file. The maximum file size is 10 MB. 

8. Wait for the transcription to complete. The transcribed text is included automatically when you send the message. 

9. Optional: Type additional text in the message input alongside the transcription. 

10. Click Send. 

11. To discard the transcription without sending, remove the audio file before sending. 

Verification 

After sending, the model responds to the transcribed content in the chat transcript. 

One audio file per message is supported. To transcribe another audio file, send the current message first or discard the current transcription. You can transcribe audio in multiple messages across the same conversation, and audio and images can coexist in the same conversation across different messages. 

Audio transcription requires a namespace-deployed or custom-endpoint ASR model. MaaS models are not supported as ASR endpoints. 

Additional resources 

How multimodal input extends model evaluation 

Model and runtime requirements for the playground 

### CHAPTER 8. TEST YOUR MODEL WITH RETRIEVAL AUGMENTED GENERATION (RAG)

You can enhance your model responses by providing contextual information from your own documents using retrieval augmented generation (RAG). When you create a playground, OpenShift AI automatically provisions a pgvector-enabled PostgreSQL instance to store document embeddings for RAG. No database setup is required, and your embeddings persist across pod restarts on a persistent volume. 

IMPORTANT 

The default auto-provisioned pgvector vector store for Gen AI Studio playground RAG is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

NOTE 

If you upgraded from a previous version of OpenShift AI, playgrounds that used the inline Milvus vector store enter a failed state after the upgrade. Delete the failed playground and create a new one by clicking Gen AI studio → Playground, then re-upload your documents. Vectors stored in inline Milvus are not migrated to the pgvector backend. 

Prerequisites 

You have configured a playground for your project. 

You have the document files ready to upload. The supported file formats are PDF, DOC, or CSV. You can upload up to 10 files, with a maximum size of 10MB per file. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. In the settings panel, click the Knowledge tab. 

3. Click Upload files. 

4. Click Upload. The Upload files dialog opens. 

5. Drag and drop your file or click to browse and select a file from your local system. 

6. Optional: Adjust the Maximum chunk length and Chunk overlap and Delimiter values as needed for your document type. For more information about these settings, see Understanding RAG settings. 

7. Click Upload. Wait for the file to finish processing. A Source uploaded notification appears, and the file is listed under Uploaded files. 

8. Repeat these steps to upload additional files if needed. 

9. Optional: In the Prompt tab, review or edit the system instructions. The playground provides a default prompt. 

10. In the chat input field, ask a question related to your documents that the model would not know otherwise. 

11. Observe the model response. 

TIP 

If the model does not use its knowledge search tool, you can modify the system instructions in the Prompt tab to change this behavior. 

To ensure that the model actively utilizes the available RAG documents rather than relying solely on its pre-trained data, refine the system prompt by including directives as shown in the following examples: 

**To force use: "You MUST use the knowledge_search tool to obtain updated information." **

To specify context: "Always search the knowledge base before answering questions about company policies, recent events, or specific documentation." 

NOTE 

After you send a prompt, the Send button changes to a Stop button. Click it to interrupt the model response. 

12. Optional: To clear the chat history and start a new conversation, click New Chat. Your playground configuration settings are preserved. 

Verification 

The model retrieves information from the uploaded documents to answer the questions. 

Additional resources 

Choosing a knowledge source for playground RAG 

Use an external vector store for RAG in the playground 

8.1. RAG SETTINGS 

When you upload a document for retrieval augmented generation (RAG), you can configure the following settings to optimize how the text is processed. 

Maximum chunk length 

The maximum word count for each text section ("chunk") created from your uploaded files. 

Smaller chunks are recommended for precise data retrieval. 

Larger chunks are recommended for tasks requiring broader context, such as summarization. 

Chunk overlap 

The number of words from the end of one text section (chunk) that are repeated at the start of the next one. This overlap helps maintain continuous context across chunks, improving model responses. 

For example, the following sentence is chunked differently depending on the chunk overlap: "Chunk overlap can improve the quality of model responses." 

Maximum chunk length = 4, Chunk overlap = 1 

Chunk overlap can improve improve the quality of of model responses. 

Maximum chunk length = 4, Chunk overlap = 0 

Chunk overlap can improve the quality of model responses. 

Delimiter A character or string that specifies where a text chunk should end. This helps define text boundaries alongside maximum chunk length and overlap, ensuring sentences or paragraphs remain intact. 

Examples of delimiters: 

**. (period): splits at sentence boundaries **

**\n (newline): splits at paragraph boundaries **

**; (semicolon): splits at clause boundaries **For example, the following sentence is split as follows depending on the delimiter: "This is the first sentence. This is the second sentence." 

Maximum chunk length = 4 , Chunk overlap = 0 

This is the first sentence. This is the second sentence. 

Maximum chunk length = 4 , Chunk overlap = 0, Delimiter = 0 

This is the first sentence. This is the second sentence. 

8.2. CHOOSING A KNOWLEDGE SOURCE FOR PLAYGROUND RAG 

You can provide knowledge sources to the Gen AI Studio playground to enhance model responses with information from your own documents and data. OpenShift AI supports two approaches for supplying knowledge to RAG workflows in the playground: uploading files directly and selecting an adminconfigured external vector store. 

IMPORTANT 

Knowledge sources for RAG in the Gen AI Studio playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

By default, you upload documents directly through the Knowledge tab. OpenShift AI automatically provisions a pgvector-enabled PostgreSQL instance when you create the playground. No database setup is required. For the upload procedure, see Test your model with retrieval augmented generation (RAG). 

For production workloads, shared access across teams, or integration with existing database infrastructure, an administrator can configure external vector stores that appear in the playground Knowledge tab. 

External vector stores offer the following advantages over the auto-provisioned default: 

Persistent storage managed by your organization’s database infrastructure 

Shared access to the same vector data across multiple users and applications 

Scale beyond the 5 GiB limit of the auto-provisioned PVC 

Integration with existing backup, replication, and high-availability configurations 

When an administrator configures external vector stores, you can select them from the Knowledge tab instead of uploading files. 

The following external vector store databases are supported: 

PostgreSQL with pgvector 

Qdrant 

Milvus 

Consult your administrator for the specific database versions and connectivity requirements that are validated for your OpenShift AI environment. 

To use external vector stores, an administrator configures them in your project namespace. For the admin procedure, see Configure external vector stores for the playground . For the user procedure, see Use an external vector store for RAG in the playground . 

The following table summarizes when to use each approach: 

Table 8.1. Knowledge source comparison 

Consideration File upload (default) External vector store 

Setup required None Administrator creates ConfigMap and Secrets 

Intended use Development and experimentation 

Production, shared workloads, advanced deployments 

Storage scope Per-playground, 5 GiB PVC Managed by your database infrastructure 

Data sharing Single playground Multiple users and applications 

Consideration File upload (default) External vector store 

IMPORTANT 

The auto-provisioned pgvector instance is intended for development and experimentation only. For production workloads, provide your own PostgreSQL instance or use an administrator-configured external vector store. 

Additional resources 

Test your model with retrieval augmented generation (RAG) 

Use an external vector store for RAG in the playground 

8.3. USE AN EXTERNAL VECTOR STORE FOR RAG IN THE PLAYGROUND 

If your administrator has configured external vector stores for your project, you can select one in the Gen AI Studio playground to use as a knowledge source for RAG. This approach is for users who need persistent, shared, or production-grade vector storage instead of the auto-provisioned default. If you do not need an external vector store, you can upload files directly through the Knowledge tab instead. For more information, see Test your model with retrieval augmented generation (RAG) . 

IMPORTANT 

External vector stores for RAG in the Gen AI Studio playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

You have configured a playground for your project. 

An administrator has configured external vector stores for the playground. For more information, see Configure external vector stores for the playground . 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. In the settings panel, click the Knowledge tab. 

NOTE 

The tab is labeled Knowledge when external vector store support is enabled. If you see a tab labeled RAG instead, external vector stores are not enabled for your environment. 

3. At the top of the Knowledge tab, enable the RAG toggle. 

4. Select Use an existing vector store. A list of available external vector stores appears. 

5. Select the vector store that you want to use. 

6. In the chat input field, ask a question about specific content stored in the selected vector store. 

Verification 

The model response includes information from the external vector store that is not part of the model’s general training data. If the response contains details specific to your stored documents, the vector store connection is working correctly. 

Additional resources 

Choosing a knowledge source for playground RAG 

Test your model with retrieval augmented generation (RAG) 

8.4. CONFIGURE EXTERNAL VECTOR STORES FOR THE PLAYGROUND 

As an administrator, you can make external vector stores available to users in the Gen AI Studio playground. Users can then select these vector stores as knowledge sources for RAG instead of uploading files. 

IMPORTANT 

External vector stores for RAG in the Gen AI Studio playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

You have installed and enabled the OGX Operator in OpenShift AI. 

You have one or more deployed vector databases with data already ingested. Supported databases are PostgreSQL with pgvector, Qdrant, and Milvus. 

You have the connection details for each vector database, including the hostname, port, and credentials. 

You know the embedding model and embedding dimension used to create the vector data in each store. 

You have permissions to create ConfigMaps and Secrets in the target project namespace. 

Procedure 

1. In the OpenShift web console, switch to the Administrator perspective and select the project namespace where the playground is configured. 

2. Create a Secret for each vector database that requires authentication. 

a. Click Workloads → Secrets. 

b. Click Create → From YAML. 

c. Paste the following YAML, update the placeholder values, and then click Create. 

Example Secret for a pgvector-enabled PostgreSQL database 

**<my_vector_store_credentials> specifies a name for the Secret. Use this name in the ConfigMap secretRefs field. **

**<my_database_password> specifies the password for the vector database. **Repeat this step for each vector database that requires credentials. 

**3. Create the gen-ai-aa-vector-stores ConfigMap. **

a. Click Workloads → ConfigMaps. 

b. Click Create ConfigMap. 

c. Paste the following YAML, update the placeholder values, and then click Create. 

Example ConfigMap for external vector stores 

apiVersion: v1 kind: Secret metadata:   name: <my_vector_store_credentials> type: Opaque stringData:   password: <my_database_password> 

apiVersion: v1 kind: ConfigMap 

**<my_provider_id> specifies a unique identifier for this vector database provider, such as pgvector-prod or qdrant-docs. **

**<my_provider_type> specifies the provider type. Supported values are remote::pgvector, remote::qdrant, and remote::milvus. **

**<my_database_host> specifies the hostname or service name of the vector database. **

**<my_database_port> specifies the port number for the vector database. **

**<my_database_name> specifies the database name. Applicable to remote::pgvector **providers. 

**<my_database_user> specifies the database user. Applicable to remote::pgvector **providers. 

**<my_vector_store_credentials> specifies the name of the Secret that contains the **database credentials. Must match the Secret you created in the previous step. 

**<my_vector_store_id> specifies a unique identifier for the vector store collection, such as vs_product-embeddings. **

**<my_embedding_model> specifies the embedding model used to create the vector data, such as ibm-granite/granite-embedding-125m-english. **

**<my_embedding_dimension> specifies the dimension of the embedding vectors, such as 768. This value must match the dimension used when the data was ingested. **

metadata:   name: gen-ai-aa-vector-stores data:   config.yaml: |     providers:       vector_io:         - provider_id: <my_provider_id>           provider_type: <my_provider_type>           config:             host: <my_database_host>             port: <my_database_port>             db: <my_database_name>             user: <my_database_user>             custom_gen_ai:               credentials:                 secretRefs:                   - name: <my_vector_store_credentials>                     key: password 

    registered_resources:       vector_stores:         - provider_id: <my_provider_id>           vector_store_id: <my_vector_store_id>           embedding_model: <my_embedding_model>           embedding_dimension: <my_embedding_dimension>           vector_store_name: "<my_display_name>"           metadata:             description: "<my_vector_store_description>" 

**<my_display_name> specifies the vector store name that users will see in Gen AI **Studio. For example, in AI Asset Endpoints, playground. 

**<my_vector_store_description> specifies an optional description of the vector store. To add multiple vector stores, add entries to both the providers.vector_io list and the registered_resources.vector_stores list. **

4. Enable the external vector stores feature in the OpenShift AI dashboard configuration. **Run the following command to set the externalVectorStores feature flag to true in the OdhDashboardConfig custom resource: **

Verification 

In the OpenShift AI dashboard, click Gen AI studio → Playground. 

In the settings panel, click the Knowledge tab. 

Enable the RAG toggle. 

Select Use an existing vector store. The vector stores you configured appear in the list. 

Additional resources 

Choosing a knowledge source for playground RAG 

Use an external vector store for RAG in the playground 

8.5. RESOURCES CREATED WHEN YOU CREATE A PLAYGROUND 

When you create a Gen AI Studio playground, OpenShift AI creates a set of Kubernetes resources to run the pgvector-enabled PostgreSQL instance for RAG. You can use the resource names and labels described here for troubleshooting or capacity planning. 

IMPORTANT 

The default auto-provisioned pgvector vector store for Gen AI Studio playground RAG is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

IMPORTANT 

The auto-provisioned pgvector instance is intended for development and experimentation only. For production workloads, provide your own PostgreSQL instance. For more information, see Configure a custom PostgreSQL instance for playground RAG. 

$ oc patch OdhDashboardConfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '{"spec":{"dashboardConfig":{"externalVectorStores":true}}}' 

OpenShift AI manages the lifecycle of the following resources. All auto-provisioned resources use the **naming prefix genai-pgvector- and carry the managed label gen-ai.opendatahub.io/pgvector. These **resources are managed directly by the Gen AI Studio service, not by a Kubernetes operator. If a resource is manually deleted or modified, you must delete and recreate the playground to restore it. 

NOTE 

Confirm the exact resource names with your environment before scripting against them. 

Table 8.2. Auto-provisioned pgvector resources 

Resource type Name Description 

Secret **genai-pgvector-credentials **

Stores the auto-generated PostgreSQL connection credentials, including the database name, user, password, and host. No user input is required. 

ConfigMap **genai-pgvector-init **Contains initialization scripts for the PostgreSQL instance, such as enabling the pgvector extension. 

PersistentVolumeClaim **genai-pgvector-storage **

Provides 5 GiB of persistent storage for vector data. Document embeddings survive pod restarts. 

Deployment **genai-pgvector **Runs the PostgreSQL 16 pod with the pgvector extension using the **registry.redhat.io/rhel9/postgresql-16 **container image. 

Service **genai-pgvector **Exposes the PostgreSQL pod on port 5432 within the namespace. 

NetworkPolicy **genai-pgvector **Restricts network access to the PostgreSQL pod to traffic originating within the same namespace. 

The auto-provisioned pgvector resources follow this lifecycle: 

Creation 

OpenShift AI creates all resources when you create a playground. Credential values are autogenerated. 

Preservation on model change 

When you reconfigure a playground and change the model, the pgvector instance and all uploaded document embeddings are preserved. You do not need to re-upload documents after changing models. 

Deletion on playground delete 

When you delete a playground, all auto-provisioned pgvector resources are removed, including the Deployment, PVC, Service, NetworkPolicy, ConfigMap, and credentials Secret. Externally configured PostgreSQL instances that you provided are not affected. 

Additional resources 

Choosing a knowledge source for playground RAG 

Configure a custom PostgreSQL instance for playground RAG 

8.6. CONFIGURE A CUSTOM POSTGRESQL INSTANCE FOR PLAYGROUND RAG 

You can configure the connection between the Open Gen AI Experience Toolkit (OGX) server and a pgvector-enabled PostgreSQL instance by using environment variables. For custom PostgreSQL deployments, you create a Kubernetes Secret containing the connection credentials and reference it from the OGX server configuration. 

**The following table describes the environment variables that configure the remote::pgvector vector_io **provider. 

Table 8.3. pgvector connection environment variables 

Environment variable 

Default value Required Description 

**PGVECTOR_HO ST **

None Yes Specifies the hostname or service name of the pgvector-enabled PostgreSQL instance. When this variable is set, OpenShift AI configures **remote::pgvector as the default vector_io provider. **

**PGVECTOR_PO RT **

**5432 **No Specifies the PostgreSQL port number. 

**PGVECTOR_DB vectordb **No Specifies the name of the PostgreSQL database for vector storage. 

**PGVECTOR_US ER **

**vectoruser **No Specifies the PostgreSQL user for vector storage connections. 

**PGVECTOR_PA SSWORD_SECR ET_NAME **

None Conditional Specifies the name of the Kubernetes Secret that contains the pgvector password. Required for PostgreSQL instances that use password authentication. OpenShift AI injects the password from this Secret into the OGX pod environment as **PGVECTOR_PASSWORD at runtime. **

**PGVECTOR_PA SSWORD_SECR ET_KEY **

**password **No Specifies the key within the password Secret that contains the password value. 

NOTE 

**The PGVECTOR_PASSWORD variable is not set directly. OpenShift AI reads PGVECTOR_PASSWORD_SECRET_NAME and PGVECTOR_PASSWORD_SECRET_KEY to locate a Kubernetes Secret, then injects the password value into the OGX pod environment as PGVECTOR_PASSWORD. The OGX server resolves PGVECTOR_PASSWORD at runtime. For custom deployments, create the Secret and set PGVECTOR_PASSWORD_SECRET_NAME to reference it. **

For playground RAG, OpenShift AI automatically generates the pgvector connection credentials and **stores them in the genai-pgvector-credentials Secret. You do not need to set these environment **variables manually. 

For custom PostgreSQL deployments, you create a Secret with the required connection credentials and **configure the environment variables to reference it. You must set PGVECTOR_HOST at a minimum to enable the remote::pgvector provider. For PostgreSQL instances that require password authentication, you must also set PGVECTOR_PASSWORD_SECRET_NAME. **

The following example shows a Secret for a custom PostgreSQL deployment: 

where: 

**<your_postgresql_password> **

Specifies the password for the PostgreSQL user account that the OGX server uses to connect to your pgvector-enabled database. 

**After creating the Secret, you must also set at least PGVECTOR_HOST so that OpenShift AI can locate **your PostgreSQL instance. For PostgreSQL instances that require password authentication, also set **PGVECTOR_PASSWORD_SECRET_NAME so that OpenShift AI can inject the credentials into the ***OGX pod. For the complete procedure, see Deploy a PostgreSQL instance with pgvector * in the *Configuring the Open Gen AI Experience Toolkit * guide. // TODO: Convert to xref when the target module is available. 

For information about the auto-provisioned resources and their naming conventions, see Resources created when you create a playground. 

Additional resources 

Choosing a knowledge source for playground RAG 

apiVersion: v1 kind: Secret metadata:   name: my-pgvector-credentials type: Opaque stringData:   password: <your_postgresql_password> 

### CHAPTER 9. MODEL SAFETY EVALUATION IN THE PLAYGROUND

IMPORTANT 

Model safety evaluation in the playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

The playground integrates with NeMo Guardrails to give you real-time safety validation alongside model evaluation. Instead of deploying and testing guardrails separately, you can enable guardrails directly in the playground to validate that safety controls work before you build your application. 

Guardrails use a guardrail model to evaluate the safety of content. This model is distinct from the chat model that generates responses, but is selected from the same models available in your playground configuration. When you enable guardrails, the guardrail model analyzes prompts and responses for harmful content, prompt injection attempts, and sensitive data. 

The playground supports two types of guardrails that you can enable independently: 

Input guardrails 

Evaluate user prompts before they reach the chat model. If the guardrail model flags a prompt as harmful, the playground blocks the request and displays a safety message. You must start a new chat to continue after an input violation. 

Output guardrails 

Evaluate model responses after the chat model generates them. If the guardrail model flags a response as harmful, the playground suppresses the response and displays a safety message instead. For streaming responses, output guardrails evaluate content in chunks as the chat model generates it. 

You can enable input guardrails, output guardrails, or both at the same time. Input and output guardrails operate independently. 

You select the guardrail model from the models available in your playground configuration. The guardrail model can be any running model in your playground; it does not need to be the same model that you use for chat. 

When you use multi-model comparison, you can configure guardrails independently for each chat panel. You can compare how the same guardrail configuration behaves across different models, or test different guardrail settings side-by-side. 

Additional resources 

Configure guardrails in the playground 

Enabling AI safety with NeMo Guardrails 

9.1. CONFIGURE GUARDRAILS IN THE PLAYGROUND 

IMPORTANT 

Guardrails in the playground is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

You can enable NeMo Guardrails in the playground to validate that safety controls filter harmful content from prompts and model responses. 

Prerequisites 

**A cluster administrator has set guardrails to true in the OdhDashboardConfig custom **resource to enable the guardrails feature. 

You have configured a playground for your project. When guardrails are enabled at the cluster **level, the NemoGuardrails custom resource is created automatically as part of the playground **configuration. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. In the playground settings panel, click the Guardrails tab. 

3. From the Guardrail model list, select the model that you want to use for content evaluation. 

4. Turn on Input guardrails to enable pre-request content filtering. 

5. Turn on Output guardrails to enable post-response content filtering. 

6. In the chat input field, enter a prompt and click Send. The enabled guardrails evaluate your prompt, the model’s response, or both, for safety. 

NOTE 

If an input guardrail blocks your prompt, click New Chat to start a new conversation before sending another message. 

Verification 

Send a prompt that has safe content and confirm that the chat model returns a response without interference. 

Send a prompt that has harmful content, such as a prompt injection attempt, and confirm that the playground displays a guardrail violation message. 

If you enabled output guardrails, confirm that the playground suppresses harmful model responses and displays a safety message instead. 

### CHAPTER 10. HOW TRACING WORKS IN THE PLAYGROUND

You can enable distributed tracing in the Gen AI Studio playground to observe how each chat message flows through the inference pipeline. Tracing helps you diagnose slow responses, identify guardrail blocks, and understand the processing path of your model interactions without leaving the playground. 

IMPORTANT 

Playground tracing is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Playground tracing uses OpenTelemetry instrumentation to capture traces for each chat request. When tracing is enabled, the dashboard server and the inference server each produce spans that record timing, inputs, and outputs for their part of the request. These spans are routed through an OpenTelemetry Collector and stored in MLflow for visualization. 

The Configure playground dialog displays an Enable tracing toggle when your cluster administrator has **configured the platform observability stack and enabled the genAiTracing feature flag. Tracing is opt-**in and scoped to the current playground session. If you do not enable tracing, no trace data is collected and the playground behaves as it does without tracing configured. 

After you enable tracing and send a chat message, each assistant response displays inline performance metrics in a collapsible section. These metrics include response latency, total tokens, and time to first token for streaming responses. 

Each traced response also includes a View trace button. Click this button to open the trace in MLflow in a new browser tab, where you can inspect the full call tree, view span inputs and outputs, and analyze the timeline for latency diagnosis. 

A new tracing session is initialized when you refresh your browser or start a new session. Traces from the earlier session are not correlated with new traces, but remain accessible in MLflow. 

Additional resources 

Analyze traces for playground responses 

Inline chat metrics 

### CHAPTER 11. ANALYZE TRACES FOR PLAYGROUND RESPONSES

You can view the distributed trace for any chat response in the Gen AI Studio playground. Each trace shows the full call tree of the inference request, including timing data for each span, so that you can diagnose slow responses, inspect guardrail decisions, and understand the flow of your request through the inference pipeline. 

IMPORTANT 

Playground tracing is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Prerequisites 

**Your cluster administrator has enabled the platform observability stack and the genAiTracing **feature flag. For more information, see Enabling the observability stack. 

Your cluster administrator has enabled the MLflow Operator component. For more information, see Enable the MLflow Operator component . 

You have configured a playground for your project with tracing enabled. For more information, see Configure a playground for your project . 

Procedure 

1. Send a chat message in the playground. Inline performance metrics appear beneath the response in a collapsible section, showing values such as response latency, token count, and time to first token. 

2. Locate the View trace button on the assistant response. 

3. Click View trace. The trace opens in MLflow in a new browser tab, showing the trace for that chat message. 

4. In the MLflow trace viewer, navigate the span tree to inspect the parent-child relationships between spans. A typical trace includes the following span types: 

A root span representing the overall chat request. 

If guardrails are enabled, child spans for guardrail moderation checks. 

Child spans from the OGX inference server for model inference operations. 

5. Click a span in the tree to view its inputs and outputs. Span attributes include the messages sent to the model, the model response content, and the **span type, such as CHAIN for the root request or GUARDRAIL for moderation checks. **

6. Review the timeline view to analyze latency across the request lifecycle. The timeline shows the duration of each span relative to the total request time, helping you identify which component contributes most to the overall response latency. 

Verification 

The MLflow trace viewer displays a complete span tree with timing data for the selected chat response. 

**The root span shows the service name gen-ai-bff for the dashboard server. **

**Span attributes include mlflow.spanInputs and mlflow.spanOutputs. **

**If guardrails were enabled, the span tree includes GUARDRAIL child spans for moderation **checks. 

Troubleshooting 

If the View trace button does not appear on a response: 

**Verify that the platform observability stack is running. The data-science-collector-collector pod must be running in the {monitoring-default-namespace} namespace. **

Verify that the MLflow Operator component is enabled and an MLflow instance is running in the project namespace. 

If the trace link opens but MLflow displays an error, verify that the trace data has been fully collected and stored. 

### CHAPTER 12. INLINE CHAT METRICS

When tracing is enabled in the Gen AI Studio playground, each assistant response displays inline performance metrics. You can use these metrics to compare latency and throughput across models and to identify performance changes when you adjust playground settings. 

IMPORTANT 

Playground tracing is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

Metrics appear beneath each response in a collapsible section after the response is complete. Click Show metrics to expand the section and view the metric values for the completed response. 

The following table describes the metrics that appear beneath each assistant response when tracing is enabled. 

Table 12.1. Inline chat metrics 

Metric Label Description 

Response latency Duration in milliseconds or seconds 

The total time from when the chat request is sent to when the complete response is received. Values under 1 second are displayed in milliseconds. Values of 1 second or more are displayed in seconds with two decimal places. 

Total tokens *Tokens: n *The combined count of input tokens and output tokens for the response. This metric is displayed only when the inference server returns token usage data. If the model or serving runtime does not report token counts, this metric is not displayed. Token cost estimation is not available. Inline metrics display token counts but do not provide cost calculations. 

Time to first token (TTFT) 

TTFT: duration The time from when the dashboard server sends the inference request to the inference server to when it receives the first token of the response. This metric is displayed only for streaming responses. TTFT is measured server-side. The value includes model processing time and server-to-inference-server network latency, but does not include browser-to-server network latency. 

### CHAPTER 13. REUSABLE SYSTEM INSTRUCTIONS

IMPORTANT 

Prompt management is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

When you find system instructions that produce effective results in the playground, you can save them as a named prompt so that you and your team can reuse them across sessions. Saving a refined prompt creates a new version automatically, so you can track changes and return to earlier versions. 

Saved prompts are stored in MLflow and scoped to your project by default. Any project member can browse and load prompts that others have saved, making it easier to standardize on instructions that work well for your use case. 

If an administrator has configured a global prompt registry namespace, you can also browse and load prompts that your organization has curated. When you modify a global prompt, you can save a copy to your project namespace by using Save As. 

**Prompts can also contain template variables, written as {{variable}} placeholders, that are filled with **specific values at runtime. You can use template variables in both loaded prompts and manually authored system instructions. When you or a team member loads a prompt that contains template variables, the playground displays an input panel where you enter values for each variable before running inference. 

You can work with saved prompts from two locations: 

Prompt tab in the playground 

While testing a model, use the Prompt tab in the chatbot settings panel to save your current instructions, load prompts that you or your team have saved, or continue refining a prompt across sessions. The interface tracks your edits and shows an Unsaved indicator when your instructions differ from the last saved version. 

Prompts page 

To review and manage saved prompts outside of a playground session, use the Prompts page under Gen AI studio. This page provides a standalone view of all saved prompts in your project, and any prompts from the configured global namespace, through the MLflow prompt registry. 

13.1. SAVE SYSTEM INSTRUCTIONS AS A REUSABLE PROMPT 

IMPORTANT 

Prompt management is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

After you write system instructions that produce effective results, you can save them as a named prompt so that you and your team can reuse them. If you later refine the instructions, saving again creates a new version automatically, so you can track your changes over time. 

Prerequisites 

You have configured a playground for your project. For more information, see Configure a playground for your project. 

The MLflow service is available in your project. For more information, see Working with MLflow. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. In the chatbot settings panel, click the Prompt tab. 

3. Write or edit the system instructions in the Instructions field. 

4. Click Save. The Save prompt dialog opens. 

5. In the Name field, enter a name for the prompt. 

6. Optional: In the Commit message field, describe your changes. 

7. Click Create. The prompt is saved to your project. 

8. To update a saved prompt and create a new version, click Edit and update the system instructions. 

9. Click Save. The New prompt version dialog opens with the version number auto-incremented. 

10. Optional: In the Commit message field, describe what changed in this version. 

11. Click Save. 

12. If you loaded a prompt from a global registry namespace, the Save button is not available. Click Save As to save a copy to your project namespace. In the dialog, enter a name for the local copy and click Create. 

**If your system instructions contain template variables written as {{variable}} placeholders, the variables **are preserved when you save the prompt. Team members who load the saved prompt can enter their own values for each variable at runtime. 

Verification 

The prompt name and version number are displayed in the Prompt tab. 

If you used Save As for a global prompt, the copy is displayed in your project namespace. 

13.2. REUSE A SAVED PROMPT IN A PLAYGROUND SESSION 

IMPORTANT 

Prompt management is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

If you or a team member have saved system instructions as a prompt, you can load them into a new playground session to continue where you left off or to start from instructions that are known to work well. You can load prompts from your project or from a global registry namespace. 

Prerequisites 

You have configured a playground for your project. For more information, see Configure a playground for your project. 

The MLflow service is available in your project. For more information, see Working with MLflow. 

One or more prompts have been saved in the project or in a global registry namespace. 

Optional: An administrator has configured a global prompt registry namespace. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. In the chatbot settings panel, click the Prompt tab. 

3. Click Load Prompt. The Load prompt dialog opens. 

4. Select the Project prompts or Global prompts tab. 

5. Optional: Use the search field to filter prompts by name prefix. 

6. Click a prompt in the table to view its versions in the side panel. 

7. Optional: From the Version dropdown, select a specific version. 

8. Click Load in Playground. The selected prompt version is loaded as the system instructions for the current chatbot configuration. 

9. Optional: If the loaded prompt contains template variables, enter a value for each variable in the input panel under the Instructions field. 

Verification 

The prompt name and version number are displayed in the Prompt tab. 

The Instructions field contains the text from the loaded prompt version. 

### CHAPTER 14. TEST WITH MODEL CONTEXT PROTOCOL (MCP) SERVERS

Authorize and interact with connected MCP servers to use their integrated tools directly from the playground chat. 

Prerequisites 

You have deployed a model with tool-calling capabilities enabled in your project. 

You have configured a playground instance for your project. 

A cluster administrator has configured an MCP server, and the server is listed and available in the MCP tab of the settings panel. 

Procedure 

1. In the settings panel, click the MCP tab. 

2. Select the checkbox for the server that you want to use. 

3. Click the Auth icon next to the server name. The Authorize MCP server dialog opens. 

4. If the server requires a token, enter the token in the Access token field and click Authorize. A Connection successful message appears. 

NOTE 

Authorization tokens for MCP servers are stored only for the current browser session. If you close your browser, you must re-authorize the server. 

5. Click Close. 

6. Click the View tools (wrench) icon for the same MCP server. A modal appears, listing all available tools for that server. You can copy a tool name to use in the chat. 

7. In the chat input field, type a query that uses one of the available tools. 

8. Click the Send button or press Enter. 

NOTE 

After you send a prompt, the Send button changes to a Stop button. Click it to interrupt the model response. 

Verification 

The AI bot responds, indicating it is using the tool. 

The bot provides the output from the tool. 

### CHAPTER 15. SAVED AGENTS IN THE GEN AI PLAYGROUND

IMPORTANT 

Saved agents is a Developer Preview feature only. Developer Preview features are not supported by Red Hat in any way and are not functionally complete or production-ready. Do not use Developer Preview features for production or business-critical workloads. Developer Preview features provide early access to upcoming product features in advance of their possible inclusion in a Red Hat product offering, enabling customers to test functionality and provide feedback during the development process. These features might not have any documentation, are subject to change or removal at any time, and testing is limited. Red Hat might provide ways to submit feedback on Developer Preview features without an associated SLA. 

When you are iterating on model configurations, tuning parameters, or comparing RAG strategies, rebuilding a complex playground setup from scratch is time-consuming. You can save a working playground configuration as a named agent so that you and your team can reload it later, use it as a baseline for variant experiments, or share it across the project. 

A saved agent captures your model selection, inference parameters, MLflow prompt reference, retrieval augmented generation (RAG) knowledge sources, and Model Context Protocol (MCP) server connections as a single object scoped to your project namespace. Chat history, playground guardrail settings, and credential values are not included. 

Saved agents are stored as Kubernetes resources in the project namespace, so all project members can view and load agents for that namespace. You can browse saved agents from the Agents tab on the AI asset endpoints page, or load one directly into the playground. 

When you load a saved agent, the system validates that all referenced resources are still available. If any resource has been deleted or become unavailable, the playground displays a warning that identifies each missing resource and links to the relevant settings tab. 

15.1. SAVE A PLAYGROUND AGENT 

IMPORTANT 

Saved agents is a Developer Preview feature only. Developer Preview features are not supported by Red Hat in any way and are not functionally complete or production-ready. Do not use Developer Preview features for production or business-critical workloads. Developer Preview features provide early access to upcoming product features in advance of their possible inclusion in a Red Hat product offering, enabling customers to test functionality and provide feedback during the development process. These features might not have any documentation, are subject to change or removal at any time, and testing is limited. Red Hat might provide ways to submit feedback on Developer Preview features without an associated SLA. 

You can save your playground configuration as a named agent to preserve it across sessions, share it with team members, or use it as a starting point for variant experiments. 

Prerequisites 

You have configured a playground for your project. 

At least one model is selected in the playground. 

**The agentConfigManagement Developer Preview feature flag is enabled. For more **information, see Dashboard configuration options . 

Procedure 

1. To save a new agent: 

a. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

b. Configure the playground with the model, inference parameters, prompt, knowledge sources, and MCP servers that you want to capture. 

c. In the playground header, click the menu and select Save agent. The Save agent dialog opens and displays a summary of the configuration that will be saved, including the selected model, prompt, knowledge sources, and MCP servers. 

NOTE 

Playground guardrail settings are not included in a saved agent. 

d. In the Agent name field, enter a descriptive name for the agent. 

e. Optional: In the Description field, describe the use case for this agent. 

f. Click Save. The agent is created and the agent name is displayed in the playground header. 

2. To save updates to a loaded agent: 

a. Make changes to the playground configuration while an agent is loaded. An unsaved-changes indicator is displayed in the playground header. 

b. In the playground header, click the menu and select Save agent. The Save agent dialog opens with the existing agent name and description pre-filled. 

c. Click Save to overwrite the existing agent with your changes. The unsaved-changes indicator disappears from the playground header, confirming the save was successful. 

NOTE 

If another user has modified the agent since you loaded it, a conflict warning is displayed. In this case, use Save as new agent to create a new agent with your changes. 

Verification 

The agent name is displayed in the playground header. 

The agent is displayed in the Agents tab on the AI asset endpoints page under Gen AI studio. 

15.2. LOAD A SAVED AGENT INTO THE PLAYGROUND 

IMPORTANT 

Saved agents is a Developer Preview feature only. Developer Preview features are not supported by Red Hat in any way and are not functionally complete or production-ready. Do not use Developer Preview features for production or business-critical workloads. Developer Preview features provide early access to upcoming product features in advance of their possible inclusion in a Red Hat product offering, enabling customers to test functionality and provide feedback during the development process. These features might not have any documentation, are subject to change or removal at any time, and testing is limited. Red Hat might provide ways to submit feedback on Developer Preview features without an associated SLA. 

You can load a saved agent into the playground to resume work or to start from a saved configuration. Loading an agent restores all captured settings, including the model, inference parameters, prompt, knowledge sources, and Model Context Protocol (MCP) servers. 

Prerequisites 

You have configured a playground for your project. 

One or more agents have been saved in the project. 

**The agentConfigManagement Developer Preview feature flag is enabled. For more **information, see Dashboard configuration options . 

Procedure 

1. To load an agent from the playground: 

a. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

b. In the playground header, click the menu and select Load agent. The Load agent dialog opens and displays a table of saved agents in the current project. 

c. Locate the agent that you want to load and click Load agent. All captured settings are restored in the playground. The agent name is displayed in the playground header. 

2. To load an agent from the AI asset endpoints page: 

a. From the OpenShift AI dashboard, click Gen AI studio → AI asset endpoints. 

b. Click the Agents tab. 

c. Locate the agent that you want to load and click Try in Playground. The playground opens with the agent loaded. 

Verification 

The agent name is displayed in the playground header. 

The model, inference parameters, prompt, knowledge source, and MCP server settings match the saved agent. 

15.3. MANAGE SAVED AGENTS IN THE GEN AI PLAYGROUND 

IMPORTANT 

Saved agents is a Developer Preview feature only. Developer Preview features are not supported by Red Hat in any way and are not functionally complete or production-ready. Do not use Developer Preview features for production or business-critical workloads. Developer Preview features provide early access to upcoming product features in advance of their possible inclusion in a Red Hat product offering, enabling customers to test functionality and provide feedback during the development process. These features might not have any documentation, are subject to change or removal at any time, and testing is limited. Red Hat might provide ways to submit feedback on Developer Preview features without an associated SLA. 

You can browse, create variant copies of, rename, and delete saved agents from the Agents tab on the AI asset endpoints page or from the playground header menu. These operations help you organize experiments and keep saved agents up to date. 

Prerequisites 

One or more agents have been saved in the project. 

**The agentConfigManagement Developer Preview feature flag is enabled. For more **information, see Dashboard configuration options . 

Procedure 

1. To create a variant copy of an agent: 

a. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

b. Load an existing agent into the playground. 

c. Adjust the configuration as needed for your variant experiment. 

d. In the playground header, click the menu and select Save as new agent. The Save as new agent dialog opens. 

e. In the Agent name field, enter a name for the new variant. 

f. Optional: In the Description field, describe how this variant differs from the original. 

g. Click Save as. A new agent is created with the modified configuration. The original agent remains unchanged. 

2. To rename an agent or update its description: 

a. From the OpenShift AI dashboard, click Gen AI studio → AI asset endpoints. 

b. Click the Agents tab. 

c. Locate the agent that you want to rename. 

**d. Click the action menu (⋮) for the agent and select Edit. **The Edit agent dialog opens. 

e. Update the Name or Description fields as needed. 

f. Click Save. 

3. To delete an agent: 

a. From the OpenShift AI dashboard, click Gen AI studio → AI asset endpoints. 

b. Click the Agents tab. 

c. Locate the agent that you want to delete. 

**d. Click the action menu (⋮) for the agent and select Delete. **

e. In the confirmation dialog, click Delete. The agent is permanently removed from the project namespace. 

4. To clear the loaded agent from the playground: 

a. In the playground header, click the menu and select Clear agent. The playground returns to its default state with no agent loaded. 

Verification 

The updated agent list on the Agents tab reflects your changes. 

### CHAPTER 16. EXPORT YOUR PLAYGROUND CONFIGURATION

Export your gen AI playground configuration as a Python code template so that you can use it in your local development environment, such as a notebook or IDE. 

IMPORTANT 

This code is a template and is not a runnable script. It provides a starting point that shows your configuration, including the model, MCP tools, and RAG files used. 

Prerequisites 

You have configured your playground instance with the settings that you want to capture in your code template. This includes: 

Selecting a model. 

Setting model parameters, such as model temperature, to your required values. 

Optional: Uploading files or selecting a vector store in the Knowledge tab. 

Optional: Authorizing and enabling servers in the MCP tab. 

Optional: Uploading an image in the chat to include vision code in the template. 

Optional: Selecting an ASR model in the Model tab to include audio transcription code in the template. 

Procedure 

1. In the playground, configure your required settings. 

2. Click the View code button. A dialog opens, displaying a Python code template. 

3. Click Copy code. 

4. Paste the code into your local development environment. 

Verification 

Review the pasted code in your local environment. 

Confirm that the template includes the correct model, MCP tools, and RAG files from your playground configuration. If you uploaded an image, confirm the template includes vision image upload code. If you selected an ASR model, confirm the template includes audio transcription code. 

NOTE 

When vision or audio transcription features are configured in your playground session, the exported Python template includes additional code sections: 

If an image has been uploaded, the template includes code to upload the image and pass it as visual input to the model. 

If an ASR model is selected, the template includes code to transcribe an audio file by using the ASR model’s endpoint and feed the transcription into the conversation. 

### CHAPTER 17. UPDATE YOUR PLAYGROUND CONFIGURATION

You can update the configuration of your playground instance to add new models, re-register models that were stopped, or change the existing configuration. 

NOTE 

Updating the playground configuration preserves the vector store and any previously uploaded document embeddings. 

Prerequisites 

You have configured a playground for your project. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. Select the project containing your model deployment from the Project dropdown list. 

3. In the upper-right corner of your playground, click the action menu (⋮) and select Update configuration. 

4. On the configuration screen, select or clear the checkboxes for the models you want to make available. 

5. Click Update. 

Verification 

The playground configuration is updated with a new selection of models. 

### CHAPTER 18. DELETE A PLAYGROUND FROM YOUR PROJECT

You can delete a playground instance from a project. This removes instance for all users who have access to that project. 

Prerequisites 

You have configured a playground for your project. 

Procedure 

1. From the OpenShift AI dashboard, click Gen AI studio → Playground. 

2. Select the project containing your model deployment from the Project drop-down list. 

3. In the upper-right corner of your playground, click the action menu (⋮) and select Delete playground. 

NOTE 

This action deletes the playground for every user in the project. Deleting a playground also removes all auto-provisioned pgvector resources, including the persistent volume containing your document embeddings. This data cannot be recovered. 

4. Confirm the deletion. 

Verification 

Confirm that the playground is deleted from the project. 

In the Gen AI studio → AI asset endpoints page, models no longer show the Try in playground button and instead show the Add to playground button. 

### CHAPTER 19. NEXT STEPS

You have successfully deployed and tested a model using the playground with RAG and MCP tools. For more information on the next steps, see the following resources: 

Developing in an IDE 

Working in your data science IDE Learn how to access your workbench IDE (JupyterLab, code-server, or RStudio Server) to develop models. 

### CHAPTER 20. TROUBLESHOOT PLAYGROUND ISSUES

If you encounter issues while using the playground, see the following scenarios and solutions: 

The model thinks indefinitely 

Problem After sending a query, the model shows a thinking indicator but never returns a response. 

Cause This issue often occurs when the query or the accumulated context exceeds the maximum context length configured for the model. 

Solution 

1. In the OpenShift AI dashboard, click the Applications menu and select OpenShift Console. 

2. Go to your project namespace. 

3. Check the logs for the following pods: 

**The playground pod: lsd-genai-playground-<pod_id> **

**The model serving pod: <model_name>-predictor-<pod_id> **

4. Look for errors related to context length limits or memory (OOM) constraints. 

The model does not use retrieval augmented generation data 

Problem The model answers questions by using its training data instead of searching the uploaded RAG documents. 

Solution 

In the Prompt tab of the settings panel, update the system instructions to explicitly force the use of the search tool. 

**Example: "You MUST use the file_search tool to obtain updated information." **

Example: "Always search the knowledge base before answering questions about company policies." 

MCP servers are missing from the UI 

Problem The MCP tab is empty or not visible in the settings panel. 

Cause MCP servers must be configured at the cluster level by an administrator. 

Solution 

Contact your OpenShift AI administrator to configure the required MCP servers. Administrators can find a list of available servers in the Red Hat OpenShift AI documentation. 

The model fails to call MCP tools 

**Problem The model attempts to use a tool but fails, or outputs raw XML tags such as <tool_call>. **

Cause 

The model does not support tool calling. 

The vLLM runtime arguments are missing or incorrect. 

Some models might output raw tags if the correct reasoning parser is not available in the current vLLM version. 

Solution 

1. Verify the model supports tool calling on its Hugging Face model card. 

2. In the model’s deployment settings, ensure the following Custom Runtime Arguments are present: 

**--enable-auto-tool-choice **

**--tool-call-parser **

**--chat-template **

3. The playground automatically separates reasoning content from response content for models **that produce <think> tags. If the model continues to display reasoning output, you can add /no_think to your prompt as a vLLM model-level directive to suppress reasoning tags at the **inference server level. 

Image upload succeeds but model returns an error 

Problem An image uploads successfully but the model fails to analyze it or returns an empty response. 

Solution 

1. Verify the model supports vision input by checking its model card. 

**2. Check the model’s runtime arguments. Vision models typically require --trust-remote-code and --limit-mm-per-prompt. **

3. Check the model serving pod logs for errors. 

Audio transcription fails or returns empty 

Problem Audio upload completes but transcription fails. An error alert is displayed instead of the "Transcription complete" toast. 

Solution 

Check the error message: 

"No speech detected": The audio file contains silence. Try a different recording. 

"Transcription timed out": Try a shorter audio file or check the ASR model pod health. 

"Audio transcription failed": Check model status, authentication, and network connectivity. 

Global prompts do not appear after configuration 

Problem After an administrator configures the global prompt registry namespace, no global prompts appear in the prompt browser. 

Cause The dashboard polls the configuration every 30 seconds. Changes can take up to 60 seconds to propagate. 

Solution 

1. Wait up to 60 seconds for the changes to take effect. 

**2. Verify that the mlflow-view RoleBinding exists in the target namespace: **

If the RoleBinding does not exist, verify that an MLflow server instance is running in the target namespace. The MLflow Operator creates RBAC bindings only when an active MLflow server is present. 

Save fails with permission denied 

Problem Clicking Save on a modified prompt fails with a "Permission denied" error. 

Cause Your write access to the prompt’s namespace was revoked after you loaded the prompt. 

Solution 

Click Save As to save a copy of the prompt to your project namespace. 

*$ oc get rolebindings -n <namespace> | grep mlflow-view *