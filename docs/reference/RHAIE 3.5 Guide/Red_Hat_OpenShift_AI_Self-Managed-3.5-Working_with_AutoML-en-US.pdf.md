# Red_Hat_OpenShift_AI_Self-Managed-3.5-Working_with_AutoML-en-US.pdf

- Red Hat OpenShift AI Self-Managed 3.5

# Working with AutoML

Use AutoML in Red Hat OpenShift AI Self-Managed 

Last Updated: 2026-08-25

### Red Hat OpenShift AI Self-Managed  3.5 Working with AutoML

Use AutoML in Red Hat OpenShift AI Self-Managed

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

Use AutoML in Red Hat OpenShift AI Self-Managed to automatically train and compare machine learning models for your tabular data.

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

CHAPTER 1. AUTOMATED MODEL SELECTION WITH AUTOML 1.1. AUTOML WORKFLOW 1.2. SUPPORTED TASK TYPES 1.3. TECHNOLOGY PREVIEW LIMITATIONS 1.4. VIEWING EXTERNALLY CREATED RUNS 

CHAPTER 2 CREATE AN AUTOML OPTIMIZATION RUN 

CHAPTER 3 EVALUATE AUTOML RESULTS 

CHAPTER 4 RUN PREDICTIONS WITH AN AUTOML MODEL 

CHAPTER 5 DEPLOY AN AUTOML MODEL FOR INFERENCE 

CHAPTER 6 AUTOML EVALUATION METRICS 6.1. DEFAULT OPTIMIZATION METRICS 6.2. MODEL DETAIL VIEWS 

CHAPTER 7 AUTOML CONFIGURATION PARAMETERS 7.1. COMMON PARAMETERS 7.2. TABULAR TASK PARAMETERS 7.3. TIME SERIES TASK PARAMETERS 7.4. AUTO-SELECTED PARAMETERS 

3 

4 4 4 4 4 

6 

8 

9 

10 

11 11 11 

13 13 13 14 14 

### PREFACE

You can use AutoML in OpenShift AI to train, evaluate, and compare machine learning models for your tabular data. 

IMPORTANT 

AutoML is a Technology Preview feature only. Technology Preview features are not supported with Red Hat production service level agreements (SLAs) and might not be functionally complete. Red Hat does not recommend using them in production. These features provide early access to upcoming product features, enabling customers to test functionality and provide feedback during the development process. 

For more information about the support scope of Red Hat Technology Preview features, see Technology Preview Features Support Scope . 

### CHAPTER 1. AUTOMATED MODEL SELECTION WITH AUTOML

AutoML is an automated machine learning system in Red Hat OpenShift AI that finds the best model for your prediction task. You provide training data in CSV format and select a task type. AutoML trains and evaluates multiple models, ranks them on a leaderboard, and produces notebooks that you can use to run predictions with the best-performing model. 

1.1. AUTOML WORKFLOW 

When you create an AutoML optimization run, AutoML loads your training data, samples it if needed, splits it into training and test sets, and trains candidate models by using different algorithms and configurations. AutoML evaluates each model against the held-out test set. The leaderboard ranks models by the optimized metric for your task type, and you can sort by other metrics to compare performance. You can register a model to a model registry or save a notebook for evaluation and exploration. After you register a model, you can deploy it for inference with a compatible serving runtime. 

1.2. SUPPORTED TASK TYPES 

Binary classification 

Predict outcomes with two distinct categories, such as pass or fail, or approved or denied. 

Multiclass classification 

Predict outcomes with three or more distinct categories, such as product categories or support ticket priorities. 

Regression 

Predict continuous numerical values, such as price, temperature, or duration. 

Time series forecasting 

Predict future values over a specified date or time range. Your data must include a timestamp column, a numeric target column, and an ID column that identifies each time series. 

1.3. TECHNOLOGY PREVIEW LIMITATIONS 

The following limitations apply during Technology Preview: 

CSV format training data only 

Training data capped at 32 MiB when uploaded through the dashboard, or 100 MB when loaded from S3 

No custom algorithm selection or hyperparameter tuning 

Optimization runs cannot be edited after creation 

1.4. VIEWING EXTERNALLY CREATED RUNS 

AutoML pipelines are automatically registered with your pipeline server when your pipeline server starts. If you create runs from these pipelines outside of the AutoML interface, the runs appear on the AutoML page in the dashboard. 

Additional resources 

Create an AutoML optimization run 

Evaluate AutoML results 

Run predictions with an AutoML model 

Deploy an AutoML model for inference 

AutoML evaluation metrics 

AutoML configuration parameters 

AutoML tabular tutorial on GitHub 

AutoML time series forecasting tutorial  on GitHub 

To find the best model for your data, create an AutoML optimization run, evaluate the results, and register or test the best-performing model. 

Before you begin, ensure that the following prerequisites are met: 

**A cluster administrator has set the value of the spec.dashboardConfig.automl dashboard configuration option to true. For more information, see Dashboard configuration options **. 

You have a pipeline server configured in your project. When configuring the pipeline server, select the Enable AutoML and AutoRAG pipelines checkbox in Advanced settings. If you **create the DataSciencePipelinesApplication instance with YAML, set spec.apiServer.managedPipelines: {}. For more information, see Configuring a pipeline **server. 

Your training data is available in an S3-compatible storage bucket in CSV format. 

IMPORTANT 

Upload updated AutoML pipeline definitions before you create your first run. For instructions and download links, see RHOAIENG-64768 - AutoML and AutoRAG pipeline runs fail with image pull errors in the release notes. 

### CHAPTER 2. CREATE AN AUTOML OPTIMIZATION RUN

Create an AutoML optimization run to train and evaluate machine learning models for your data set. 

Prerequisites 

You have editor access to a project in OpenShift AI. 

**A cluster administrator has set the value of the spec.dashboardConfig.automl dashboard configuration option to true. For more information, see Dashboard configuration options **. 

You have a pipeline server configured in your project. When configuring the pipeline server, select the Enable AutoML and AutoRAG pipelines checkbox in Advanced settings. For more information, see Configuring a pipeline server. 

Your cluster has at least 4 CPUs and 16 GiB memory available for scheduling. 

Your training data is available in an S3-compatible storage bucket in CSV format. 

Your CSV file uses UTF-8 encoding and comma delimiters, and includes a header row. Maximum file size is 32 MiB when uploading through the dashboard. 

Procedure 

1. In the OpenShift AI dashboard, click Develop and train > AutoML. 

2. Select a project and click Create AutoML optimization run. 

3. Enter a name and optionally a description for the optimization run and click Next. 

4. Configure the data source as follows: 

a. From the S3 connection list, select an existing data connection or click Add new connection. 

b. Click Browse bucket and select your CSV data file. 

5. Select the prediction task type and configure the prediction settings: 

Binary classification: Your target column has two distinct categories. 

Multiclass classification: Your target column has three or more distinct categories. 

Regression: Your target column has continuous numerical values. 

Time series forecasting: Your data is sequential and you want to predict future values. 

a. For binary classification, multiclass classification, or regression: 

Select the Label column from your data set. 

b. For time series forecasting: 

Select the Target column with the numerical values to forecast. 

Select the Timestamp column with the date or time values. 

Select the ID column that identifies each time series. 

Optional: Select Known covariates for values known in advance across the forecast horizon. 

Set the Prediction length for the number of time steps to forecast. 

6. Optional: Adjust the Top models to consider value (default 3, range 1 to 10 for tabular, 1 to 7 for time series). 

7. Optional: To change the optimization metric, in the Optimization Metric card, click Edit, select a metric, and click Save. The default metric depends on the task type. For more information, see AutoML evaluation metrics. 

NOTE 

Optimization runs cannot be edited after creation. To stop, archive, or delete the underlying pipeline run, see Managing pipeline runs. 

8. Click Create run. AutoML begins training models. You can monitor the run status on the AutoML page. 

Verification 

On the AutoML page, verify that the optimization run is displayed in the list with a status indicating that it is running or complete. 

Additional resources 

Evaluate AutoML results 

AutoML configuration parameters 

### CHAPTER 3. EVALUATE AUTOML RESULTS

After an AutoML optimization run completes, review the leaderboard and model details to select the best model for your use case. You can register a model to a model registry or save a notebook for evaluation and exploration. 

Prerequisites 

You have created an AutoML optimization run and the run status is Completed. For more information, see Create an AutoML optimization run . 

Procedure 

1. In the OpenShift AI dashboard, click Develop and train > AutoML. 

2. Click the name of your completed run to view the results. 

3. Review the leaderboard, which ranks trained models by the optimized metric for your task type. The top-ranked model is highlighted. Click a column header to sort by a different metric. 

4. To view detailed information about a model, click View details from the actions menu. The model details view includes evaluation metrics, feature importance scores, confusion matrix, ROC curves, and precision recall curves. 

5. Review the feature importance and the confusion matrix across models to verify that the bestscoring model produces predictions that you can explain and trust. 

6. For classification models, view the ROC curves and precision recall curves to assess how the model performs across different decision thresholds. 

7. To register the selected model to a model registry, select Register model from the actions menu and select a model registry. 

8. To save a notebook, select Save notebook from the actions menu. 

Verification 

If you registered a model, navigate to the model registry and verify that the model is displayed. 

If you saved a notebook, verify that the notebook file downloaded to your local system. 

Additional resources 

Run predictions with an AutoML model 

Deploy an AutoML model for inference 

AutoML evaluation metrics 

Working with model registries 

### CHAPTER 4. RUN PREDICTIONS WITH AN AUTOML MODEL

After you save a notebook from the AutoML leaderboard in OpenShift AI, run it in a workbench to load the trained model and run predictions on sample data. 

Prerequisites 

You have created an AutoML optimization run and saved a notebook from the leaderboard. For more information, see Evaluate AutoML results . 

You have a running workbench in your OpenShift AI project. 

You have the connection details for the S3-compatible object storage bucket configured for the AI Pipelines server in your project. 

Procedure 

1. In the OpenShift AI dashboard, open your workbench. 

2. Add the S3-compatible object storage connection configured for the AI Pipelines server to the workbench: 

a. On the workbench edit page, scroll to the Connections section. 

b. Click Attach existing connections. 

c. Select the connection and click Attach. 

d. Click Update workbench. 

3. Upload the saved notebook to the workbench. 

4. Open the notebook and run all cells. The notebook loads the trained model from S3 and runs predictions on sample data. The final cells in the notebook display sample predictions from test inputs. 

Verification 

Verify that all cells in the notebook completed without errors. 

Verify that the model returns predictions for test inputs. 

Additional resources 

Evaluate AutoML results 

### CHAPTER 5. DEPLOY AN AUTOML MODEL FOR INFERENCE

After you register a model from the AutoML leaderboard, you can deploy it for inference with the AutoGluon serving runtime. Deploying the model creates a REST API endpoint that you can use to send prediction requests. 

Prerequisites 

You have registered a model from the AutoML leaderboard to a model registry. For more information, see Evaluate AutoML results . 

The AutoGluon serving runtime is available in your project. 

NOTE 

An administrator can control the availability of serving runtimes for a project by managing ServingRuntime template resources. If the AutoGluon runtime has been disabled for your project, it does not appear as a selectable option in the deployment UI. 

Procedure 

1. Deploy the registered model version from the model registry by following the steps in Deploying a model version from a model registry. Configure the deployment with the following values: 

For Model framework, select autogluon - 1. 

For Serving runtime, select AutoGluon ServingRuntime for KServe. 

Verification 

On the Deployments page, verify that the model deployment shows a status of Ready. 

Additional resources 

Evaluate AutoML results 

Deploying a model version from a model registry 

### CHAPTER 6. AUTOML EVALUATION METRICS

AutoML evaluates each trained model with metrics appropriate for the prediction task type. The leaderboard ranks models by the optimization metric. You can change the optimization metric when you create an optimization run. Additional metrics might appear on the leaderboard depending on the task type. 

6.1. DEFAULT OPTIMIZATION METRICS 

The following metrics are used by default when you do not select an optimization metric. 

Table 6.1. Optimized metrics 

Task type Optimized metric 

Binary classification Accuracy 

Multiclass classification Accuracy 

Regression R2 

Time series forecasting MASE (Mean Absolute Scaled Error) 

Accuracy 

The proportion of predictions that are correct. A high accuracy score means the model correctly classifies most inputs. 

R2 (R-squared) 

The proportion of variance in the target variable that the model explains. A score of 1.0 means the model perfectly predicts the target. A score of 0.0 means the model performs no better than predicting the mean. 

MASE (Mean Absolute Scaled Error) 

A scale-independent measure of forecast accuracy. AutoML negates MASE values so that higher values indicate better models, consistent with all other metrics on the leaderboard. A raw MASE below 1.0 means the model outperforms a naive baseline forecast. 

Additional optimization metrics are available for each task type. To view and select a metric, click Edit in the Optimization Metric card when you create an optimization run. 

6.2. MODEL DETAIL VIEWS 

Feature importance 

Shows which input features had the most influence on the model’s predictions. Use feature importance to verify that the model relies on meaningful features rather than noise or data artifacts. Feature importance is available for binary classification, multiclass classification, and regression tasks. It is not available for time series forecasting tasks. 

Confusion matrix 

Shows predicted compared to actual class distributions as a grid. Use the confusion matrix to identify which classes the model confuses most often. The confusion matrix is available for binary and multiclass classification tasks only. 

Receiver Operating Characteristic (ROC) curve 

Shows how well the model separates positive and negative predictions at different decision thresholds. Use the ROC curve to choose a threshold that balances false positives and false negatives for your use case. ROC curves are available for binary and multiclass classification tasks only. Runs created before OpenShift AI 3.5 do not include ROC curve data. 

Precision recall curve 

Shows how well the model balances finding all positive cases (recall) versus avoiding false positives (precision) across different decision thresholds. Use the precision recall curve to evaluate models on imbalanced datasets or when false positives are costly. Precision recall curves are available for binary and multiclass classification tasks only. Runs created before OpenShift AI 3.5 do not include precision recall curve data. 

Backtesting 

Shows average error metrics across rolling validation windows, per-window metric trends, and forecast-compared-to-observed charts for the best and worst performing windows. Use backtesting to evaluate how consistently the model forecasts across different time periods. Backtesting is available for time series forecasting tasks only. Runs created before OpenShift AI 3.5 do not include backtesting data. 

Additional resources 

Evaluate AutoML results 

AutoML configuration parameters 

### CHAPTER 7. AUTOML CONFIGURATION PARAMETERS

You can configure several parameters when you create an AutoML optimization run in the OpenShift AI dashboard. 

7.1. COMMON PARAMETERS 

You set the following parameters for all task types. 

Table 7.1. Common parameters 

Parameter Description Values 

S3 connection The data connection for your S3-compatible storage bucket. 

Existing data connections in your project, or create a new connection. 

Training data file The CSV file containing your training data. Must use UTF-8 encoding and comma delimiters with a header row. 

CSV format. Maximum 32 MiB when uploading through the dashboard, or 100 MB when loaded from S3. 

Prediction task type The type of prediction problem. Binary classification, Multiclass classification, Regression, Time series forecasting 

Top models to consider The number of top-performing models to refit on the full training set. 

1-10 (tabular) or 1-7 (time series), default 3 

Optimization metric The metric used to rank models on the leaderboard. Click Edit to select a different metric. 

Default depends on task type. For more information, see AutoML evaluation metrics. 

Preset The training quality tier, which determines resource allocation for the training job. 

**speed (default) or balanced. The balanced preset allocates **more CPU and memory but training can take more than twice as long. 

7.2. TABULAR TASK PARAMETERS 

You set the following parameter for binary classification, multiclass classification, and regression tasks. 

Table 7.2. Tabular task parameters 

Parameter Description Values 

Label column The column in your data set that contains the values to predict. 

Populated from the CSV file schema. 

7.3. TIME SERIES TASK PARAMETERS 

You set the following parameters for time series forecasting tasks. 

Table 7.3. Time series task parameters 

Parameter Description Values 

Target column The column with the numerical values to forecast. 

Populated from the CSV file schema. 

Timestamp column The column with the date or time values. 

Populated from the CSV file schema. 

ID column The column that identifies each time series. 

Required. Populated from the CSV file schema. 

Known covariates Columns with values that are known in advance across the forecast horizon. 

Optional. Populated from the CSV file schema. 

Prediction length The number of time steps to forecast. 

Positive integer. 

7.4. AUTO-SELECTED PARAMETERS 

AutoML automatically selects the following during training. You cannot configure these values. 

Algorithms and hyperparameters: AutoML uses AutoGluon to select and tune candidate models. 

Train/test split: AutoML splits your data into training and test sets for evaluation. 

Additional resources 

Create an AutoML optimization run 

AutoML evaluation metrics 