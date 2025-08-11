#!/bin/bash
# Local test version - uses home directory instead of /opt
# This is for testing on macOS without needing to configure Docker file sharing

set -e

# Configuration
DEPLOY_IMAGE_BASE="ghcr.io/sidhen-ai/aeth-core-deploy"
APP_IMAGE_BASE="ghcr.io/sidhen-ai/aeth-core"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
GHCR_TOKEN=""
VERSION="latest"

while [[ $# -gt 0 ]]; do
    case $1 in
        --token|-t)
            GHCR_TOKEN="$2"
            shift 2
            ;;
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        --help|-h)
            echo "AETH-CORE Local Test Deployment"
            echo ""
            echo "Usage: $0 --token TOKEN [--version VERSION]"
            echo ""
            echo "This version uses ~/aeth-core-test instead of /opt/aeth-core"
            echo "Perfect for testing on macOS without Docker file sharing issues"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate token
if [ -z "$GHCR_TOKEN" ]; then
    echo -e "${RED}Error: GitHub token is required${NC}"
    echo "Usage: $0 --token YOUR_TOKEN"
    exit 1
fi

# Use home directory for testing
INSTALL_DIR="$HOME/aeth-core-test"

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  AETH-CORE Local Test Deployment       ║${NC}"
echo -e "${GREEN}║  Version: $VERSION                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo
echo -e "${YELLOW}Note: Using $INSTALL_DIR for testing${NC}"
echo

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}Docker daemon is not running${NC}"
    exit 1
fi

# Login to GitHub Container Registry
echo -e "${YELLOW}Authenticating with GitHub Container Registry...${NC}"
set +e
AUTH_OUTPUT=$(echo "$GHCR_TOKEN" | docker login ghcr.io -u token --password-stdin 2>&1)
AUTH_RESULT=$?
set -e

if [ $AUTH_RESULT -ne 0 ]; then
    echo -e "${RED}  Authentication failed${NC}"
    echo ""
    echo "Error details:"
    echo "$AUTH_OUTPUT"
    exit 1
fi
echo -e "${GREEN}  Authentication successful${NC}"

# Pull deployment tools image
DEPLOY_IMAGE="${DEPLOY_IMAGE_BASE}:${VERSION}"
echo -e "${YELLOW}Downloading deployment tools...${NC}"
echo "  Image: $DEPLOY_IMAGE"

set +e
docker pull "$DEPLOY_IMAGE"
PULL_RESULT=$?
set -e

if [ $PULL_RESULT -ne 0 ]; then
    echo -e "${RED}Failed to download deployment tools${NC}"
    exit 1
fi

# Run deployment container with local directory
echo -e "${GREEN}Starting deployment process...${NC}"
echo -e "${YELLOW}Using local directory: $INSTALL_DIR${NC}"
echo

# Run with modified volume mount
docker run --rm -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$INSTALL_DIR:/opt/aeth-core" \
    -e GHCR_TOKEN="$GHCR_TOKEN" \
    -e APP_VERSION="$VERSION" \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    "$DEPLOY_IMAGE"

DEPLOY_EXIT_CODE=$?

# Logout from registry
docker logout ghcr.io &> /dev/null

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    echo
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}    Test deployment completed!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo
    echo "Installation directory: $INSTALL_DIR"
    echo "Configuration file: $INSTALL_DIR/.env"
    echo
    echo "Next steps:"
    echo "1. Review configuration: cat $INSTALL_DIR/.env"
    echo "2. Check container: docker ps | grep aeth-core"
    echo "3. View logs: docker logs -f aeth-core"
    echo
    echo "To clean up test:"
    echo "  docker stop aeth-core"
    echo "  docker rm aeth-core"
    echo "  rm -rf $INSTALL_DIR"
else
    echo
    echo -e "${RED}Deployment failed with exit code: $DEPLOY_EXIT_CODE${NC}"
    exit $DEPLOY_EXIT_CODE
fi