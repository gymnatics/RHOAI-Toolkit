# n8n Workflow Automation

Deploy [n8n](https://n8n.io/) on OpenShift for workflow automation.

## Deploy

```bash
./deploy.sh                    # Deploy to 'n8n' namespace
./deploy.sh -n my-namespace    # Custom namespace
./deploy.sh --delete           # Remove
```

## What's Deployed

- n8n community edition (latest)
- 5Gi PVC for SQLite data persistence
- Edge TLS Route

## After Deployment

1. Open the n8n URL (printed after deploy)
2. Create your admin account on first login
3. Connect to RHOAI model endpoints as AI nodes
