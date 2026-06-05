"""
KFP SDK v2 Pipeline: Loan Approval Model Training
===================================================
End-to-end ML pipeline: data prep -> train -> evaluate -> register in Model Registry.

Usage:
    python pipeline-kfp.py              # Compile to YAML
    python pipeline-kfp.py --run        # Compile and submit to DSPA
"""

from kfp import dsl, compiler
from kfp.dsl import Input, Output, Dataset, Model, Metrics


@dsl.component(
    base_image="registry.redhat.io/ubi9/python-311:latest",
    packages_to_install=["pandas", "scikit-learn"],
)
def data_prep(
    raw_data_path: str,
    cleaned_data: Output[Dataset],
):
    """Load and clean the loan dataset."""
    import pandas as pd

    df = pd.read_csv(raw_data_path)

    df = df.dropna()
    df = df.drop_duplicates()

    numeric_cols = ["age", "income", "loan_amount", "interest_rate",
                    "credit_score", "dti_ratio", "employment_length",
                    "num_credit_lines", "delinquencies"]
    for col in numeric_cols:
        if col in df.columns:
            mean_val = df[col].mean()
            std_val = df[col].std()
            if std_val > 0:
                df[col] = (df[col] - mean_val) / std_val

    cat_cols = ["home_ownership", "loan_purpose"]
    df = pd.get_dummies(df, columns=cat_cols, drop_first=True)

    df.to_csv(cleaned_data.path, index=False)
    print(f"Cleaned data: {len(df)} rows, {len(df.columns)} columns")


@dsl.component(
    base_image="registry.redhat.io/ubi9/python-311:latest",
    packages_to_install=["pandas", "scikit-learn", "joblib"],
)
def train_model(
    cleaned_data: Input[Dataset],
    trained_model: Output[Model],
    test_data: Output[Dataset],
):
    """Train a RandomForest classifier on loan data."""
    import pandas as pd
    from sklearn.model_selection import train_test_split
    from sklearn.ensemble import RandomForestClassifier
    import joblib

    df = pd.read_csv(cleaned_data.path)

    target = "approved"
    X = df.drop(columns=[target, "loan_id"], errors="ignore")
    y = df[target]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    clf = RandomForestClassifier(
        n_estimators=100, max_depth=10, random_state=42
    )
    clf.fit(X_train, y_train)

    joblib.dump(clf, trained_model.path)
    print(f"Model trained on {len(X_train)} samples")

    test_df = X_test.copy()
    test_df[target] = y_test
    test_df.to_csv(test_data.path, index=False)


@dsl.component(
    base_image="registry.redhat.io/ubi9/python-311:latest",
    packages_to_install=["pandas", "scikit-learn", "joblib"],
)
def evaluate_model(
    trained_model: Input[Model],
    test_data: Input[Dataset],
    metrics: Output[Metrics],
):
    """Evaluate the trained model and log metrics."""
    import pandas as pd
    from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
    import joblib

    clf = joblib.load(trained_model.path)
    test_df = pd.read_csv(test_data.path)

    target = "approved"
    X_test = test_df.drop(columns=[target])
    y_test = test_df[target]

    y_pred = clf.predict(X_test)

    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, zero_division=0)
    recall = recall_score(y_test, y_pred, zero_division=0)
    f1 = f1_score(y_test, y_pred, zero_division=0)

    metrics.log_metric("accuracy", accuracy)
    metrics.log_metric("precision", precision)
    metrics.log_metric("recall", recall)
    metrics.log_metric("f1_score", f1)

    print(f"Accuracy:  {accuracy:.4f}")
    print(f"Precision: {precision:.4f}")
    print(f"Recall:    {recall:.4f}")
    print(f"F1 Score:  {f1:.4f}")


@dsl.component(
    base_image="registry.redhat.io/ubi9/python-311:latest",
    packages_to_install=["boto3", "joblib", "requests"],
)
def register_model(
    trained_model: Input[Model],
    model_name: str,
    model_version: str,
    s3_bucket: str,
    s3_endpoint: str,
    registry_url: str,
):
    """Upload model to S3 and register in Model Registry."""
    import joblib
    import boto3
    import requests
    import os

    s3_key = f"models/{model_name}/{model_version}/model.joblib"
    s3_client = boto3.client(
        "s3",
        endpoint_url=s3_endpoint,
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", "minio"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "minio123"),
        verify=False,
    )

    try:
        s3_client.head_bucket(Bucket=s3_bucket)
    except Exception:
        s3_client.create_bucket(Bucket=s3_bucket)

    s3_client.upload_file(trained_model.path, s3_bucket, s3_key)
    s3_uri = f"s3://{s3_bucket}/{s3_key}"
    print(f"Model uploaded to {s3_uri}")

    if registry_url:
        try:
            resp = requests.post(
                f"{registry_url}/api/model_registry/v1alpha3/registered_models",
                json={"name": model_name, "description": "Loan approval classifier"},
                verify=False,
            )
            model_id = resp.json().get("id", "unknown")

            requests.post(
                f"{registry_url}/api/model_registry/v1alpha3/model_versions",
                json={
                    "name": model_version,
                    "registeredModelId": model_id,
                    "customProperties": {
                        "s3_uri": {"string_value": s3_uri},
                        "framework": {"string_value": "sklearn"},
                    },
                },
                verify=False,
            )
            print(f"Registered in Model Registry: {model_name} v{model_version}")
        except Exception as e:
            print(f"Model Registry registration skipped: {e}")


@dsl.pipeline(
    name="loan-approval-training",
    description="Train and register a loan approval ML model",
)
def loan_pipeline(
    raw_data_path: str = "https://raw.githubusercontent.com/gymnatics/RHOAI-Toolkit/main/demo/pipeline-demo/data/sample-loans.csv",
    model_name: str = "loan-approval-classifier",
    model_version: str = "v1",
    s3_bucket: str = "models",
    s3_endpoint: str = "http://minio:9000",
    registry_url: str = "http://team-models.rhoai-model-registries.svc:8080",
):
    prep_task = data_prep(raw_data_path=raw_data_path)

    train_task = train_model(cleaned_data=prep_task.outputs["cleaned_data"])

    evaluate_model(
        trained_model=train_task.outputs["trained_model"],
        test_data=train_task.outputs["test_data"],
    )

    register_model(
        trained_model=train_task.outputs["trained_model"],
        model_name=model_name,
        model_version=model_version,
        s3_bucket=s3_bucket,
        s3_endpoint=s3_endpoint,
        registry_url=registry_url,
    )


if __name__ == "__main__":
    import sys

    output_file = "loan-pipeline.yaml"
    compiler.Compiler().compile(loan_pipeline, output_file)
    print(f"Pipeline compiled to {output_file}")

    if "--run" in sys.argv:
        print("To submit: use the RHOAI dashboard or kfp.Client().create_run_from_pipeline_package()")
