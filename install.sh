#!/bin/bash
# AETH-CORE Deployment Bootstrap
# This script downloads and runs the deployment tools
# Usage: ./install.sh --token YOUR_TOKEN [--version VERSION]

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
            echo "AETH-CORE Deployment Tool"
            echo ""
            echo "Usage: $0 --token TOKEN [--version VERSION]"
            echo ""
            echo "Options:"
            echo "  --token, -t TOKEN     GitHub token with read:packages permission (required)"
            echo "  --version, -v VERSION Version to deploy (default: latest)"
            echo "  --help, -h            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --token ghp_xxxxx"
            echo "  $0 --token ghp_xxxxx --version v1.2.10"
            echo ""
            echo "For deployment tokens, contact Sidhen support."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate token
if [ -z "$GHCR_TOKEN" ]; then
    echo -e "${RED}Error: Deployment token is required${NC}"
    echo ""
    echo "Usage: $0 --token YOUR_TOKEN"
    echo ""
    echo "To obtain a deployment token, please contact Sidhen support."
    echo "The token only requires 'read:packages' permission."
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Warning: Not running as root${NC}"
    echo "Some operations may require sudo privileges."
    echo "Recommended: sudo $0 --token YOUR_TOKEN"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     AETH-CORE Deployment System        ║${NC}"
echo -e "${GREEN}║           Version: $VERSION${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo

# Check Docker installation
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed${NC}"
    echo "Please install Docker first:"
    echo "  Ubuntu/Debian: sudo apt-get install docker.io docker-compose"
    echo "  CentOS/RHEL:   sudo yum install docker docker-compose"
    echo "  macOS:         Download Docker Desktop from docker.com"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker daemon is not running${NC}"
    echo "Please start Docker service:"
    echo "  Linux: sudo systemctl start docker"
    echo "  macOS: Start Docker Desktop application"
    exit 1
fi

# Login to GitHub Container Registry
echo -e "${YELLOW}Authenticating with GitHub Container Registry...${NC}"
echo "$GHCR_TOKEN" | docker login ghcr.io -u token --password-stdin &> /dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Authentication failed${NC}"
    echo "Please verify your token has 'read:packages' permission."
    echo "You can create a fine-grained token at:"
    echo "  https://github.com/settings/tokens?type=beta"
    exit 1
fi

# Pull deployment tools image
DEPLOY_IMAGE="${DEPLOY_IMAGE_BASE}:${VERSION}"
echo -e "${YELLOW}Downloading deployment tools...${NC}"
echo "  Image: $DEPLOY_IMAGE"

docker pull "$DEPLOY_IMAGE"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download deployment tools${NC}"
    echo "Possible reasons:"
    echo "  - Invalid version: $VERSION"
    echo "  - Network connectivity issues"
    echo "  - Token permissions insufficient"
    exit 1
fi

# Run deployment container
echo -e "${GREEN}Starting deployment process...${NC}"
echo

# The deployment container needs:
# - Docker socket to manage containers on host
# - Installation directory for configuration files
# - GitHub token for pulling application image
docker run --rm -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /opt/aeth-core:/opt/aeth-core \
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
    echo -e "${GREEN}    Deployment completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo
    echo "Installation directory: /opt/aeth-core"
    echo "Configuration file: /opt/aeth-core/.env"
    echo
    echo "Useful commands:"
    echo "  View logs:    docker logs -f aeth-core"
    echo "  Stop service: docker stop aeth-core"
    echo "  Start service: docker start aeth-core"
    echo "  Update:       Run this script again with new version"
else
    echo
    echo -e "${RED}Deployment failed with exit code: $DEPLOY_EXIT_CODE${NC}"
    echo "Please check the error messages above."
    exit $DEPLOY_EXIT_CODE
fi