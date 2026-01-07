# Weather Data MCP Server
# A generic Model Context Protocol server for weather data

FROM registry.redhat.io/ubi9/python-312:latest

WORKDIR /app

# Install dependencies
# mcp - Model Context Protocol SDK with FastMCP
# motor - Async MongoDB driver
# uvicorn - ASGI server
RUN pip install --no-cache-dir mcp motor uvicorn

# Copy application
COPY http_app.py .

# Set to non-root user for OpenShift compatibility
USER 1001

# Environment variables (override these in your deployment)
ENV MCP_SERVER_NAME="weather-data" \
    MONGODB_URL="mongodb://localhost:27017" \
    DATABASE_NAME="weather" \
    COLLECTION_NAME="observations"

# Expose MCP server port
EXPOSE 8000

# Run the server
CMD ["python", "http_app.py"]
