# AI Pipelines and Training on OpenShift AI

## Kubeflow Pipelines

OpenShift AI integrates Kubeflow Pipelines for ML workflow automation. Pipelines are defined using the KFP SDK (Python) or Elyra visual pipeline editor.

### Pipeline Components
A typical ML pipeline includes:
1. **Data preparation**: Load, clean, and split datasets
2. **Feature engineering**: Transform raw data into model features
3. **Model training**: Train models using various frameworks
4. **Model evaluation**: Assess model performance on test data
5. **Model registration**: Save trained models to the Model Registry
6. **Model deployment**: Deploy models for inference

### Pipeline Server (DSPA)
DataSciencePipelineApplication (DSPA) is the custom resource that configures the pipeline server in a namespace. It requires S3-compatible storage for pipeline artifacts.

### Elyra
Elyra provides a visual pipeline editor in JupyterLab that lets you chain notebooks into pipelines without writing pipeline code. Each notebook becomes a pipeline step.

## AutoML

AutoML automates the model training process:
1. Upload CSV training data to S3
2. Select prediction task type and target column
3. AutoML trains multiple models using AutoGluon
4. Review the leaderboard and compare models
5. Register and deploy the best model

Supported tasks: Binary Classification, Multiclass Classification, Regression, Time Series Forecasting.

## Distributed Training

### Kubeflow Trainer v2
Trainer v2 supports distributed training with JIT checkpointing and S3 storage for checkpoints. It requires the JobSet operator.

### Ray
Ray provides distributed computing for training and hyperparameter tuning. It integrates with KubeRay for Kubernetes-native Ray cluster management.

## Experiment Tracking

### MLflow
MLflow is integrated as a managed DSC component for experiment tracking, model versioning, and artifact management. Experiments can be tracked from notebooks, pipelines, and evaluation workflows.

Key features:
- Experiment tracking with metrics, parameters, and artifacts
- Model versioning and lineage
- Integration with Model Registry
- Automatic logging from popular ML frameworks
