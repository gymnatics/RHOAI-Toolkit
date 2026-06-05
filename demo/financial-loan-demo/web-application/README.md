# Loan Default Prediction Web Application

AI-powered loan approval system for financial advisors. Uses XGBoost for predictions and Qwen3-4B LLM for explanations.

## Quick Start (Local)

```bash
docker-compose up --build -d
```

Open http://localhost:8080

## Deploy to OpenShift

```bash
# Apply resources
oc apply -f deployment.yaml

# Build and deploy
oc start-build microloan-webapp --from-dir=. -n microloan-web-app

# Restart deployment
oc rollout restart deployment/microloan-webapp -n microloan-web-app

# Get URL
oc get route microloan-webapp -n microloan-web-app
```

## Project Structure

```
web-application/
├── backend/app.py          # Flask API
├── static/                 # CSS, JS, images
├── index.html              # Main UI
├── Dockerfile              # Container config
├── docker-compose.yml      # Local development
└── deployment.yaml         # OpenShift deployment
```

## Configuration

API endpoints are configured via environment variables in `deployment.yaml` (OpenShift) or `.env` (local).
