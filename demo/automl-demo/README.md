# AutoML Demo (Technology Preview)

Automated machine learning model training and comparison using AutoGluon via Kubeflow Pipelines.

## What AutoML Does

Upload CSV data, pick a prediction task type, and AutoML automatically:
- Trains multiple candidate models using different algorithms
- Evaluates each model against a held-out test set
- Ranks models on a leaderboard by optimized metric
- Generates notebooks for evaluation and exploration
- Registers winning models to Model Registry for deployment

## Supported Task Types

| Task Type | Prediction | Optimized Metric |
|-----------|-----------|-----------------|
| Binary Classification | Two categories (yes/no, pass/fail) | Accuracy |
| Multiclass Classification | Three or more categories | Accuracy |
| Regression | Continuous numerical values | R-squared |
| Time Series Forecasting | Future values over time | MASE |

## Deploy

```bash
./deploy.sh                    # Deploy infrastructure
./deploy.sh -n my-namespace    # Custom namespace
./deploy.sh --delete           # Remove
```

This deploys:
- MinIO (pipeline artifacts + sample data storage)
- Pipeline Server (DSPA for Kubeflow Pipelines)
- AutoGluon ServingRuntime (for deploying trained models)
- S3 data connection with sample CSV

## Using AutoML (Dashboard Walkthrough)

### 1. Create an Optimization Run

1. Open RHOAI Dashboard
2. Navigate to **Develop and train > AutoML**
3. Click **Create run**
4. Configure data source:
   - S3 Connection: `AutoML Training Data`
   - Browse bucket and select `loan-approval.csv`
5. Configure prediction:
   - Task type: **Binary Classification**
   - Label column: `loan_status`
6. Top models to consider: 3 (default)
7. Click **Create run**

### 2. Evaluate Results

- Wait for the run to complete (~5-10 minutes)
- Review the leaderboard -- models ranked by accuracy
- Click **View details** for any model to see:
  - Evaluation metrics
  - Feature importance scores
  - Confusion matrix

### 3. Deploy Best Model

1. From the leaderboard, select **Register model** for the best model
2. Navigate to **Model Registry** to find the registered model
3. Deploy the model version:
   - Serving runtime: **AutoGluon ServingRuntime for KServe**
   - Model framework: **autogluon - 1**

### 4. Run Predictions (Optional)

1. From the leaderboard, select **Save notebook**
2. Create a workbench in the RHOAI dashboard
3. Attach the S3 data connection
4. Upload and run the notebook

## Sample Data

`sample-data/loan-approval.csv` -- Loan approval dataset with features:
- `applicant_income`, `coapplicant_income`, `loan_amount`, `loan_term`
- `gender`, `married`, `dependents`, `education`, `self_employed`
- `credit_history`, `property_area`
- `loan_status` (target: Y/N)

## Prerequisites

- RHOAI 3.4 with `aipipelines: Managed` in DataScienceCluster
- At least 4 CPUs and 16 GiB memory available for scheduling
- CSV data: UTF-8 encoding, comma delimiters, header row, max 32 MiB (dashboard upload)

## Limitations (Technology Preview)

- CSV format only
- Training data capped at 32 MiB (dashboard) or 100 MB (S3)
- No custom algorithm or hyperparameter selection
- Runs cannot be edited after creation
