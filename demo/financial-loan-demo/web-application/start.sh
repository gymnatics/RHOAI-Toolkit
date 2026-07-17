#!/bin/bash

echo "=========================================="
echo "Microloan Approval System - Docker Demo"
echo "=========================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running!"
    echo ""
    echo "Please start Docker Desktop and try again."
    exit 1
fi

echo "✓ Docker is running"
echo ""
echo "Building and starting the application..."
echo ""

# Build and start
docker-compose up --build

echo ""
echo "Application stopped."
