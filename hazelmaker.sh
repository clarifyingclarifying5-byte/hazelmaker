#!/bin/bash
set -euo pipefail
# =========================================
# 🚀 GCP-XRAY MULTI-ENGINE DEPLOYER — WS-ONLY EDITION
# ✅ ENGINES: OPENRESTY, ENVOY, HAPROXY, CADDY, SING-BOX
# ✅ INCLUDES CUSTOM USER-AGENT HEADERS
# ✅ UPDATE: Artifact Registry Support (Auto-Create Repo)
# ✅ FIXED: Qwiklabs/Skills Boost Quotas & Suspension Safety
# =========================================

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# ==============================================
# AUTO INSTALL JQ IF MISSING
# ==============================================
if ! command -v jq &> /dev/null; then
    echo -e "\n${YELLOW}⚠️ Installing required tool: jq...${NC}"
    sudo apt update -qq && sudo apt install -y -qq jq || {
        echo -e "${RED}❌ Failed to install jq!${NC}"
        exit 1
    }
    echo -e "${GREEN}✅ jq installed successfully!${NC}"
fi

# ==============================================
# SKILLS & QWIKLABS SAFE STUB (BYPASSED KERNEL MODS)
# ==============================================
sysctl_optimize() {
    echo -e "\n${CYAN}⚙️ Bypassing restricted host sysctl modifications for cloud environment stability...${NC}"
}

setup_log_cleaner() {
    echo -e "${CYAN}🧹 Skipping restricted cron setup for cloud environment stability...${NC}"
}

# ==============================================
# SUPERVISORD — Process Manager
# ==============================================
install_supervisord() {
    echo -e "${CYAN}📦 Installing Supervisord...${NC}"
    sudo apt update -qq && sudo apt install -y -qq supervisor || true
    sudo systemctl enable supervisor >/dev/null 2>&1 || true
}

# ==============================================
# ✅ FULLY FIXED: ARTIFACT REGISTRY SETUP
# ==============================================
setup_artifact_registry() {
    local TARGET_REGION="$1"
    PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
    REPO_NAME="xray-images"
    
    echo -e "\n${CYAN}📦 Checking Artifact Registry Repository...${NC}"
    if ! gcloud artifacts repositories describe "$REPO_NAME" --location="$TARGET_REGION" --project="$PROJECT_ID" &>/dev/null; then
        echo -e "${YELLOW}⚠️ Repository not found. Creating: $REPO_NAME in $TARGET_REGION...${NC}"
        gcloud artifacts repositories create "$REPO_NAME" \
            --repository-format=docker \
            --location="$TARGET_REGION" \
            --project="$PROJECT_ID" \
            --quiet
        echo -e "${GREEN}✅ Artifact Registry Repository created!${NC}"
    else
        echo -e "${GREEN}✅ Artifact Registry Repository already exists.${NC}"
    fi

    echo -e "${CYAN}🔐 Configuring Docker authentication...${NC}"
    gcloud auth configure-docker "${TARGET_REGION}-docker.pkg.dev" --quiet
    ARTIFACT_REGISTRY_URL="${TARGET_REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"
}

# ==============================================
# LIST SERVICES
# ==============================================
list_deployed_services() {
    echo -e "\n======================================"
    echo -e "${CYAN}📋 ALL DEPLOYED GCP-XRAY SERVICES${NC}"
    echo -e "======================================"
    PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
    echo "Project: $PROJECT_ID"
    echo ""

    declare -A REGION_NAMES=(
        ["us-central1"]="Iowa, United States 🇺🇸"
        ["us-east1"]="South Carolina, United States 🇺🇸"
        ["us-east4"]="N. Virginia, United States 🇺🇸"
        ["us-west1"]="Oregon, United States 🇺🇸"
        ["asia-east1"]="Taiwan 🇹🇼"
        ["asia-southeast1"]="Singapore 🇸🇬"
        ["asia-northeast1"]="Tokyo, Japan 🇯🇵"
        ["asia-northeast3"]="Seoul, South Korea 🇰🇷"
        ["europe-west1"]="Belgium 🇧🇪"
        ["europe-west4"]="Netherlands 🇳🇱"
        ["europe-west9"]="Paris, France 🇫🇷"
        ["asia-south1"]="Mumbai, India 🇮🇳"
    )

    SERVICES=$(gcloud run services list \
        --format="value(metadata.name, status.url, region, metadata.creationTimestamp.date(%Y-%m-%d))" \
        --project="$PROJECT_ID" 2>/dev/null)

    if [ -z "$SERVICES" ]; then
        echo -e "${RED}❌ No services found.${NC}"
    else
        local COUNT=1
        while IFS=$'\t' read -r NAME URL REGION CREATED; do
            [ -z "$NAME" ] && continue
            FULL_REGION="${REGION_NAMES[$REGION]:-$REGION}"
            DETAILS=$(gcloud run services describe "$NAME" --region "$REGION" --project="$PROJECT_ID" --format=json 2>/dev/null || true)
            
            if [ -z "$DETAILS" ]; then
                echo -e "${GREEN}=== SERVICE #$COUNT ===${NC}"
                echo "🔹 Name: $NAME"
                echo "🔹 URL: $URL"
                echo "🔹 Region: $REGION → $FULL_REGION"
                echo "🔹 Created: $CREATED"
                echo ""
                ((COUNT++))
                continue
            fi

            MEMORY=$(echo "$DETAILS" | jq -r '.spec.template.spec.containers[0].resources.limits.memory // "1Gi"')
            CPU=$(echo "$DETAILS"
