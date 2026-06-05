# Feast Feature Store Demo

## What is a Feature Store?

A Feature Store is a central warehouse for ML-ready data. Without it, every data scientist writes their own queries to build features (e.g., "average transaction amount over 30 days"), leading to duplicated work, inconsistent calculations, and a gap between training and production.

A Feature Store solves this by providing:

- **One definition, used everywhere** -- define a feature once, reuse it across all models and teams
- **Training/serving consistency** -- the exact same feature logic used to train the model is used when making live predictions, eliminating the #1 cause of model degradation
- **Real-time + batch** -- serve features in milliseconds for live fraud detection, or in bulk for monthly model retraining
- **On-demand computation** -- calculate things like risk scores on the fly at prediction time

## This Demo

A banking feature store with customer demographics, transaction patterns, ATM usage, branch visits, and call center data. One API call retrieves 47+ features for a customer in real-time -- no SQL, no pipelines, no waiting.

### Feature Services (9 total)

| Service | Description | Use Case |
|---|---|---|
| `customer_charter_service` | Demographics, branch, call center, transactions | Customer satisfaction & churn |
| `call_prediction_service` | Demographics, behavioral, call center patterns | Predict service calls |
| `customer_behavior_service` | Spending patterns, financial needs | Customer segmentation |
| `branch_optimization_service` | Branch performance, visits, wait times | Branch operations |
| `atm_optimization_service` | ATM usage, location performance | ATM placement |
| `transaction_prediction_service` | Transaction patterns, velocity metrics | Fraud detection & AML |
| `risk_compliance_service` | Risk assessment, compliance monitoring | Regulatory compliance |
| `comprehensive_banking_service` | All 17 feature views combined | Multi-use analysis |
| `simple_ondemand_risk_service` | On-demand risk score computation | Real-time risk scoring |

### Demo Highlights

1. **Feature discovery** -- 9 feature services, 17 feature views, all self-documented
2. **Online retrieval** -- One call, 47 features, real-time
3. **On-demand risk score** -- Computed on the fly during feature retrieval, not pre-stored
4. **Dashboard** -- Visual feature catalog in RHOAI (Feature Store tab)

## Prerequisites

- Feast operator enabled (`feastoperator.managementState: Managed` in DSC)
- FeatureStore CR deployed and Ready
- Features applied (`feast apply`) and materialized (`feast materialize`)

## Quick Start

### 1. Deploy (if not already done)

```bash
# Via toolkit
./rhoai-toolkit.sh
# Navigate to: RHOAI Management > Demos > Deploy Banking Demo (Feast)

# Or manually
oc apply -f lib/manifests/feast/featurestore-banking-demo.yaml -n <namespace>
```

### 2. Run Notebooks

In the workbench, clone the repo and open the notebooks:

```bash
git clone https://github.com/gymnatics/RHOAI-Toolkit.git
```

| Notebook | Description |
|---|---|
| `feast-online-retrieval.ipynb` | Online/offline retrieval, feature services, on-demand transforms |
| `feast-banking-complex.ipynb` | Full demo with all teams, multi-entity queries, raw data exploration |

The notebooks auto-connect to Feast services on the cluster -- no manual config copying needed.

## Architecture

```
Feast Operator (RHOAI)
  └── FeatureStore CR (banking)
        ├── Registry   (feast-banking-registry)   -- feature metadata
        ├── Online Store (feast-banking-online)    -- low-latency serving
        └── Offline Store (feast-banking-offline)  -- historical retrieval (training)
```

Feature definitions are sourced from [RHRolun/banking-feature-store](https://github.com/RHRolun/banking-feature-store) (branch: `rbac`).
