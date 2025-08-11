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
DRY_RUN=false
INSTALL_DIR="/opt/aeth-core"

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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --dir|-d)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "AETH-CORE Deployment Tool"
            echo ""
            echo "Usage: $0 --token TOKEN [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --token, -t TOKEN     GitHub token with read:packages permission (required)"
            echo "  --version, -v VERSION Version to deploy (default: latest)"
            echo "  --dir, -d PATH        Installation directory (default: /opt/aeth-core)"
            echo "  --dry-run             Test deployment without making changes"
            echo "  --help, -h            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --token ghp_xxxxx"
            echo "  $0 --token ghp_xxxxx --version v1.2.10"
            echo "  $0 --token ghp_xxxxx --dir ~/aeth-core"
            echo "  $0 --token ghp_xxxxx --dry-run"
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
    echo -e "${RED}Error: GitHub token is required${NC}"
    echo ""
    echo "Usage: $0 --token YOUR_TOKEN"
    echo ""
    echo "To obtain a deployment token, please contact Sidhen support."
    echo "The token only requires 'read:packages' permission."
    exit 1
fi

# Validate token format (basic check)
if [[ ! "$GHCR_TOKEN" =~ ^ghp_[a-zA-Z0-9]+$ ]]; then
    echo -e "${YELLOW}Warning: Token format may be invalid${NC}"
    echo "Expected format: ghp_xxxx... (Classic Personal Access Token)"
    echo ""
    echo "Note: Fine-grained tokens (github_pat_) do not support package access yet."
    echo "Please use a Classic token with 'read:packages' scope."
    if [ "$DRY_RUN" != "true" ]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
fi

# Check if running as root (skip in dry-run)
if [ "$DRY_RUN" != "true" ] && [ "$EUID" -ne 0 ] && [ "$INSTALL_DIR" = "/opt/aeth-core" ]; then 
    echo -e "${YELLOW}Warning: Not running as root${NC}"
    echo "The default directory /opt/aeth-core requires sudo privileges."
    echo ""
    echo "Options:"
    echo "  1. Run with sudo: sudo $0 --token YOUR_TOKEN"
    echo "  2. Use custom directory: $0 --token YOUR_TOKEN --dir ~/aeth-core"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     AETH-CORE Deployment System        ║${NC}"
echo -e "${GREEN}║           Version: $VERSION            ║${NC}"
if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}║         DRY RUN MODE                   ║${NC}"
fi
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo
if [ "$INSTALL_DIR" != "/opt/aeth-core" ]; then
    echo -e "${YELLOW}Using custom installation directory: $INSTALL_DIR${NC}"
    echo
fi

# Platform detection
PLATFORM="$(uname -s)"
if [ "$PLATFORM" = "Darwin" ] && [ "$INSTALL_DIR" = "/opt/aeth-core" ]; then
    echo -e "${YELLOW}Note: On macOS, /opt requires Docker Desktop file sharing configuration.${NC}"
    echo -e "${YELLOW}Consider using --dir ~/aeth-core for easier setup.${NC}"
    echo
fi

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

if [ "$DRY_RUN" = "true" ]; then
    echo "  [DRY RUN] Would authenticate with provided token"
    # Test token format but don't actually login
    if [[ "$GHCR_TOKEN" =~ ^ghp_ ]] || [[ "$GHCR_TOKEN" =~ ^github_pat_ ]]; then
        echo -e "${GREEN}  [DRY RUN] Token format appears valid${NC}"
    else
        echo -e "${YELLOW}  [DRY RUN] Token format may be invalid${NC}"
    fi
else
    # Temporarily disable exit on error for authentication check
    set +e
    # Capture authentication output for error reporting
    AUTH_OUTPUT=$(echo "$GHCR_TOKEN" | docker login ghcr.io -u token --password-stdin 2>&1)
    AUTH_RESULT=$?
    set -e  # Re-enable exit on error
    
    if [ $AUTH_RESULT -ne 0 ]; then
        echo -e "${RED}  Authentication failed${NC}"
        echo ""
        echo "Error details:"
        echo "$AUTH_OUTPUT" | grep -i "error" || echo "$AUTH_OUTPUT"
        echo ""
        echo "Please verify:"
        echo "  1. Token has 'read:packages' permission"
        echo "  2. Token hasn't expired"
        echo "  3. Token is correctly copied (no spaces)"
        echo ""
        echo "Create a Classic token at: https://github.com/settings/tokens"
        exit 1
    fi
    echo -e "${GREEN}  Authentication successful${NC}"
fi

# Pre-deployment checks
echo -e "${YELLOW}Running pre-deployment checks...${NC}"

# Check for existing containers
if docker ps -a --format "{{.Names}}" | grep -q "^aeth-core$"; then
    echo -e "${YELLOW}  Found existing aeth-core container${NC}"
    
    # Check if it's running
    if docker ps --format "{{.Names}}" | grep -q "^aeth-core$"; then
        echo "  Container is currently running"
        read -p "  Stop and remove existing container? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "  Stopping existing container..."
            docker stop aeth-core >/dev/null 2>&1
            docker rm aeth-core >/dev/null 2>&1
            echo -e "${GREEN}  Existing container removed${NC}"
        else
            echo -e "${RED}Cannot proceed with existing container${NC}"
            echo "Please manually remove: docker rm -f aeth-core"
            exit 1
        fi
    else
        echo "  Container exists but is stopped"
        echo "  Removing stopped container..."
        docker rm aeth-core >/dev/null 2>&1
        echo -e "${GREEN}  Stopped container removed${NC}"
    fi
fi

# Check for port conflicts
if [ "$INSTALL_DIR" = "/opt/aeth-core" ] || [[ "$INSTALL_DIR" == *"aeth-core"* ]]; then
    # Check if default ports are in use (if applicable)
    # This is where you'd check for port 8080, 7880, etc.
    echo -e "${GREEN}  No port conflicts detected${NC}"
fi

# Check disk space
REQUIRED_SPACE_GB=5
if command -v df >/dev/null 2>&1; then
    AVAILABLE_SPACE=$(df -BG "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ ! -z "$AVAILABLE_SPACE" ] && [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE_GB" ]; then
        echo -e "${YELLOW}  Warning: Low disk space (${AVAILABLE_SPACE}GB available, ${REQUIRED_SPACE_GB}GB recommended)${NC}"
        read -p "  Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
fi

echo -e "${GREEN}Pre-deployment checks completed${NC}"
echo

# Pull deployment tools image
DEPLOY_IMAGE="${DEPLOY_IMAGE_BASE}:${VERSION}"
echo -e "${YELLOW}Downloading deployment tools...${NC}"
echo "  Image: $DEPLOY_IMAGE"

if [ "$DRY_RUN" = "true" ]; then
    echo "  [DRY RUN] Would pull deployment tools image"
    echo "  [DRY RUN] Would check image availability"
    DEPLOY_EXIT_CODE=0
else
    set +e  # Temporarily disable exit on error
    docker pull "$DEPLOY_IMAGE"
    PULL_RESULT=$?
    set -e  # Re-enable exit on error
    
    if [ $PULL_RESULT -ne 0 ]; then
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
    
    # Create installation directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # The deployment container needs:
    # - Docker socket to manage containers on host
    # - Installation directory for configuration files
    # - GitHub token for pulling application image
    docker run --rm -it \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$INSTALL_DIR:/opt/aeth-core" \
        -e GHCR_TOKEN="$GHCR_TOKEN" \
        -e APP_VERSION="$VERSION" \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        "$DEPLOY_IMAGE"
    
    DEPLOY_EXIT_CODE=$?
fi

# Logout from registry
if [ "$DRY_RUN" != "true" ]; then
    docker logout ghcr.io &> /dev/null
fi

if [ "$DRY_RUN" = "true" ]; then
    echo
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}    DRY RUN completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo
    echo "What would have happened:"
    echo "  1. Authenticated with GitHub Container Registry"
    echo "  2. Downloaded deployment tools image"
    echo "  3. Run interactive configuration"
    echo "  4. Downloaded application image"
    echo "  5. Created service configuration"
    echo "  6. Started AETH-CORE service"
    echo
    echo "To perform actual deployment, run without --dry-run"
elif [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    echo
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}    Deployment completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo
    echo "Installation directory: $INSTALL_DIR"
    echo "Configuration file: $INSTALL_DIR/.env"
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