# AI Pipeline Demo

End-to-end ML pipeline showing data cleaning, training, evaluation, and model registration.

## Deploy

```bash
./deploy.sh                     # Deploy to 'pipeline-demo' namespace
./deploy.sh -n my-namespace     # Custom namespace
./deploy.sh --delete            # Remove
```

## Pipelines

### KFP SDK Pipeline (`pipeline-kfp.py`)

A Kubeflow Pipelines v2 pipeline with 5 components:

1. **data_prep** -- load and normalize loan dataset
2. **train_model** -- train RandomForest classifier
3. **evaluate_model** -- compute accuracy, precision, recall, F1
4. **register_model** -- upload to S3 and register in Model Registry

Compile: `python pipeline-kfp.py`
Upload the generated `loan-pipeline.yaml` to RHOAI Dashboard > Pipelines.

### Elyra Notebook Pipeline (`pipeline-elyra/`)

Visual notebook pipeline for JupyterLab:

1. `01-data-prep.ipynb` -- data loading and cleaning
2. `02-train.ipynb` -- model training
3. `03-evaluate.ipynb` -- evaluation metrics
4. `04-register.ipynb` -- S3 upload + Model Registry

#### Elyra Runtime Setup (one-time, inside workbench)

Before submitting an Elyra pipeline, configure a Kubeflow Pipelines runtime:

1. Open the **Runtime Configuration** panel (wrench icon in left sidebar)
2. Click **+** and select **Kubeflow Pipelines**
3. Fill in:

| Field | Value |
|-------|-------|
| **Display Name** | `pipeline-demo` |
| **Kubeflow Pipelines API Endpoint** | `https://ds-pipeline-pipelines-definition.<namespace>.svc:8443` |
| **Authentication Type** | `KUBERNETES_SERVICE_ACCOUNT_TOKEN` |
| **Cloud Object Storage Endpoint** | `http://minio.<namespace>.svc:9000` |
| **Cloud Object Storage Bucket Name** | `pipelines` |
| **Cloud Object Storage Authentication Type** | `USER_CREDENTIALS` |
| **Cloud Object Storage Username** | *(from `pipelines-s3-credentials` secret, key `AWS_ACCESS_KEY_ID`)* |
| **Cloud Object Storage Password** | *(from `pipelines-s3-credentials` secret, key `AWS_SECRET_ACCESS_KEY`)* |

Replace `<namespace>` with your project name (default: `pipeline-demo`).

To retrieve the S3 credentials, run in the workbench terminal:

```bash
oc extract secret/pipelines-s3-credentials --to=-
```

4. Click **Save**
5. Open a `.pipeline` file and submit -- the runtime should now appear in the dropdown.

> **Note:** The deploy script grants workbench service accounts the `edit` role so Elyra can upload and run pipelines.

## Sample Data

`data/sample-loans.csv` -- 20 sample loan applications with features like income, credit score, DTI ratio.
