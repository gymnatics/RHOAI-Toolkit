# Attribution

The notebooks in this directory are adapted from:

- **Repository:** [hyogrin/rhoai-lmeval-builder-lab](https://github.com/hyogrin/rhoai-lmeval-builder-lab)
- **Author:** [hyogrin](https://github.com/hyogrin)
- **License:** See the original repository for license terms

## Changes from Original

- Default namespace changed from `hyo-project` to `lmeval-demo`
- EvalHub URL defaults updated to match this toolkit's deployment
- Added auto-detection of model endpoints via `oc` CLI
- Execution outputs stripped (contained prior cluster-specific data)
- Korean adapter and report generator files remain in the upstream repo

## Original Notebooks

| Vendored Notebook | Original |
|---|---|
| `guidellm-benchmark.ipynb` | [1_eval_hub_guidellm_benchmark/1_guidellm_benchmark.ipynb](https://github.com/hyogrin/rhoai-lmeval-builder-lab/blob/main/1_eval_hub_guidellm_benchmark/1_guidellm_benchmark.ipynb) |
| `korean-mcq-benchmark.ipynb` | [2_eval_hub_kmcq_benchmark/1_kmcq_benchmark.ipynb](https://github.com/hyogrin/rhoai-lmeval-builder-lab/blob/main/2_eval_hub_kmcq_benchmark/1_kmcq_benchmark.ipynb) |

## Advanced Notebooks (Upstream Only)

For the full workshop experience including unified benchmarks, result summarization, and model setup, clone the original repo:

```bash
git clone https://github.com/hyogrin/rhoai-lmeval-builder-lab.git
```
