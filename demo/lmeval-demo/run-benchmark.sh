#!/bin/bash
################################################################################
# Run LMEval Benchmarks
################################################################################
# Submit LMEvalJob CRs against a deployed model. Supports both English and
# Korean benchmark suites.
#
# Usage:
#   ./run-benchmark.sh                          # Interactive -- pick benchmark
#   ./run-benchmark.sh mmlu                     # Run MMLU directly
#   ./run-benchmark.sh --model qwen3-32b --model-ns admin-workshop mmlu
#   ./run-benchmark.sh --list                   # List available benchmarks
#   ./run-benchmark.sh --status                 # Check running jobs
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"

NAMESPACE="${NAMESPACE:-lmeval-demo}"
MODEL_NAME=""
MODEL_NAMESPACE=""
BENCHMARK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --model) MODEL_NAME="$2"; shift 2 ;;
        --model-ns) MODEL_NAMESPACE="$2"; shift 2 ;;
        --list) LIST_MODE=true; shift ;;
        --status) STATUS_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [BENCHMARK]"
            echo ""
            echo "Options:"
            echo "  --model NAME        Model name (auto-detected if not set)"
            echo "  --model-ns NS       Model namespace (auto-detected if not set)"
            echo "  -n, --namespace NS  LMEval namespace (default: lmeval-demo)"
            echo "  --list              List available benchmarks"
            echo "  --status            Check running LMEvalJob status"
            echo ""
            echo "Benchmarks:"
            echo "  mmlu                MMLU - 57 subjects, 5-shot"
            echo "  reasoning           ARC Challenge + HellaSwag + Winogrande"
            echo "  truthful-math       TruthfulQA + GSM8K"
            echo "  ifeval-bbh          IFEval + BIG-Bench Hard"
            echo "  all-english         All English benchmarks"
            echo "  korean              Korean benchmarks (via EvalHub lab notebooks)"
            exit 0
            ;;
        *) BENCHMARK="$1"; shift ;;
    esac
done

# --- Status mode ---
if [ "${STATUS_MODE:-}" = true ]; then
    print_header "LMEvalJob Status"
    oc get lmevaljob -n "$NAMESPACE" 2>/dev/null || print_info "No LMEvalJobs found in $NAMESPACE"
    echo ""
    RUNNING=$(oc get lmevaljob -n "$NAMESPACE" -o jsonpath='{range .items[?(@.status.state=="Running")]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
    if [ -n "$RUNNING" ]; then
        print_info "Running jobs:"
        echo "$RUNNING" | while read -r job; do
            echo "    $job -- logs: oc logs -f job/$job -n $NAMESPACE"
        done
    fi
    exit 0
fi

# --- List mode ---
if [ "${LIST_MODE:-}" = true ]; then
    print_header "Available Benchmarks"
    echo ""
    echo "  English:"
    echo "    mmlu              57-subject knowledge test (5-shot)"
    echo "    reasoning         ARC Challenge + HellaSwag + Winogrande"
    echo "    truthful-math     TruthfulQA + GSM8K"
    echo "    ifeval-bbh        IFEval + BIG-Bench Hard"
    echo "    all-english       All of the above"
    echo ""
    echo "  Korean (via EvalHub lab notebooks):"
    echo "    korean            KMMLU, CLIcK, KoBEST, HAE-RAE"
    echo ""
    echo "  Performance (language-agnostic):"
    echo "    guidellm          GuideLLM throughput benchmark (via EvalHub lab)"
    echo ""
    exit 0
fi

# --- Auto-detect model ---
if [ -z "$MODEL_NAME" ]; then
    print_step "Auto-detecting model..."
    FIRST_ISVC=$(oc get inferenceservice -A --no-headers 2>/dev/null | head -1)
    if [ -n "$FIRST_ISVC" ]; then
        MODEL_NAMESPACE=$(echo "$FIRST_ISVC" | awk '{print $1}')
        MODEL_NAME=$(echo "$FIRST_ISVC" | awk '{print $2}')
        print_success "Detected: $MODEL_NAME in $MODEL_NAMESPACE"
    else
        print_error "No InferenceService found. Deploy a model first or use --model and --model-ns."
        exit 1
    fi
fi

# --- Get SA token (long-lived Secret first, then short-lived fallback) ---
SA_TOKEN=$(oc get secret lmeval-sa-token -n "$NAMESPACE" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null)
if [ -z "$SA_TOKEN" ]; then
    SA_TOKEN=$(oc create token lmeval-sa -n "$NAMESPACE" --duration=24h 2>/dev/null || \
               oc create token default -n "$NAMESPACE" --duration=24h 2>/dev/null)
fi

if [ -z "$SA_TOKEN" ]; then
    print_error "Failed to get SA token. Run deploy.sh first to create RBAC."
    exit 1
fi

export NAMESPACE MODEL_NAME MODEL_NAMESPACE SA_TOKEN

# --- Interactive selection ---
if [ -z "$BENCHMARK" ]; then
    print_header "LMEval Benchmark Runner"
    echo ""
    echo "  Model: $MODEL_NAME ($MODEL_NAMESPACE)"
    echo ""
    echo "  English benchmarks:"
    echo "    1) MMLU (57-subject knowledge, ~30 min)"
    echo "    2) Reasoning (ARC + HellaSwag + Winogrande, ~20 min)"
    echo "    3) TruthfulQA + GSM8K (~15 min)"
    echo "    4) IFEval + BBH (~20 min)"
    echo "    5) All English benchmarks"
    echo ""
    echo "  Korean benchmarks:"
    echo "    6) Korean (use EvalHub lab notebooks instead)"
    echo ""
    read -rp "Select [1-6]: " choice
    case $choice in
        1) BENCHMARK="mmlu" ;;
        2) BENCHMARK="reasoning" ;;
        3) BENCHMARK="truthful-math" ;;
        4) BENCHMARK="ifeval-bbh" ;;
        5) BENCHMARK="all-english" ;;
        6)
            echo ""
            print_info "Korean benchmarks use the EvalHub SDK via notebooks."
            echo "  Clone the lab repo in your workbench:"
            echo "  git clone https://github.com/hyogrin/rhoai-lmeval-builder-lab.git"
            echo "  Run: 2_eval_hub_kmcq_benchmark/1_kmcq_benchmark.ipynb"
            exit 0
            ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
fi

# --- Submit benchmarks ---
submit_benchmark() {
    local file="$1"
    local name="$2"
    if [ -f "$file" ]; then
        print_step "Submitting $name..."
        envsubst < "$file" | oc apply -f -
    else
        print_error "Benchmark file not found: $file"
    fi
}

case "$BENCHMARK" in
    mmlu)
        submit_benchmark "$SCRIPT_DIR/benchmarks/english-mmlu.yaml" "MMLU"
        ;;
    reasoning)
        submit_benchmark "$SCRIPT_DIR/benchmarks/english-reasoning.yaml" "ARC + HellaSwag + Winogrande"
        ;;
    truthful-math)
        submit_benchmark "$SCRIPT_DIR/benchmarks/english-truthful-math.yaml" "TruthfulQA + GSM8K"
        ;;
    ifeval-bbh)
        submit_benchmark "$SCRIPT_DIR/benchmarks/english-ifeval-bbh.yaml" "IFEval + BBH"
        ;;
    all-english)
        submit_benchmark "$SCRIPT_DIR/benchmarks/english-mmlu.yaml" "MMLU"
        submit_benchmark "$SCRIPT_DIR/benchmarks/english-reasoning.yaml" "ARC + HellaSwag + Winogrande"
        submit_benchmark "$SCRIPT_DIR/benchmarks/english-truthful-math.yaml" "TruthfulQA + GSM8K"
        submit_benchmark "$SCRIPT_DIR/benchmarks/english-ifeval-bbh.yaml" "IFEval + BBH"
        ;;
    korean)
        print_info "Korean benchmarks use the EvalHub SDK via notebooks."
        echo "  Clone the lab repo in your workbench and run the Korean MCQ notebooks."
        exit 0
        ;;
    *)
        print_error "Unknown benchmark: $BENCHMARK"
        echo "Use --list to see available benchmarks"
        exit 1
        ;;
esac

echo ""
print_success "Benchmark jobs submitted"
echo ""
echo "  Monitor progress:"
echo "    oc get lmevaljob -n $NAMESPACE -w"
echo "    ./run-benchmark.sh --status"
echo ""
echo "  View logs:"
echo "    oc logs -f \$(oc get pods -n $NAMESPACE -l lmevaljob --no-headers | head -1 | awk '{print \$1}') -n $NAMESPACE"
echo ""
echo "  Results tracked in MLflow (if EvalHub is deployed)"
echo ""
