#!/bin/bash
# Debug version of install script
set -x  # Enable debug output

# Configuration
DEPLOY_IMAGE_BASE="ghcr.io/sidhen-ai/aeth-core-deploy"
VERSION="latest"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get token from command line
GHCR_TOKEN="$1"

if [ -z "$GHCR_TOKEN" ]; then
    echo "Usage: $0 TOKEN"
    exit 1
fi

echo -e "${YELLOW}Testing authentication with debug output...${NC}"

# Show Docker version
echo "Docker version:"
docker --version

# Test direct login with visible output
echo "Attempting login..."
echo "$GHCR_TOKEN" | docker login ghcr.io -u token --password-stdin

LOGIN_RESULT=$?
echo "Login result code: $LOGIN_RESULT"

if [ $LOGIN_RESULT -eq 0 ]; then
    echo -e "${GREEN}Login successful!${NC}"
    
    # Try to pull image
    echo "Attempting to pull deployment image..."
    docker pull "${DEPLOY_IMAGE_BASE}:${VERSION}"
    
    PULL_RESULT=$?
    echo "Pull result code: $PULL_RESULT"
    
    # Logout
    docker logout ghcr.io
else
    echo -e "${RED}Login failed!${NC}"
fi

echo "Debug script completed"