"""
KFP SDK v2 Pipeline: LMEval / EvalHub Benchmark Run
====================================================
Wraps the same eval-hub-sdk submit -> poll -> MLflow flow used in the
lmeval-demo notebooks (notebooks/*.ipynb) as a Kubeflow Pipeline, so
benchmark runs are repeatable, parameterized, and trackable in the RHOAI
Dashboard's Pipelines UI (in addition to the MLflow experiment EvalHub
already creates automatically).

Usage:
    python pipeline-kfp.py              # Compile to YAML
    python pipeline-kfp.py --run        # Compile and submit to DSPA (requires kfp.Client() config)

See README.md "Run as a Data Science Pipeline" section for required
parameters (auth token, model endpoint, etc.) and RBAC prerequisites.
"""

from kfp import dsl, compiler
from kfp.dsl import Output, Metrics


@dsl.component(
    base_image="registry.redhat.io/ubi9/python-311:latest",
    packages_to_install=["eval-hub-sdk"],
)
def submit_evaluation(
    evalhub_url: str,
    tenant: str,
    auth_token: str,
    model_name: str,
    model_url: str,
    benchmark_id: str,
    provider_id: str,
    tokenizer: str,
    num_fewshot: int,
    limit: int,
    experiment_name: str,
    job_name: str,
) -> str:
    """Submit an evaluation job to EvalHub. Returns the job ID."""
    from evalhub import (
        SyncEvalHubClient,
        ModelConfig,
        BenchmarkConfig,
        JobSubmissionRequest,
        ExperimentConfig,
        ExperimentTag,
    )

    # eval-hub-sdk 0.1.x Benchmark/Provider models require description/category
    # fields the server doesn't always return -- same workaround as the
    # notebooks. Harmless no-op on SDK versions where the fields are optional.
    try:
        from evalhub.models.api import Benchmark, Provider, ProviderList

        for field_name in ("description", "category"):
            if field_name in Benchmark.model_fields:
                Benchmark.model_fields[field_name].default = None
                Benchmark.model_fields[field_name].annotation = str | None
        Benchmark.model_rebuild(force=True)
        Provider.model_rebuild(force=True)
        ProviderList.model_rebuild(force=True)
    except Exception:
        pass

    client = SyncEvalHubClient(
        base_url=evalhub_url,
        auth_token=auth_token,
        insecure=True,
        tenant=tenant,
    )

    parameters = {"num_fewshot": num_fewshot}
    if limit > 0:
        parameters["limit"] = limit
    if tokenizer:
        parameters["tokenizer"] = tokenizer

    request = JobSubmissionRequest(
        name=job_name,
        model=ModelConfig(url=model_url, name=model_name),
        benchmarks=[
            BenchmarkConfig(
                id=benchmark_id,
                provider_id=provider_id,
                parameters=parameters,
            ),
        ],
        experiment=ExperimentConfig(
            name=experiment_name,
            tags=[
                ExperimentTag(key="source", value="kfp-pipeline"),
                ExperimentTag(key="model", value=model_name),
                ExperimentTag(key="benchmark", value=benchmark_id),
            ],
        ),
    )

    job = client.jobs.submit(request)
    print(f"Job submitted: {job.id}")
    print(f"MLflow experiment: {experiment_name}")
    return job.id


@dsl.component(
    base_image="registry.redhat.io/ubi9/python-311:latest",
    packages_to_install=["eval-hub-sdk"],
)
def wait_for_evaluation(
    evalhub_url: str,
    tenant: str,
    auth_token: str,
    job_id: str,
    poll_interval_seconds: int,
    timeout_seconds: int,
    metrics: Output[Metrics],
) -> str:
    """Poll an EvalHub job until it reaches a terminal state. Logs metrics
    to the KFP run's Metrics tab and returns the final state."""
    import time
    from evalhub import SyncEvalHubClient

    try:
        from evalhub.models.api import Benchmark, Provider, ProviderList

        for field_name in ("description", "category"):
            if field_name in Benchmark.model_fields:
                Benchmark.model_fields[field_name].default = None
                Benchmark.model_fields[field_name].annotation = str | None
        Benchmark.model_rebuild(force=True)
        Provider.model_rebuild(force=True)
        ProviderList.model_rebuild(force=True)
    except Exception:
        pass

    client = SyncEvalHubClient(
        base_url=evalhub_url,
        auth_token=auth_token,
        insecure=True,
        tenant=tenant,
    )

    terminal_states = {"completed", "failed", "error", "cancelled"}
    elapsed = 0
    job = None

    while elapsed < timeout_seconds:
        job = client.jobs.get(job_id)
        state = job.status.state.value if hasattr(job.status.state, "value") else str(job.status.state)
        print(f"[{elapsed}s] Job {job_id} state: {state}")

        if state in terminal_states:
            break

        time.sleep(poll_interval_seconds)
        elapsed += poll_interval_seconds

    if job is None:
        raise RuntimeError(f"Never received a status for job {job_id}")

    final_state = job.status.state.value if hasattr(job.status.state, "value") else str(job.status.state)

    if final_state != "completed":
        message = getattr(job.status, "message", None)
        raise RuntimeError(f"Evaluation job {job_id} ended in state '{final_state}': {message}")

    # Surface every numeric result in the KFP run's Metrics visualization,
    # mirroring what EvalHub already logged to MLflow.
    results = job.results or {}
    logged_any = False
    for benchmark in results.get("benchmarks", []) if isinstance(results, dict) else []:
        for metric_name, metric_value in (benchmark.get("metrics") or {}).items():
            if isinstance(metric_value, (int, float)):
                metrics.log_metric(f"{benchmark.get('id', 'benchmark')}_{metric_name}", float(metric_value))
                logged_any = True

    if not logged_any:
        # Fall back to whatever top-level numeric fields are present
        for key, value in results.items() if isinstance(results, dict) else []:
            if isinstance(value, (int, float)):
                metrics.log_metric(key, float(value))

    print(f"Evaluation completed. mlflow_experiment_id={job.resource.mlflow_experiment_id if hasattr(job, 'resource') else 'n/a'}")
    print(f"Full results: {results}")
    return final_state


@dsl.pipeline(
    name="lmeval-benchmark-run",
    description="Submit an EvalHub benchmark job and wait for completion, with results tracked in both KFP and MLflow",
)
def lmeval_pipeline(
    evalhub_url: str = "https://evalhub.redhat-ods-applications.svc:8443",
    tenant: str = "lmeval-demo",
    auth_token: str = "",
    model_name: str = "redhataiqwen3-8b-fp8-dynamic",
    model_url: str = "https://redhataiqwen3-8b-fp8-dynamic-lmeval-demo.apps.example.com/v1",
    benchmark_id: str = "arc_easy",
    provider_id: str = "lm_evaluation_harness",
    tokenizer: str = "Qwen/Qwen3-8B",
    num_fewshot: int = 0,
    limit: int = 20,
    experiment_name: str = "kfp-lmeval-run",
    job_name: str = "kfp-benchmark",
    poll_interval_seconds: int = 15,
    timeout_seconds: int = 1800,
):
    submit_task = submit_evaluation(
        evalhub_url=evalhub_url,
        tenant=tenant,
        auth_token=auth_token,
        model_name=model_name,
        model_url=model_url,
        benchmark_id=benchmark_id,
        provider_id=provider_id,
        tokenizer=tokenizer,
        num_fewshot=num_fewshot,
        limit=limit,
        experiment_name=experiment_name,
        job_name=job_name,
    )
    submit_task.set_caching_options(False)

    wait_task = wait_for_evaluation(
        evalhub_url=evalhub_url,
        tenant=tenant,
        auth_token=auth_token,
        job_id=submit_task.output,
        poll_interval_seconds=poll_interval_seconds,
        timeout_seconds=timeout_seconds,
    )
    wait_task.set_caching_options(False)
    wait_task.set_retry(num_retries=0)


if __name__ == "__main__":
    import sys

    output_file = "lmeval-pipeline.yaml"
    compiler.Compiler().compile(lmeval_pipeline, output_file)
    print(f"Pipeline compiled to {output_file}")

    if "--run" in sys.argv:
        print("To submit: use the RHOAI dashboard or kfp.Client().create_run_from_pipeline_package()")
