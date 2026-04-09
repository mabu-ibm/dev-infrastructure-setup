#!/bin/bash
#
# Install IBM Winning Products AI
#
# This script installs IBM Winning Products AI which provides
# enhanced AI capabilities for Concert integration and Bob AI.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      IBM Winning Products AI Installation                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}⚠️  Warning: Running as root. Consider running as regular user.${NC}"
fi

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ Error: curl is not installed${NC}"
    echo -e "${YELLOW}   Install with: sudo apt-get install curl (Ubuntu/Debian)${NC}"
    echo -e "${YELLOW}   Install with: sudo dnf install curl (AlmaLinux/RHEL)${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ curl installed${NC}"

# Check bash
if [ -z "$BASH_VERSION" ]; then
    echo -e "${RED}❌ Error: This script requires bash${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ bash available${NC}"

# Check internet connectivity
if ! curl -s --head --request GET https://w3.ibm.com > /dev/null; then
    echo -e "${RED}❌ Error: Cannot reach w3.ibm.com${NC}"
    echo -e "${YELLOW}   Check your internet connection and IBM network access${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ IBM network accessible${NC}"

echo ""
echo -e "${BLUE}📦 Installing IBM Winning Products AI...${NC}"
echo ""

# Download and execute installation script
curl -fsSL https://w3.ibm.com/software/winning-products-ai/install.sh | bash

# Check installation result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      IBM Winning Products AI Installed Successfully       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}🎉 Installation Complete!${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  1. Configure IBM Winning Products AI credentials"
    echo -e "  2. Integrate with Concert API"
    echo -e "  3. Test Bob AI enhanced capabilities"
    echo -e "  4. Run automated vulnerability remediation"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo -e "  - Concert Integration: ${GREEN}docs/CONCERT_BOB_AUTOMATION.md${NC}"
    echo -e "  - Architecture: ${GREEN}docs/ARCHITECTURE.md${NC}"
    echo -e "  - SBOM Guide: ${GREEN}docs/SBOM_GENERATION_GUIDE.md${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║      Installation Failed                                   ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}❌ Installation failed. Please check the error messages above.${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  1. Verify IBM network access"
    echo -e "  2. Check system requirements"
    echo -e "  3. Review installation logs"
    echo -e "  4. Contact IBM support if needed"
    echo ""
    exit 1
fi

exit 0

# Made with Bob
