#!/usr/bin/env bash
set -euo pipefail

MODEL="qwen3.6:27b"
OLLAMA_PORT=9714

# ================================
# 1. GPU / 드라이버 버전 체크
# ================================
echo "[1/5] Checking GPU driver..."

if ! command -v nvidia-smi &>/dev/null; then
  echo "  WARNING: nvidia-smi not found. GPU acceleration unavailable."
else
  DRIVER_FULL=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
  DRIVER_MAJOR=$(echo "$DRIVER_FULL" | cut -d. -f1)
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
  echo "  GPU    : $GPU_NAME"
  echo "  Driver : $DRIVER_FULL"

  if [ "$DRIVER_MAJOR" -lt 525 ]; then
    echo ""
    echo "  [WARNING] 드라이버 버전이 525 미만입니다 (현재: $DRIVER_FULL)."
    echo "  최신 Ollama는 CUDA 12.x 번들을 사용 → 드라이버 >= 525 필요."
    echo "  그대로 진행하면 CPU fallback으로 실행될 수 있습니다."
    echo ""
    echo "  드라이버 업그레이드: sudo apt install nvidia-driver-535"
    echo ""
    echo "  계속 진행하려면 Enter, 중단하려면 Ctrl+C ..."
    read -r
  else
    echo "  Driver OK (>= 525, CUDA 12 호환)"
  fi
fi

# ================================
# 2. Ollama 설치 (이미 설치돼 있으면 스킵)
# ================================
if ! command -v ollama &>/dev/null; then
  echo "[2/5] Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
else
  echo "[2/5] Ollama already installed: $(ollama --version)"
fi

# ================================
# 3. Ollama 서버 백그라운드 실행
# ================================
echo "[3/5] Starting Ollama server..."

if pgrep -x "ollama" &>/dev/null; then
  echo "  Ollama server already running, skipping."
else
  export OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT}
  export OLLAMA_MODELS=/home/yujin/directory_to_share/models
  nohup ollama serve > /home/yujin/directory_to_share/ollama.log 2>&1 &
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
      echo "  Run: tail -f /home/yujin/directory_to_share/ollama.log"
      exit 1
    fi
  done
fi

# ================================
# 3. 모델 Pull
# ================================
echo "[4/5] Pulling model: $MODEL (~17GB, 시간이 걸릴 수 있습니다)..."
ollama pull "$MODEL"

# ================================
# 5. 모델 GPU 메모리에 로드
# ================================
echo "[5/5] Loading model into GPU memory..."
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