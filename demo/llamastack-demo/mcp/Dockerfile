# Weather Data MCP Server
# A generic Model Context Protocol server for weather data

FROM registry.redhat.io/ubi9/python-312:latest

WORKDIR /app

# Install dependencies
COPY pyproject.toml .
RUN pip install --no-cache-dir mcp motor uvicorn

# Copy application
COPY http_app.py .

# Environment variables (override these in your deployment)
ENV MCP_SERVER_NAME="weather-data" \
    MONGODB_URL="mongodb://localhost:27017" \
    DATABASE_NAME="weather" \
    COLLECTION_NAME="observations"

# Expose MCP server port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the server
CMD ["python", "http_app.py"]
