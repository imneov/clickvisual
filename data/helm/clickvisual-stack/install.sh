#!/bin/bash
# ClickVisual Stack Installation Script
# Quick installation script for ClickVisual complete stack

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="clickvisual"
RELEASE_NAME="clickvisual-stack"
CHART_PATH="."
VALUES_FILE=""
WAIT_TIMEOUT="10m"

# Usage
usage() {
    cat <<EOF
ClickVisual Stack Installation Script

Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAMESPACE       Kubernetes namespace (default: clickvisual)
    -r, --release RELEASE           Helm release name (default: clickvisual-stack)
    -f, --values FILE               Custom values file
    -m, --mode MODE                 Deployment mode: minimal|production|external (default: full)
    -w, --wait TIMEOUT              Wait timeout (default: 10m)
    -h, --help                      Show this help message

Examples:
    # Full deployment with defaults
    $0

    # Minimal deployment
    $0 --mode minimal

    # Production deployment with custom namespace
    $0 --namespace production --mode production

    # Use external services
    $0 --mode external --values my-external-config.yaml

    # Custom values file
    $0 --values my-values.yaml

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Banner
echo -e "${GREEN}"
cat <<'EOF'
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║       ClickVisual Stack Installer                    ║
║       Complete Log Analytics Platform                ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm not found. Please install helm 3.0+.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)${NC}"
echo -e "${GREEN}✓ helm found: $(helm version --short)${NC}"

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
echo ""

# Select values file based on mode
if [ -n "$MODE" ]; then
    case $MODE in
        minimal)
            VALUES_FILE="examples/minimal-values.yaml"
            echo -e "${YELLOW}Using minimal configuration${NC}"
            ;;
        production)
            VALUES_FILE="examples/production-values.yaml"
            echo -e "${YELLOW}Using production configuration${NC}"
            echo -e "${RED}⚠️  Remember to update passwords and secrets!${NC}"
            ;;
        external)
            if [ -z "$VALUES_FILE" ]; then
                VALUES_FILE="examples/external-services-values.yaml"
            fi
            echo -e "${YELLOW}Using external services configuration${NC}"
            ;;
        *)
            echo -e "${RED}Unknown mode: $MODE${NC}"
            echo "Available modes: minimal, production, external"
            exit 1
            ;;
    esac
fi

# Display configuration
echo -e "${GREEN}Installation Configuration:${NC}"
echo "  Namespace:     $NAMESPACE"
echo "  Release:       $RELEASE_NAME"
echo "  Chart Path:    $CHART_PATH"
echo "  Values File:   ${VALUES_FILE:-default values.yaml}"
echo "  Wait Timeout:  $WAIT_TIMEOUT"
echo ""

# Confirm installation
read -p "Proceed with installation? (yes/no): " -n 3 -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

# Create namespace if it doesn't exist
echo -e "${YELLOW}Creating namespace if not exists...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace ready${NC}"
echo ""

# Install with Helm
echo -e "${YELLOW}Installing ClickVisual Stack...${NC}"
echo ""

HELM_CMD="helm install $RELEASE_NAME $CHART_PATH --namespace $NAMESPACE --wait --timeout $WAIT_TIMEOUT"

if [ -n "$VALUES_FILE" ]; then
    HELM_CMD="$HELM_CMD -f $VALUES_FILE"
fi

echo "Running: $HELM_CMD"
echo ""

if $HELM_CMD; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                       ║${NC}"
    echo -e "${GREEN}║   ✓ ClickVisual Stack installed successfully!        ║${NC}"
    echo -e "${GREEN}║                                                       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show access information
    echo -e "${YELLOW}Access ClickVisual:${NC}"
    echo ""
    echo "  1. Port forward:"
    echo -e "     ${GREEN}kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-clickvisual 19001:19001${NC}"
    echo ""
    echo "  2. Open browser:"
    echo -e "     ${GREEN}http://localhost:19001${NC}"
    echo ""
    echo "  3. Login with default credentials:"
    echo "     Username: clickvisual"
    echo "     Password: clickvisual"
    echo ""
    echo -e "${RED}⚠️  Important: Change default password in production!${NC}"
    echo ""

    # Show useful commands
    echo -e "${YELLOW}Useful commands:${NC}"
    echo ""
    echo "  Check status:"
    echo "    kubectl get pods -n $NAMESPACE"
    echo ""
    echo "  View logs:"
    echo "    kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME-clickvisual"
    echo ""
    echo "  Uninstall:"
    echo "    helm uninstall $RELEASE_NAME -n $NAMESPACE"
    echo ""

else
    echo ""
    echo -e "${RED}Installation failed!${NC}"
    echo ""
    echo "To debug:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl describe pod <pod-name> -n $NAMESPACE"
    echo "  kubectl logs <pod-name> -n $NAMESPACE"
    echo ""
    exit 1
fi
