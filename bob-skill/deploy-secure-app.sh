#!/bin/bash

# Bob Skill: Deploy Secure Application
# Automates: Create repo → Push code → Build → Deploy

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "Bob Skill: Deploy Secure Application"
echo -e "==========================================${NC}"
echo ""

# Configuration
GITEA_URL="${GITEA_URL:-http://almabuild:3000}"
GITEA_USER="${GITEA_USER:-}"
GITEA_TOKEN="${GITEA_TOKEN:-}"
APP_NAME="${1:-}"
APP_TYPE="${2:-python}"

# Function to show usage
show_usage() {
    echo "Usage: $0 <app-name> [app-type]"
    echo ""
    echo "Arguments:"
    echo "  app-name    Name of the application (required)"
    echo "  app-type    Type of application: python, nodejs, go (default: python)"
    echo ""
    echo "Environment Variables:"
    echo "  GITEA_URL   Gitea server URL (default: http://almabuild:3000)"
    echo "  GITEA_USER  Gitea username (required)"
    echo "  GITEA_TOKEN Gitea API token (required)"
    echo ""
    echo "Example:"
    echo "  export GITEA_USER=manfred"
    echo "  export GITEA_TOKEN=your-token-here"
    echo "  $0 my-secure-app python"
    exit 1
}

# Validate inputs
if [ -z "$APP_NAME" ]; then
    echo -e "${RED}Error: Application name is required${NC}"
    show_usage
fi

if [ -z "$GITEA_USER" ]; then
    echo -e "${RED}Error: GITEA_USER environment variable not set${NC}"
    show_usage
fi

if [ -z "$GITEA_TOKEN" ]; then
    echo -e "${RED}Error: GITEA_TOKEN environment variable not set${NC}"
    show_usage
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  Gitea URL: $GITEA_URL"
echo "  Username: $GITEA_USER"
echo "  App Name: $APP_NAME"
echo "  App Type: $APP_TYPE"
echo ""

# Step 1: Check if repository exists
echo -e "${BLUE}Step 1: Checking if repository exists...${NC}"
REPO_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $GITEA_TOKEN" \
    "$GITEA_URL/api/v1/repos/$GITEA_USER/$APP_NAME")

if [ "$REPO_EXISTS" = "200" ]; then
    echo -e "${YELLOW}Repository already exists: $GITEA_USER/$APP_NAME${NC}"
    read -p "Do you want to use existing repository? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 0
    fi
else
    echo -e "${GREEN}Creating new repository: $APP_NAME${NC}"
    
    # Create repository
    CREATE_RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$APP_NAME\",\"description\":\"Secure $APP_TYPE application\",\"private\":false,\"auto_init\":false}" \
        "$GITEA_URL/api/v1/user/repos")
    
    if echo "$CREATE_RESPONSE" | grep -q "\"name\":\"$APP_NAME\""; then
        echo -e "${GREEN}✓ Repository created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create repository${NC}"
        echo "$CREATE_RESPONSE"
        exit 1
    fi
fi

# Step 2: Create application from template
echo ""
echo -e "${BLUE}Step 2: Creating application from template...${NC}"

WORK_DIR="/tmp/bob-deploy-$APP_NAME-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Copy template based on app type
TEMPLATE_DIR="$HOME/dev-infrastructure-setup/project-templates/hello-world-$APP_TYPE"

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo -e "${RED}✗ Template not found: $TEMPLATE_DIR${NC}"
    echo "Available templates:"
    ls -1 "$HOME/dev-infrastructure-setup/project-templates/" | grep "hello-world-"
    exit 1
fi

echo "Copying template from: $TEMPLATE_DIR"
cp -r "$TEMPLATE_DIR"/* .
cp -r "$TEMPLATE_DIR"/.gitea .

# Customize application
echo "Customizing application..."
if [ -f "app.py" ]; then
    sed -i.bak "s/Hello World from Python Flask!/$APP_NAME - Secure Application/g" app.py
    rm -f app.py.bak
fi

# Update deployment manifests
if [ -f "k8s/deployment-secure.yaml" ]; then
    sed -i.bak "s/hello-world-python/$APP_NAME/g" k8s/deployment-secure.yaml
    sed -i.bak "s/hello-world-python/$APP_NAME/g" k8s/network-policy.yaml
    rm -f k8s/*.bak
fi

echo -e "${GREEN}✓ Application created${NC}"

# Step 3: Initialize git and push
echo ""
echo -e "${BLUE}Step 3: Initializing git repository...${NC}"

git init
git branch -M main
git add .
git commit -m "Initial commit: Secure $APP_TYPE application created by Bob"

# Add remote
REPO_URL="$GITEA_URL/$GITEA_USER/$APP_NAME.git"
git remote add origin "$REPO_URL"

echo "Pushing to: $REPO_URL"
git push -u origin main

echo -e "${GREEN}✓ Code pushed to Gitea${NC}"

# Step 4: Configure Gitea secrets
echo ""
echo -e "${BLUE}Step 4: Configuring Gitea secrets...${NC}"

# Check if secrets exist
echo "Checking for required secrets..."

# REGISTRY_TOKEN
REGISTRY_TOKEN_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $GITEA_TOKEN" \
    "$GITEA_URL/api/v1/repos/$GITEA_USER/$APP_NAME/actions/secrets/REGISTRY_TOKEN")

if [ "$REGISTRY_TOKEN_EXISTS" != "200" ]; then
    echo -e "${YELLOW}⚠ REGISTRY_TOKEN secret not found${NC}"
    echo "Please create it manually in Gitea:"
    echo "  1. Go to: $GITEA_URL/$GITEA_USER/$APP_NAME/settings/actions/secrets"
    echo "  2. Add secret: REGISTRY_TOKEN"
    echo "  3. Value: Your Gitea Personal Access Token"
fi

# KUBECONFIG
KUBECONFIG_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $GITEA_TOKEN" \
    "$GITEA_URL/api/v1/repos/$GITEA_USER/$APP_NAME/actions/secrets/KUBECONFIG")

if [ "$KUBECONFIG_EXISTS" != "200" ]; then
    echo -e "${YELLOW}⚠ KUBECONFIG secret not found${NC}"
    echo "Please create it manually in Gitea:"
    echo "  1. Go to: $GITEA_URL/$GITEA_USER/$APP_NAME/settings/actions/secrets"
    echo "  2. Add secret: KUBECONFIG"
    echo "  3. Value: Base64-encoded kubeconfig"
    echo ""
    echo "To get base64-encoded kubeconfig:"
    echo "  cat ~/.kube/config | base64 -w 0"
fi

# Step 5: Trigger workflow
echo ""
echo -e "${BLUE}Step 5: Triggering CI/CD pipeline...${NC}"

# Make a small change to trigger workflow
echo "# Deployed by Bob at $(date)" >> README.md
git add README.md
git commit -m "Trigger CI/CD pipeline"
git push

echo -e "${GREEN}✓ Pipeline triggered${NC}"

# Step 6: Monitor workflow
echo ""
echo -e "${BLUE}Step 6: Monitoring workflow...${NC}"
echo ""
echo "Watch the pipeline at:"
echo "  $GITEA_URL/$GITEA_USER/$APP_NAME/actions"
echo ""
echo "The pipeline will:"
echo "  1. Test the application"
echo "  2. Build secure Docker image"
echo "  3. Scan for vulnerabilities (optional)"
echo "  4. Deploy to K3s with security"
echo "  5. Verify security configuration"
echo ""

# Cleanup
cd /
rm -rf "$WORK_DIR"

# Summary
echo -e "${GREEN}=========================================="
echo "Deployment Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Repository: $GITEA_URL/$GITEA_USER/$APP_NAME"
echo "Actions: $GITEA_URL/$GITEA_USER/$APP_NAME/actions"
echo ""
echo "Next steps:"
echo "  1. Watch the pipeline in Gitea Actions"
echo "  2. Wait for deployment to complete (~3-5 minutes)"
echo "  3. Check application: kubectl get pods -l app=$APP_NAME"
echo "  4. Access application: kubectl port-forward service/$APP_NAME 8080:80"
echo ""
echo -e "${GREEN}Your secure application is being deployed!${NC} 🚀"

# Made with Bob
