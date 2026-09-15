# Red_Hat_OpenShift_AI_Self-Managed-3.5-Working_with_AutoRAG-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Working with AutoRAG

Use AutoRAG in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Working with AutoRAG

Use AutoRAG in Red Hat OpenShift AI Self-Managed

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

Use AutoRAG in Red Hat OpenShift AI Self-Managed to automatically optimize and evaluate retrieval-augmented generation (RAG) configurations for your documents and use case.

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

CHAPTER 1. AUTORAG OVERVIEW 1.1. AUTORAG WORKFLOW 1.2. AUTORAG TERMINOLOGY 1.3. MULTILINGUAL SUPPORT 1.4. CPU-ONLY INFRASTRUCTURE 1.5. TECHNOLOGY PREVIEW LIMITATIONS 1.6. VIEWING EXTERNALLY CREATED RUNS 

CHAPTER 2 PREPARE TEST DATA FOR AUTORAG 

CHAPTER 3 CREATE AN AUTORAG OPTIMIZATION RUN 

CHAPTER 4 EVALUATE AUTORAG RESULTS 

CHAPTER 5 RUN THE RAG PATTERN 

CHAPTER 6 AUTORAG EVALUATION METRICS 6.1. METRIC COMBINATIONS 

CHAPTER 7 AUTORAG CONFIGURATION PARAMETERS 7.1. USER-CONFIGURABLE PARAMETERS 7.2. RUN PRESETS 7.3. SEARCH SPACE DEFAULTS 7.4. RECOMMENDED EMBEDDING MODELS 7.5. RECOMMENDED FOUNDATION MODELS 7.6. CPU-ONLY DEPLOYMENTS 

3 

4 4 4 4 4 4 5 

6 

8 

11 

13 

14 14 

15 15 16 16 17 17 17 

### PREFACE

You can use AutoRAG in OpenShift AI to optimize and evaluate retrieval-augmented generation (RAG) configurations for your documents and use cases. 

### CHAPTER 1. AUTORAG OVERVIEW

AutoRAG is an automated optimization system in Red Hat OpenShift AI that finds the best retrievalaugmented generation (RAG) configuration for your documents and use case. You provide documents and test data. AutoRAG tests different RAG configurations, ranks results by evaluation metrics, and generates notebooks to run RAG patterns. 

1.1. AUTORAG WORKFLOW 

When you create an AutoRAG optimization run, AutoRAG tests combinations of chunking, embedding, retrieval, and generation settings against your test data. Each combination produces a RAG pattern with evaluation scores. AutoRAG ranks patterns on a leaderboard and generates Jupyter notebooks that you can use to run the best pattern. 

AutoRAG automatically samples up to 1 GiB of relevant documents based on your test data, so you do not need to filter your document set in advance. Documents referenced in your test data are prioritized during sampling. 

1.2. AUTORAG TERMINOLOGY 

RAG pattern 

An optimized RAG configuration that includes performance metrics, a leaderboard position, indexing and inference notebooks, and a Responses API template for programmatic integration. 

Search space 

The set of parameter combinations that AutoRAG tests during optimization. The search space includes chunking, embedding, retrieval, and generation settings. 

1.3. MULTILINGUAL SUPPORT 

AutoRAG supports documents and test data in multiple languages. When you run an optimization experiment, AutoRAG automatically detects the dominant language of your evaluation questions and configures the optimization pipeline accordingly. No additional configuration is required for language detection. 

If your documents are in a language other than English, ensure that the models you select support your target language. 

1.4. CPU-ONLY INFRASTRUCTURE 

AutoRAG supports CPU-only deployments using lightweight foundation and embedding models optimized for CPU inference. For validated model recommendations and expected latency, see the CPU-only deployments section of the AutoRAG configuration parameters. 

1.5. TECHNOLOGY PREVIEW LIMITATIONS 

IMPORTANT 

AutoRAG is a Technology Preview feature. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope on the Red Hat Customer Portal. 

The following limitations apply during Technology Preview: 

Remote vector databases only: Milvus and pgvector (PostgreSQL) are supported. Inline vector databases are not supported. 

A maximum of three foundation models and two embedding models per optimization run. Specifying more models can cause the run to fail. 

Images embedded in documents are not processed. 

Optical character recognition (OCR) is not available for PDF documents. 

Table structure detection for PDF documents is available only with the Better quality run preset. 

1.6. VIEWING EXTERNALLY CREATED RUNS 

The AutoRAG pipeline is automatically registered with your pipeline server when your pipeline server starts. If you create runs from the pipeline outside of the AutoRAG interface, the runs appear on the AutoRAG page in the dashboard. 

Additional resources 

Prepare test data for AutoRAG 

Create an AutoRAG optimization run 

AutoRAG evaluation metrics 

AutoRAG configuration parameters 

Technology Preview Features Support Scope 

AutoRAG tutorial 

To find the best RAG configuration for your documents, prepare test data, create an AutoRAG optimization run, evaluate the results, and run the best-performing pattern. 

### CHAPTER 2. PREPARE TEST DATA FOR AUTORAG

Create a test data file that AutoRAG uses to evaluate RAG configurations against ground-truth answers. The test data contains questions, expected answers, and the document IDs where those answers can be found. 

Your test data file must be a JSON array with the following structure: 

The test data file uses the following fields: 

**question **

The question that AutoRAG submits to each RAG configuration during evaluation. 

**correct_answers **

One or more expected answers. Multiple phrasings help AutoRAG evaluate answer correctness more accurately. 

**correct_answer_document_ids **

The file names of documents that contain the answer. AutoRAG uses these IDs to prioritize documents during sampling and to evaluate context correctness. 

Prerequisites 

You have access to the documents that you plan to use with AutoRAG. 

You have a text editor or scripting environment for creating JSON files. 

Procedure 

1. Identify questions that represent your target use case. Select questions that cover the range of topics in your document set. Include both simple factual questions and questions that require synthesizing information from multiple sections. 

2. For each question, write one or more correct answers. Use the exact phrasing from your source documents where possible. Include alternative phrasings to improve evaluation accuracy. 

3. For each question, identify the source documents that contain the answer. **Use the base file name without any folder path. For example, use policies.pdf, not documents/policies.pdf. **

[   {     "question": "What is the return policy?",     "correct_answers": ["Items can be returned within 30 days", "The return window is 30 days from purchase"],     "correct_answer_document_ids": ["policies.pdf", "faq.md"]   },   {     "question": "How do I reset my password?",     "correct_answers": ["Navigate to Settings and select Reset Password"],     "correct_answer_document_ids": ["user-guide.pdf"]   } ] 

4. Save your test data as a JSON file. **Ensure the file uses the .json extension and follows the JSON format shown earlier in this **procedure. 

5. Make the test data file available for your optimization run: 

Upload the file to an S3-compatible storage bucket. 

Keep the file on your local system to upload when you create the optimization run. 

Verification 

Open the JSON file in a text editor and verify that it is valid JSON. 

**Verify that each entry contains the question and correct_answers fields. **

**Verify that the document IDs in correct_answer_document_ids match the file names in your **document set. 

Additional resources 

Create an AutoRAG optimization run 

AutoRAG evaluation metrics 

### CHAPTER 3. CREATE AN AUTORAG OPTIMIZATION RUN

Create an AutoRAG optimization run to find the best RAG configuration for your documents and use case. You configure the optimization run in a two-step wizard that collects connection details and optimization settings. 

Prerequisites 

You have editor access to a project in OpenShift AI. 

**A cluster administrator has set the values of the spec.dashboardConfig.genAiStudio and spec.dashboardConfig.autorag dashboard configuration options to true. For more **information, see Dashboard configuration options . 

You have a pipeline server configured in your project. When configuring the pipeline server, select the Enable AutoML and AutoRAG pipelines checkbox in Advanced settings. If you **create the DataSciencePipelinesApplication instance with YAML, set spec.apiServer.managedPipelines: {}. For more information, see Configuring a pipeline **server. 

An OGX instance is available and configured with foundation and embedding models. For more information, see Working with OGX. 

**Foundation models deployed with vLLM are configured with tool calling enabled, including the --enable-auto-tool-choice and --tool-call-parser model server arguments. The --tool-call-parser value depends on the model family: for example, mistral for Mistral models. For more **information, see Tool calling in the vLLM documentation. 

A remote vector database is registered as a vector I/O provider with your OGX instance. Supported vector databases are Milvus and pgvector (PostgreSQL). Inline vector databases are not supported. For information about configuring pgvector, see Using PostgreSQL in OGX . 

An OGX connection is configured in your project. The connection must include the OGX base URL and API key. 

Your documents are available in an S3-compatible storage bucket or locally for upload. 

If you store multiple documents in S3, they are in a single folder in the bucket. 

Documents are in one of the following formats: PDF, DOCX, PPTX, Markdown, HTML, or TXT. 

You have prepared a test data file in JSON format. For more information, see Prepare test data for AutoRAG. 

Procedure 

1. In the OpenShift AI dashboard, click Gen AI studio > AutoRAG. 

2. Select your project, and then click Create AutoRAG optimization run. 

3. Enter a name and optionally a description for the optimization run, select an OGX connection, and click Next. 

4. Configure the optimization settings as follows: 

a. In the Knowledge setup section, select an S3 connection for your documents and select the files to use. You can browse your S3 bucket or upload files directly. Uploaded files can be up to 32 MiB. 

b. Select your vector database from the Vector I/O provider list. 

c. Add an evaluation data set by browsing your S3 bucket for a JSON file or by uploading one directly. You can download a template from the evaluation dataset template link on the configuration page. 

d. Select an optimization metric from the Optimization metric list: 

Answer faithfulness: Optimizes for answers grounded in retrieved context. 

Answer correctness: Optimizes for answers that match your test data. 

Context correctness: Optimizes for retrieval of relevant documents. 

e. In the Maximum RAG patterns field, enter a value between 4 and 20. The default is 8. 

f. Select a Run preset to control the search space and resource allocation. For more information about preset options, see Run presets. 

g. Optional: Click Edit on the model configuration card to exclude models. By default, all foundation and embedding models available from your OGX instance are selected. Select no more than 3 foundation models and 2 embedding models to avoid run failures. 

TIP 

**For embedding models, BAAI/bge-m3 is recommended. For more information, see **AutoRAG configuration parameters. 

If your documents are in a language other than English, ensure that the models you select support your target language. AutoRAG detects the language of your evaluation questions automatically. To verify model language support, view the model details in the Model catalog. 

NOTE 

Optimization runs cannot be edited after creation. To stop, archive, or delete the underlying pipeline run, see Managing pipeline runs. 

5. Click Create run. AutoRAG begins testing RAG configurations. You can monitor the optimization run status on the AutoRAG page. 

Verification 

On the AutoRAG page, the new optimization run is listed with a status of Running or Pending. 

The run progresses to Complete when AutoRAG finishes testing all RAG configurations. 

Additional resources 

Evaluate AutoRAG results 

AutoRAG configuration parameters 

AutoRAG evaluation metrics 

### CHAPTER 4. EVALUATE AUTORAG RESULTS

After an AutoRAG optimization run completes, review the leaderboard and pattern details to select the best RAG configuration for your use case. 

Prerequisites 

You have created an AutoRAG optimization run and it has completed successfully. 

Procedure 

1. In the OpenShift AI dashboard, click Gen AI studio > AutoRAG. 

2. Select a project from the project list. 

3. Click the name of the completed optimization run. 

4. Review the leaderboard, which ranks RAG patterns by your selected optimization metric. Compare scores across all metric columns to evaluate each pattern holistically. The score columns show mean values for each metric, and an indicator marks the optimization metric. For information about how each metric is calculated, see AutoRAG evaluation metrics. 

5. To view detailed information about a pattern, click the pattern name or select View details from the actions menu. The pattern details view shows: 

Scores for each metric with mean, confidence interval high, and confidence interval low values 

Configuration settings organized by category: chunking, embedding, retrieval, and generation 

Sample Q&A results with per-question scores, your expected answers, and the pattern’s generated answers 

6. Compare patterns by examining Sample Q&A responses across different patterns. Review answers in the Sample Q&A tab to verify that patterns produce accurate, well-grounded responses. 

7. Optional: To test a pattern interactively, select Try this pattern from the actions menu. A chat panel opens where you can ask questions about your documents and review the pattern’s responses. Use the pattern selector to switch between patterns and compare responses. To get code snippets for integrating the pattern into your application by using the Responses API, click View code. You can also select View code directly from the actions menu on the leaderboard without opening the chat panel. Code snippets are available in curl, Node.js, Go, and Python. By default, snippets fetch OGX credentials from the Kubernetes secret at runtime. Enable Inject credentials to embed your OGX hostname and API key directly in the snippet. Treat injected snippets as secrets. The chat panel is for testing purposes only. Your chat history is lost if you switch patterns or close the panel. 

8. After you choose a pattern, integrate it by using one of the following methods: 

To call the pattern from an application or service, use the Responses API code snippets from View code. 

To explore the pattern interactively in a workbench, save the notebooks by selecting Save as indexing notebook and Save as inference notebook from the actions menu. 

Verification 

You have selected a RAG pattern based on its leaderboard scores and Sample Q&A results. 

You have copied a Responses API code snippet or downloaded the indexing and inference notebooks for the selected pattern. 

Additional resources 

Run the RAG pattern 

AutoRAG evaluation metrics 

### CHAPTER 5. RUN THE RAG PATTERN

After you select a RAG pattern from the AutoRAG leaderboard, run the notebooks in an OpenShift AI workbench to use the pattern with your documents. 

Prerequisites 

You have selected a RAG pattern from a completed AutoRAG optimization run. For more information, see Evaluate AutoRAG results . 

You have downloaded the indexing and inference notebooks from the AutoRAG leaderboard or pattern details view. 

You have a running workbench in your OpenShift AI project. 

You have the connection details for your S3-compatible object storage and your OGX instance. 

The models used in your selected RAG pattern are available on your OGX instance. 

Procedure 

1. In the OpenShift AI dashboard, open your workbench. 

2. Attach the following data connections to the workbench. Use the same S3 bucket and OGX instance that you used for the optimization run. 

An S3-compatible object storage connection for your documents 

A connection for your OGX instance that includes the API key and base URL 

3. Optional: To index additional documents, upload and run the indexing notebook. The vector database is already populated from the optimization run. 

4. Upload the inference notebook to the workbench. 

5. Open the inference notebook and run each cell. The notebook prompts you to enter a question. Enter a question to verify that the RAG system returns relevant answers from your documents. 

Verification 

If you ran the indexing notebook, verify that all cells completed without errors. 

The inference notebook returns answers grounded in your documents. 

If the notebook displays an error, check your connection details. 

Additional resources 

Evaluate AutoRAG results 

### CHAPTER 6. AUTORAG EVALUATION METRICS

Each AutoRAG optimization run produces scores for three evaluation metrics. All metrics are scored from 0 to 1, with higher scores indicating better performance. Each score includes a mean value, a high confidence interval (CI high), and a low confidence interval (CI low). 

Answer faithfulness 

Measures whether the generated answer uses information from the retrieved context rather than hallucinated content. A high faithfulness score means the answer uses information from the retrieved documents, not from the model’s training data. Optimize for faithfulness when accuracy and traceability to source documents are critical, such as in compliance or legal use cases. 

Answer correctness 

Measures whether the generated answer matches the expected ground-truth answers in your test data. A high answer correctness score means the RAG system produces answers that align with your provided correct answers. Optimize for answer correctness when you have well-defined expected answers and want the system to match them closely. 

Context correctness 

Measures whether the retrieved documents are relevant to the question. A high context correctness score means the retrieval step finds the relevant documents from your document set. Optimize for context correctness when retrieval quality is more important than answer phrasing, such as when you plan to use a different generation model in production. 

6.1. METRIC COMBINATIONS 

When you review AutoRAG results, consider metric scores together: 

High faithfulness with low answer correctness indicates that the answer is grounded in the retrieved context, but the context does not contain the most accurate answer. 

High answer correctness with low faithfulness indicates that the model draws on training data rather than retrieved documents. 

Low context correctness with high answer correctness indicates that the generation model is compensating for poor retrieval. This pattern might not be reliable for questions outside your test data. 

Additional resources 

Evaluate AutoRAG results 

AutoRAG configuration parameters 

### CHAPTER 7. AUTORAG CONFIGURATION PARAMETERS

The following user-configurable parameters are available when you create an AutoRAG optimization run in the OpenShift AI dashboard. AutoRAG also uses default values for search space parameters that you cannot change. 

7.1. USER-CONFIGURABLE PARAMETERS 

You set the following parameters when you create an AutoRAG optimization run. 

Table 7.1. User-configurable parameters 

Parameter Description Values 

Run preset Controls the search space and resource allocation for the optimization run. 

Faster (default), Better quality. See Run presets. 

Optimization metric The metric that AutoRAG uses to rank RAG patterns. 

Answer faithfulness (default), Answer correctness, Context correctness 

Maximum RAG patterns The number of RAG configurations that AutoRAG evaluates. 

A value between 4 and 20. Default: 8. 

Foundation models The large language models used for answer generation. Discovered from your OGX instance. 

All available models are selected by default. Clear the checkbox for models to exclude them. 

Embedding models The models used to create vector embeddings and to encode queries during retrieval. Discovered from your OGX instance. 

All available models are selected by default. Clear the checkbox for models to exclude them. 

Vector database The vector database where AutoRAG stores document embeddings. 

A remote Milvus or pgvector (PostgreSQL) instance registered as a vector I/O provider with your OGX instance. 

Input documents Documents that AutoRAG processes and indexes for retrieval. 

PDF, DOCX, PPTX, Markdown, HTML, TXT. Maximum 32 MiB per file when uploading. Documents in S3 can be selected via the file browser without upload size restrictions. 

Evaluation dataset A JSON file with test questions and expected answers for evaluating RAG quality. 

JSON format. See Prepare test data for AutoRAG. 

7.2. RUN PRESETS 

The run preset controls how AutoRAG balances ingestion speed and retrieval quality. 

Faster (default) 

Uses recursive chunking only on exported text. Suitable for most data sets and faster optimization runs. Requires 4 vCPU and 16 GiB of memory. 

Better quality 

Explores both recursive and hybrid chunking with Docling table layout parsing and structural contextualization. Hybrid chunking preserves document structure by prepending heading hierarchy and section paths to each chunk, which improves embedding quality for documents with complex structure. Requires 8 vCPU and 32 GiB of memory. 

7.3. SEARCH SPACE DEFAULTS 

AutoRAG explores the following search space during optimization. The values depend on the selected run preset. For parameters with multiple values, AutoRAG evaluates combinations across RAG configurations. 

Table 7.2. Search space parameters by preset 

Parameter Faster Better quality Description 

Chunking method Recursive Recursive, Hybrid The method used to split documents into chunks. Hybrid chunking uses Docling structural contextualization to preserve heading hierarchy. 

Chunk size 128, 256, 512 512, 1024, 2048 The target size of each document chunk in tokens. 

Chunk overlap 32, 64 0, 128, 256 The number of overlapping tokens between consecutive chunks. 

Retrieval method Simple Simple Direct chunk retrieval. 

Number of chunks 3, 5, 10 3, 5, 10 The number of document chunks retrieved per query. 

Search mode Vector, Hybrid Vector, Hybrid The search strategy. Hybrid search combines vector and keyword search and is available only with Milvus. 

7.4. RECOMMENDED EMBEDDING MODELS 

**For best results, use BAAI/bge-m3 as your embedding model. It supports more than 100 languages, **dense and sparse retrieval, and requires approximately 1.1 GB of memory (fp16). 

7.5. RECOMMENDED FOUNDATION MODELS 

The following foundation models are recommended for use with AutoRAG, organized by resource tier. 

Table 7.3. Recommended foundation models 

Tier Model Best for 

Lightweight **Qwen2.5-7B-Instruct **Highest retrieval precision among small models. Suitable for lowlatency, high-concurrency workloads on limited GPU resources. 

Lightweight **Llama-3.1-8B-Instruct **Text extraction and summarization on edge clusters or single-GPU environments. 

Medium **Mistral-3-14B-Instruct **Strict instruction following, structured JSON output, and tool-call formatting. Suitable for pipelines that require precise output control. 

Enterprise **Llama-3.3-70B-Instruct **Cross-document synthesis, multistep reasoning, and complex tool execution across large datasets. 

Lightweight 

Limited GPU resources or low-latency, high-concurrency workloads. 

Medium 

Higher answer correctness across multiple documents with moderate infrastructure. 

Enterprise 

Complex reasoning, multi-step tool execution, or large-scale document synthesis. 

NOTE 

Foundation models deployed with vLLM require tool calling to be enabled for use with **AutoRAG. Add the --enable-auto-tool-choice and --tool-call-parser arguments to the model server configuration when you deploy the model. The --tool-call-parser value **depends on the model family. 

7.6. CPU-ONLY DEPLOYMENTS 

You can run AutoRAG optimization on CPU-only infrastructure by using lightweight models optimized for CPU inference. 

Table 7.4. Recommended CPU models 

Type Model Throughput Memory 

Embedding **nomic-embed-text-v1.5 **

20–50 ms/query ~1–2 GB 

Embedding **BAAI/bge-m3 **~83 samples/sec (INT8) ~2–3 GB 

Foundation **Phi-4-mini-instruct **(Q4_K_M) 

10–22 tok/sec ~4–5 GB 

Foundation **Qwen3.5-4B-Instruct **(Q4_K_M) 

9.8 tok/sec ~5–6 GB 

Foundation **Qwen2.5-3B-Instruct **(Q4_K_M) 

7–26 tok/sec ~3–4 GB 

Foundation **Llama-3.2-3B-Instruct (Q4_K_M) **

- -

Table 7.5. CPU-only stacks 

Use case Embedding Foundation Chunks E2E latency Total RAM 

Default nomic Phi-4-mini 8 × 1500–2048 chars 

4–12 sec 4–6 GB 

Multilingual bge-m3 Phi-4-mini 8 × 1500–2048 chars 

4–14 sec 5–7 GB 

Higher accuracy 

nomic Qwen3.5-4B 8 × 2048 chars 6–18 sec 6–8 GB 

Memory-constrained 

nomic Qwen2.5-3B 6 × 1200 chars 3–10 sec 3–5 GB 

E2E latency is measured for a 100-token response including embedding, retrieval, and generation. 

Additional resources 

Create an AutoRAG optimization run 

AutoRAG evaluation metrics 

Tool calling in the vLLM documentation 