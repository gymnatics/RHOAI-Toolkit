# Korean MCQ EvalHub provider (vendored)

`provider.yaml` is copied from [hyogrin/rhoai-lmeval-builder-lab](https://github.com/hyogrin/rhoai-lmeval-builder-lab)
(`adapters/korean-mcq/provider.yaml`, MIT License) so that `notebooks/korean-mcq-benchmark.ipynb` can register the
provider from inside the workbench (it reads `../adapters/korean-mcq/provider.yaml`).

The provider runs the adapter image
`image-registry.openshift-image-registry.svc:5000/<namespace>/korean-mcq-adapter:latest`, which
`demo/lmeval-demo/deploy.sh` builds in-cluster from the upstream repo's `adapters/korean-mcq/` directory.
