# Weather Data MCP Server

A generic Model Context Protocol (MCP) server for querying weather data from MongoDB. This server demonstrates how to connect LLMs to real databases via MCP.

## Features

- ✅ **Generic Data Model** - Clean, simple weather data schema
- ✅ **Kubernetes Ready** - DNS rebinding protection disabled for K8s service names
- ✅ **Flexible Queries** - Search by station, location, temperature, conditions
- ✅ **14 Global Stations** - Sample data for airports worldwide
- ✅ **48 Hours of Data** - Realistic hourly observations

## Available Tools

| Tool | Description |
|------|-------------|
| `search_weather` | Search observations with filters (station, location, temperature, conditions) |
| `get_current_weather` | Get the latest observation for a specific station |
| `list_stations` | List all available weather stations |
| `get_statistics` | Get database statistics and coverage |
| `health_check` | Check server and database health |

## Sample Data Schema

```json
{
  "station": "VIDP",
  "station_name": "Delhi - Indira Gandhi International",
  "city": "New Delhi",
  "country": "India",
  "location": {"lat": 28.5665, "lon": 77.1031},
  "timestamp": "2024-01-01T12:00:00Z",
  "temperature": 32.5,
  "dewpoint": 18.2,
  "humidity": 45,
  "wind_speed": 8,
  "wind_direction": 270,
  "visibility": 10000,
  "pressure": 1013.2,
  "conditions": "Partly Cloudy",
  "source": "demo-data"
}
```

## Included Stations

| Code | City | Country |
|------|------|---------|
| VIDP | New Delhi | India |
| VABB | Mumbai | India |
| VOBL | Bangalore | India |
| VOMM | Chennai | India |
| VECC | Kolkata | India |
| WSSS | Singapore | Singapore |
| VHHH | Hong Kong | China |
| RJTT | Tokyo | Japan |
| EGLL | London | United Kingdom |
| LFPG | Paris | France |
| KJFK | New York | USA |
| KLAX | Los Angeles | USA |
| OMDB | Dubai | UAE |
| YSSY | Sydney | Australia |

---

## Quick Start - OpenShift Deployment

### Step 1: Login and Set Project

```bash
oc login --token=<your-token> --server=<your-cluster>
oc project demo-test  # Or create: oc new-project demo-test
```

### Step 2: Deploy MongoDB

```bash
oc apply -f mongodb-deployment.yaml

# Wait for MongoDB to be ready
oc wait --for=condition=available deployment/mongodb --timeout=120s
```

### Step 3: Initialize Sample Data

```bash
oc apply -f init-data-job.yaml

# Watch the job
oc logs -f job/init-weather-data

# Verify data was inserted
oc exec deployment/mongodb -- mongosh weather --eval "db.observations.countDocuments()"
```

### Step 4: Build and Deploy MCP Server

```bash
# Create build resources
oc apply -f buildconfig.yaml

# Build from local directory
oc start-build weather-mcp-server --from-dir=. --follow

# Deploy
oc apply -f deployment.yaml

# Wait for deployment
oc wait --for=condition=available deployment/weather-mcp-server --timeout=120s
```

### Step 5: Register with LlamaStack

Edit your LlamaStack ConfigMap to add the MCP toolgroup:

```bash
# Find which ConfigMap LlamaStack uses
oc get deployment <your-llamastack> -o yaml | grep -A5 "volumes:"

# Edit the ConfigMap
oc edit configmap llama-stack-config
```

Add under `tool_groups:`:
```yaml
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://weather-mcp-server:8000/mcp
```

Restart LlamaStack:
```bash
oc delete pod -l app=llama-stack
```

### Step 6: Verify

```bash
# Check MCP server logs
oc logs deployment/weather-mcp-server

# Test tools endpoint
oc exec deployment/weather-mcp-server -- curl -s http://localhost:8000/mcp \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# Check LlamaStack tools
curl -s http://<llamastack-route>/v1/tools | jq '.data[].name'
```

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_SERVER_NAME` | `weather-data` | Name for the MCP server |
| `MONGODB_URL` | `mongodb://mongodb:27017` | MongoDB connection string |
| `DATABASE_NAME` | `weather` | Database name |
| `COLLECTION_NAME` | `observations` | Collection name |

---

## Local Development

```bash
# Install dependencies
pip install mcp motor uvicorn pymongo

# Start local MongoDB (Docker)
docker run -d -p 27017:27017 --name mongodb mongo:6.0

# Generate sample data
python sample_data.py --insert --mongodb-url mongodb://localhost:27017

# Run the server
python http_app.py
```

---

## Example Queries

Once connected to an LLM via LlamaStack, try asking:

- "What's the current weather in Delhi?"
- "Find all stations with temperature above 30°C"
- "Which airports have fog right now?"
- "List all available weather stations"
- "Compare the weather in London and New York"
- "Show me the weather statistics"

---

## Files

| File | Description |
|------|-------------|
| `http_app.py` | MCP server application |
| `sample_data.py` | Sample data generator (local use) |
| `Dockerfile` | Container build file |
| `deployment.yaml` | MCP server deployment + ConfigMap |
| `buildconfig.yaml` | OpenShift build configuration |
| `mongodb-deployment.yaml` | MongoDB deployment |
| `init-data-job.yaml` | Job to initialize sample data |

---

*Author: Danny Yeo*
