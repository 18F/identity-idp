#!/bin/bash

# mDL POC Demo Startup Script
# Starts OpenCred and Login.gov for mDL demo

set -e

OPENCRED_DIR="$HOME/IdeaProjects/opencred-local"
IDP_DIR="$HOME/IdeaProjects/identity-idp"
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "localhost")

echo "=== mDL Demo Startup ==="
echo ""

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Start Docker Desktop first."
    exit 1
fi

# Check OpenCred directory exists
if [ ! -d "$OPENCRED_DIR" ]; then
    echo "ERROR: OpenCred directory not found at $OPENCRED_DIR"
    exit 1
fi

# Start OpenCred
echo "[1/3] Starting OpenCred..."
cd "$OPENCRED_DIR"
docker compose up -d

# Wait for OpenCred to be ready
echo "[2/3] Waiting for OpenCred to be ready..."
for i in {1..30}; do
    if curl -s "http://localhost:22080/.well-known/did.json" > /dev/null 2>&1; then
        echo "      OpenCred is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: OpenCred failed to start. Check: docker compose logs opencred"
        exit 1
    fi
    sleep 1
done

# Start Login.gov
echo "[3/3] Starting Login.gov..."
echo ""
echo "=== Ready ==="
echo ""
echo "OpenCred:  http://localhost:22080"
echo "Login.gov: http://localhost:3000"
echo "Your IP:   $LOCAL_IP (for wallet config)"
echo ""
echo "Starting Rails server..."
echo ""

cd "$IDP_DIR"
RAILS_MAX_THREADS=3 make run
