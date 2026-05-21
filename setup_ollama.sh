#!/usr/bin/env bash
set -euo pipefail

MODEL="qwen3.6:27b"
OLLAMA_PORT=11434

# ================================
# 1. Ollama 설치 (이미 설치돼 있으면 스킵)
# ================================
if ! command -v ollama &>/dev/null; then
  echo "[1/4] Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
else
  echo "[1/4] Ollama already installed: $(ollama --version)"
fi

# ================================
# 2. Ollama 서버 백그라운드 실행
# ================================
echo "[2/4] Starting Ollama server..."

if pgrep -x "ollama" &>/dev/null; then
  echo "  Ollama server already running, skipping."
else
  export OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT}
  nohup ollama serve > /tmp/ollama.log 2>&1 &
  disown $!

  echo "  Waiting for server to be ready..."
  for i in $(seq 1 30); do
    if curl -sf http://localhost:${OLLAMA_PORT}/api/version &>/dev/null; then
      echo "  Server is up."
      break
    fi
    sleep 1
    if [ "$i" -eq 30 ]; then
      echo "  ERROR: Ollama server did not start in time."
      echo "  Run: tail -f /tmp/ollama.log"
      exit 1
    fi
  done
fi

# ================================
# 3. 모델 Pull
# ================================
echo "[3/4] Pulling model: $MODEL (~17GB, 시간이 걸릴 수 있습니다)..."
ollama pull "$MODEL"

# ================================
# 4. 모델 GPU 메모리에 로드
# ================================
echo "[4/4] Loading model into GPU memory..."
curl -sf http://localhost:${OLLAMA_PORT}/api/generate \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"\",\"keep_alive\":-1}" \
  -o /dev/null

echo ""
echo "  Done. Ollama API is ready."
echo "  Endpoint : http://0.0.0.0:${OLLAMA_PORT}"
echo "  Log      : tail -f /tmp/ollama.log"
echo ""
echo "  테스트 명령어:"
echo "  curl http://<서버IP>:${OLLAMA_PORT}/api/chat \\"
echo "    -d '{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}'"