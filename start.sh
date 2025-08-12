#!/usr/bin/env bash
set -euo pipefail

LOG="/home/ollama/ollama_startup.log"
echo "startup: $(date)" >> "$LOG"

MODEL_NAME="mistral-7b-instruct-v0.2.Q4_K_M.gguf"
MODEL_DIR="/home/ollama/.ollama/models"
MODEL_PATH="${MODEL_DIR}/${MODEL_NAME}"
MODEL_ALIAS="mistral-7b-q4km"
HF_REPO="TheBloke/Mistral-7B-Instruct-v0.2-GGUF"

mkdir -p "${MODEL_DIR}"
chown ollama:ollama "${MODEL_DIR}" || true

# 1) download model if missing (uses HF_TOKEN env var)
if [ ! -f "${MODEL_PATH}" ]; then
  echo "Model not found at ${MODEL_PATH} — attempting download" >> "$LOG"
  if [ -z "${HF_TOKEN:-}" ]; then
    echo "ERROR: HF_TOKEN not provided; cannot download model." >> "$LOG"
    echo "Set HF_TOKEN environment variable and restart container." >> "$LOG"
    exit 1
  fi

  python3 /usr/local/bin/download_model.py \
    --repo "${HF_REPO}" \
    --filename "${MODEL_NAME}" \
    --out "${MODEL_DIR}" \
    >> "$LOG" 2>&1

  chown ollama:ollama "${MODEL_DIR}/${MODEL_NAME}" || true
  echo "Model downloaded." >> "$LOG"
fi

# 2) create Modelfile if missing
if [ ! -f "${MODEL_DIR}/Modelfile" ]; then
  cat > "${MODEL_DIR}/Modelfile" <<'EOF'
FROM ./mistral-7b-instruct-v0.2.Q4_K_M.gguf
TEMPLATE """{{ .System }}\n{{ .Prompt }}"""
PARAMETER stop ["</s>"]
EOF
  chown ollama:ollama "${MODEL_DIR}/Modelfile" || true
fi

# 3) create Ollama model alias (if not already created)
if ! ollama list | grep -q "${MODEL_ALIAS}"; then
  echo "Creating Ollama model alias ${MODEL_ALIAS}" >> "$LOG"
  ollama create "${MODEL_ALIAS}" -f "${MODEL_DIR}/Modelfile" >> "$LOG" 2>&1 || {
    echo "Failed to create model (see logs)" >> "$LOG"
    # continue - maybe it already exists or will work on next run
  }
fi

# 4) start Ollama server in foreground, binding 0.0.0.0
echo "Starting ollama serve..." >> "$LOG"
ollama serve