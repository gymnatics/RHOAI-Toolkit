#!/bin/bash
################################################################################
# run-tests.sh -- offline tests for toolkit-ops checks (fake oc + fake curl + fixture cluster)
# Usage: .claude/skills/toolkit-ops/tests/run-tests.sh
################################################################################
set -u
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C="$T/../checks"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/toolkit-ops-test.XXXXXX")"
python3 -I "$T/make-fixture.py" "$WORK/fixture.json" >/dev/null

mkdir -p "$WORK/bin"
printf '#!/bin/bash\nexec python3 -I "%s" "$@"\n' "$T/mock-oc.py" > "$WORK/bin/oc"
# fake curl: hosts containing ".ok.test" or rh-ai answer 200, maas answers 401, everything else fails
cat > "$WORK/bin/curl" <<'EOF'
#!/bin/bash
url="${@: -1}"
for a in "$@"; do case "$a" in http://*|https://*) url="$a" ;; esac; done
# functional probes (check-demos.sh "probe" rows) read response bodies
case "$url" in
  *open-webui.ok.test/api/v1/auths/signin) echo '{"token":"t"}'; exit 0 ;;
  *open-webui.ok.test/api/models) echo '{"data":[{"id":"qwen3-8b"},{"id":"arena-model"}]}'; exit 0 ;;
  *nemo.ok.test/v1/guardrail/checks) echo '{"status":"blocked"}'; exit 0 ;;
  *lemonade.ok.test/api/chat) printf 'data: {"type": "error", "message": "Backend error (401)"}\n\n'; exit 0 ;;
esac
case "$url" in
  *.ok.test*|*rh-ai.*) echo -n 200 ;;
  *maas.*) echo -n 401 ;;
  *) echo -n 000; exit 7 ;;
esac
EOF
chmod +x "$WORK/bin/oc" "$WORK/bin/curl"
export PATH="$WORK/bin:$PATH" MOCK_OC_FIXTURE="$WORK/fixture.json" MOCK_OC_LOG="$WORK/oc.log"

pass=0; fail=0
expect() {  # results-file area id status
    if awk -F'\t' -v a="$2" -v i="$3" -v s="$4" '$1==a && $2==i && $3==s {f=1} END{exit !f}' "$1"; then
        pass=$((pass+1))
    else
        fail=$((fail+1))
        echo "  FAIL: expected $2/$3 = $4; got: $(awk -F'\t' -v a="$2" -v i="$3" '$1==a && $2==i {print $3": "$4}' "$1" | head -1)"
    fi
}
run() {  # name script args...
    local name="$1"; shift
    export TOOLKIT_OPS_RESULTS="$WORK/$name.tsv"; : > "$TOOLKIT_OPS_RESULTS"
    bash "$C/$@" --quiet > "$WORK/$name.out" 2>&1
    echo "$name: exit=$? ($(wc -l < "$TOOLKIT_OPS_RESULTS" | tr -d ' ') results)"
}

run infra check-infra.sh
expect "$WORK/infra.tsv" infra cluster-admin PASS
expect "$WORK/infra.tsv" infra ocp-version PASS
expect "$WORK/infra.tsv" infra capacity PASS
expect "$WORK/infra.tsv" infra gpu-allocatable PASS
expect "$WORK/infra.tsv" infra gpu-taint PASS
expect "$WORK/infra.tsv" infra default-storageclass PASS
expect "$WORK/infra.tsv" infra ocp-mcp-lco INFO
expect "$WORK/infra.tsv" infra user-workload-monitoring PASS

expect "$WORK/infra.tsv" infra nodes-ready FAIL
expect "$WORK/infra.tsv" infra gpu-contention WARN
expect "$WORK/infra.tsv" infra stale-pods WARN
grep -q 'GPUs held by: financial-loan-demo/model-training-0' "$WORK/infra.tsv" && pass=$((pass+1)) || { fail=$((fail+1)); echo "  FAIL: GPU holder not named"; }
grep -q 'cloud instances are STOPPED: gpu-1' "$WORK/infra.tsv" && pass=$((pass+1)) || { fail=$((fail+1)); echo "  FAIL: stopped-instance cause not named"; }

run platform check-platform.sh
expect "$WORK/platform.tsv" operators rhods-operator PASS
expect "$WORK/platform.tsv" operators rhcl-version PASS
expect "$WORK/platform.tsv" operators jobset-operator SKIP
expect "$WORK/platform.tsv" platform dsc-phase PASS
expect "$WORK/platform.tsv" dsc ogx FAIL
expect "$WORK/platform.tsv" dsc dashboard PASS
expect "$WORK/platform.tsv" dsc kueue INFO
expect "$WORK/platform.tsv" dsc mcplifecycleoperator-ocp FAIL
expect "$WORK/platform.tsv" dashboard flag-agentsCatalog WARN
expect "$WORK/platform.tsv" dashboard flags PASS
expect "$WORK/platform.tsv" hwprofile gpu-tolerations FAIL
expect "$WORK/platform.tsv" storage s3-backend PASS
expect "$WORK/platform.tsv" hwprofile kueue-namespaces INFO
expect "$WORK/platform.tsv" pods redhat-ods-applications PASS
expect "$WORK/platform.tsv" pods redhat-ods-applications-restarts WARN
expect "$WORK/platform.tsv" gateway gateways PASS

run maas check-maas.sh --no-diagnose
expect "$WORK/maas.tsv" maas enabled PASS
expect "$WORK/maas.tsv" maas AIGatewayReady PASS
expect "$WORK/maas.tsv" maas maas-api PASS
expect "$WORK/maas.tsv" maas db-config PASS
expect "$WORK/maas.tsv" maas tenant PASS
expect "$WORK/maas.tsv" maas gateway PASS
expect "$WORK/maas.tsv" maas models PASS

# Variant: the MaaS model is stopped on purpose -> its not-Ready MaaSModelRef is WARN, not FAIL
python3 -I - "$WORK/fixture.json" "$WORK/fixture-stopped.json" <<'PY'
import json, sys
f = json.load(open(sys.argv[1]))
for r in f["resources"]:
    if r["metadata"].get("name") == "simulator" and r["kind"] in ("MaaSModelRef", "LLMInferenceService"):
        r["status"]["conditions"] = [{"type": "Ready", "status": "False", "reason": "Stopped"}]
        r.setdefault("spec", {})
        if r["kind"] == "MaaSModelRef":
            r["spec"]["modelRef"] = {"kind": "LLMInferenceService", "name": "simulator"}
        else:
            r["metadata"].setdefault("annotations", {})["serving.kserve.io/stop"] = "true"
json.dump(f, open(sys.argv[2], "w"))
PY
MOCK_OC_FIXTURE="$WORK/fixture-stopped.json" run maas-stopped check-maas.sh --no-diagnose
expect "$WORK/maas-stopped.tsv" maas models WARN

run serving check-serving.sh --probe
expect "$WORK/serving.tsv" serving "llmisvc:maas-models/simulator" PASS
expect "$WORK/serving.tsv" serving "llmisvc:maas-models/simulator-probe" PASS
expect "$WORK/serving.tsv" serving "isvc:maas-models/bge-m3" INFO

run demos check-demos.sh
expect "$WORK/demos.tsv" demo:open-webui-demo deploy:open-webui PASS
expect "$WORK/demos.tsv" demo:open-webui-demo route:open-webui PASS
expect "$WORK/demos.tsv" demo:open-webui-demo probe:open-webui PASS
expect "$WORK/demos.tsv" demo:nemo-guardrails-demo probe:nemo-quickstart PASS
expect "$WORK/demos.tsv" demo:lemonade-stand-demo probe:lemonade-stand FAIL
grep -q 'chat error: Backend error (401)' "$WORK/demos.tsv" && pass=$((pass+1)) || { fail=$((fail+1)); echo "  FAIL: lemonade 401 not reported"; }
expect "$WORK/demos.tsv" demo:n8n-demo deployed SKIP
grep -q 'pipelines-definition .status.conditions\[?(@.type=="Ready")\].status=False (want True)' "$WORK/demos.tsv" && pass=$((pass+1)) || { fail=$((fail+1)); echo "  FAIL: DSPA jsonpath condition not parsed"; }
expect "$WORK/demos.tsv" demo:maas-ratelimit-demo notebook:rate-limit-testing PASS

run demos-explicit check-demos.sh --demo n8n-demo
expect "$WORK/demos-explicit.tsv" demo:n8n-demo deploy:n8n FAIL

run notebooks check-notebooks.sh --demo maas-ratelimit-demo
expect "$WORK/notebooks.tsv" nb:maas-ratelimit-demo wb:rate-limit-testing PASS
expect "$WORK/notebooks.tsv" nb:maas-ratelimit-demo wb:rate-limit-testing-image WARN
expect "$WORK/notebooks.tsv" nb:maas-ratelimit-demo wb:rate-limit-testing-env-drift FAIL
expect "$WORK/notebooks.tsv" nb:maas-ratelimit-demo maas-ratelimit-test-env FAIL
expect "$WORK/notebooks.tsv" nb:maas-ratelimit-demo url:MAAS_ENDPOINT PASS
expect "$WORK/notebooks.tsv" nb:maas-ratelimit-demo maas-ratelimit-test-exec INFO
expect "$WORK/notebooks.tsv" nb:maas-ratelimit-demo maas-traffic-generator-exec INFO

run notebooks-exec check-notebooks.sh --demo feast-demo,maas-ratelimit-demo --execute
expect "$WORK/notebooks-exec.tsv" nb:feast-demo feast-online-retrieval-exec PASS
expect "$WORK/notebooks-exec.tsv" nb:feast-demo wb:feature-store-env-drift PASS
expect "$WORK/notebooks-exec.tsv" nb:maas-ratelimit-demo maas-ratelimit-test-exec INFO
run demos-feast check-demos.sh --demo feast-demo
expect "$WORK/demos-feast.tsv" demo:feast-demo "field:featurestore/banking" PASS
expect "$WORK/demos-feast.tsv" demo:feast-demo "field:namespace/feast-demo" PASS

run json check-infra.sh --json
jq -e '.totals.PASS > 0 and (.results | length) > 5' "$WORK/json.out" >/dev/null && pass=$((pass+1)) || { fail=$((fail+1)); echo "  FAIL: --json output not valid"; }

# End to end: run-all with report
export TOOLKIT_OPS_RESULTS="$WORK/all.tsv"; : > "$TOOLKIT_OPS_RESULTS"
bash "$C/run-all.sh" --quiet --report "$WORK/report.md" > "$WORK/all.out" 2>&1
if grep -q '^| FAIL | dsc | mcplifecycleoperator-ocp' "$WORK/report.md" && [ "$(awk -F'\t' '$1=="infra"' "$WORK/all.tsv" | wc -l)" -gt 5 ] \
   && awk -F'\t' '$1 ~ /^nb:/' "$WORK/all.tsv" | grep -q .; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: run-all report/phases incomplete"; fi
echo "run-all: $(wc -l < "$WORK/all.tsv" | tr -d ' ') results, report $(wc -l < "$WORK/report.md" | tr -d ' ') lines"

# Unreachable cluster: stops after first phase with a clear FAIL
export TOOLKIT_OPS_RESULTS="$WORK/down.tsv"; : > "$TOOLKIT_OPS_RESULTS"
MOCK_OC_UNREACHABLE=1 bash "$C/run-all.sh" --quiet > "$WORK/down.out" 2>&1
if [ "$(awk -F'\t' '$2=="cluster-reachable" && $3=="FAIL"' "$WORK/down.tsv" | wc -l | tr -d ' ')" = "1" ] && ! awk -F'\t' '$1=="operators"' "$WORK/down.tsv" | grep -q .; then
    pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: unreachable cluster not handled (see $WORK/down.tsv)"; fi

# Safety: no mutating oc verbs were attempted by any check
if grep -E '^(apply|create|delete|patch|label|annotate|scale|rollout|set|adm|replace|edit) ' "$WORK/oc.log"; then
    fail=$((fail+1)); echo "  FAIL: mutating oc command attempted (see above)"
else
    pass=$((pass+1))
fi

echo ""
echo "Assertions: $pass passed, $fail failed   (work dir: $WORK)"
[ "$fail" -eq 0 ]
