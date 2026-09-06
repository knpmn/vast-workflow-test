#!/usr/bin/env bash
set -eo pipefail

# --- Color Formatting ---
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'

if [ ! -t 1 ]; then
    C_RESET='' C_BOLD='' C_BLUE='' C_CYAN='' C_GREEN='' C_YELLOW='' C_RED=''
fi

# --- Logging Helpers ---
log_time()    { date '+%H:%M:%S'; }
log_info()    { printf "${C_CYAN}[%s] [INFO]${C_RESET}  %s\n" "$(log_time)" "$*"; }
log_success() { printf "${C_GREEN}[%s] [OK]${C_RESET}    %s\n" "$(log_time)" "$*"; }
log_warn()    { printf "${C_YELLOW}[%s] [WARN]${C_RESET}  %s\n" "$(log_time)" "$*"; }
log_error()   { printf "${C_RED}${C_BOLD}[%s] [ERROR]${C_RESET} %s\n" "$(log_time)" "$*"; }
log_step()    { printf "\n${C_BOLD}${C_BLUE}─── [%s] %s ───${C_RESET}\n" "$(log_time)" "$*"; }

START_TIME=$(date +%s)

# --- Signal Trap ---
cleanup() {
    printf "\n"
    log_warn "Caught interruption signal. Killing active child downloads..."
    pkill -P $$ 2>/dev/null || true
    log_error "Provisioning aborted by user."
    exit 130
}
trap cleanup INT TERM

printf "${C_BOLD}${C_BLUE}================================================================${C_RESET}\n"
printf "${C_BOLD}     ComfyUI Multi-Asset Dynamic Provisioning Pipeline          ${C_RESET}\n"
printf "${C_BOLD}${C_BLUE}================================================================${C_RESET}\n"

# --- 1. Detect ComfyUI Directory ---
log_step "Step 1: Locating ComfyUI Root"

if [ -d "/workspace/ComfyUI" ]; then
    COMFY_DIR="/workspace/ComfyUI"
elif [ -d "/opt/ComfyUI" ]; then
    COMFY_DIR="/opt/ComfyUI"
else
    COMFY_DIR="/workspace/ComfyUI"
fi

log_info "Active ComfyUI Directory: ${COMFY_DIR}"

# --- 2. Verify HF Tooling & Xet High Performance Engine ---
log_step "Step 2: Checking Download Engine"

if command -v hf &> /dev/null; then
    log_success "'hf' CLI is installed."
else
    log_info "Installing modern 'hf' CLI via huggingface_hub..."
    pip install -q -U "huggingface_hub[cli]"
fi

# Modern high-performance transfers in Hugging Face use Xet
export HF_XET_HIGH_PERFORMANCE=1
log_success "HF_XET_HIGH_PERFORMANCE=1 enabled."

# --- 3. Dynamic Asset Manifest ---
# Format: "REPO_ID | FILENAME | RELATIVE_SUBFOLDER"
DOWNLOAD_TARGETS=(
    "Unzanezx/ananmatsu_v2 | amanatsuIllustrious_v11.safetensors | models/checkpoints"
    "Unzanezx/ananmatsu_v2 | IFL_v1.0_IL.safetensors | models/loras"
)

AUTH_FLAG=()
if [ -n "$HF_TOKEN" ]; then
    log_info "Using detected \$HF_TOKEN."
    AUTH_FLAG=(--token "$HF_TOKEN")
fi

# --- 4. Process Downloads ---
log_step "Step 3: Processing Asset Downloads (${#DOWNLOAD_TARGETS[@]} items)"

for entry in "${DOWNLOAD_TARGETS[@]}"; do
    IFS='|' read -r repo_raw file_raw folder_raw <<< "$entry"
    REPO=$(echo "$repo_raw" | xargs)
    FILENAME=$(echo "$file_raw" | xargs)
    REL_FOLDER=$(echo "$folder_raw" | xargs)

    DEST_DIR="$COMFY_DIR/$REL_FOLDER"
    TARGET_PATH="$DEST_DIR/$FILENAME"

    mkdir -p "$DEST_DIR"

    printf "\n"
    log_info "Target File: ${FILENAME}"
    log_info "Destination: ${DEST_DIR}"

    # Existence check: Skip network call entirely if file is non-empty
    if [ -s "$TARGET_PATH" ]; then
        FILE_SIZE=$(ls -lh "$TARGET_PATH" | awk '{print $5}')
        log_warn "File already exists and is non-empty (${FILE_SIZE}). Skipping download."
        continue
    fi

    log_info "Fetching from '${REPO}'..."
    
    # Download single target file without recreating repo folder tree
    hf download "$REPO" "$FILENAME" \
        --local-dir "$DEST_DIR" \
        "${AUTH_FLAG[@]}"

    if [ -s "$TARGET_PATH" ]; then
        FILE_SIZE=$(ls -lh "$TARGET_PATH" | awk '{print $5}')
        log_success "Downloaded successfully (${FILE_SIZE})."
    else
        log_error "Failed to verify '${FILENAME}' after download (missing or 0-byte)."
        exit 1
    fi
done

# --- 5. Execution Summary ---
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

printf "\n${C_BOLD}${C_GREEN}================================================================${C_RESET}\n"
printf "${C_BOLD}${C_GREEN}[SUCCESS] All assets provisioned in %ss.${C_RESET}\n" "$TOTAL_DURATION"
printf "${C_BOLD}${C_GREEN}================================================================${C_RESET}\n"
