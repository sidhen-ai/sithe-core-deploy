# AETH-CORE Deployment Tool

Automated deployment system for AETH-CORE.

## Quick Start

```bash
# Download the installer
curl -O https://raw.githubusercontent.com/sidhen-ai/aeth-core-deploy/main/install.sh
chmod +x install.sh

# Run deployment
sudo ./install.sh --token YOUR_TOKEN
```

## Requirements

- Linux (Ubuntu 20.04+, CentOS 7+, Debian 10+) or macOS
- Docker and Docker Compose
- Deployment token (contact Sidhen support)

## Options

```bash
# Deploy latest version
./install.sh --token YOUR_TOKEN

# Deploy specific version
./install.sh --token YOUR_TOKEN --version v1.2.10

# Show help
./install.sh --help
```

## Support

For deployment tokens and support, please contact Sidhen.

## License

Copyright (c) 2025 Sidhen Limited. All rights reserved.