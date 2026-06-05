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

Open in the Elyra workbench and create a pipeline from these notebooks.

## Sample Data

`data/sample-loans.csv` -- 20 sample loan applications with features like income, credit score, DTI ratio.
