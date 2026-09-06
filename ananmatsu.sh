#!/usr/bin/env bash
set -eo pipefail

# --- Catch Ctrl+C (SIGINT) and Exit Cleanly ---
trap 'echo -e "\n[ABORTED] Script interrupted by user."; kill 0; exit 130' INT TERM


echo "=================================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Provisioning Setup"
echo "=================================================="

# --- 1. Detect ComfyUI Directory & Set Paths ---
if [ -d "/workspace/ComfyUI" ]; then
    COMFY_DIR="/workspace/ComfyUI"
elif [ -d "/opt/ComfyUI" ]; then
    COMFY_DIR="/opt/ComfyUI"
else
    COMFY_DIR="/workspace/ComfyUI"
fi

CKPT_DIR="$COMFY_DIR/models/checkpoints"
mkdir -p "$CKPT_DIR"

echo "[INFO] ComfyUI checkpoints target: $CKPT_DIR"

# --- 2. Ensure Fast Downloader (aria2) is Installed ---
if ! command -v aria2c &> /dev/null; then
    echo "[INFO] Installing aria2 for fast multi-threaded downloads..."
    apt-get update -qq && apt-get install -y -qq aria2 > /dev/null
fi

# --- 3. Target File Details ---
MODEL_URL="https://huggingface.co/Unzanezx/ananmatsu_v2/resolve/main/amanatsuIllustrious_v11.safetensors"
MODEL_FILENAME="amanatsuIllustrious_v11.safetensors"
TARGET_FILE="$CKPT_DIR/$MODEL_FILENAME"

# --- 4. Download Model ---
if [ -f "$TARGET_FILE" ]; then
    echo "[SKIP] Model already exists at: $TARGET_FILE"
else
    echo "[INFO] Downloading $MODEL_FILENAME..."
    aria2c -x 16 -s 16 -k 1M -c \
        --summary-interval=10 \
        --dir="$CKPT_DIR" \
        --out="$MODEL_FILENAME" \
        "$MODEL_URL"
fi

# --- 5. Verify Installation ---
echo "=================================================="
if [ -f "$TARGET_FILE" ]; then
    FILE_SIZE=$(ls -lh "$TARGET_FILE" | awk '{print $5}')
    echo "[SUCCESS] Model successfully installed!"
    echo "Path: $TARGET_FILE"
    echo "Size: $FILE_SIZE"
else
    echo "[ERROR] Model download failed or file is missing!"
    exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Provisioning finished successfully."
echo "=================================================="
