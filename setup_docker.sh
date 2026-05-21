#!/usr/bin/env bash
set -euo pipefail

# ================================
# 1. Docker 설치 확인
# ================================
echo "[1/4] Checking Docker..."

if ! command -v docker &>/dev/null; then
  echo "  Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "  Docker installed. 그룹 반영을 위해 로그아웃 후 재로그인 필요."
else
  echo "  Docker already installed: $(docker --version)"
fi

# ================================
# 2. nvidia-container-toolkit 설치
# ================================
echo "[2/4] Installing nvidia-container-toolkit..."

if dpkg -s nvidia-container-toolkit &>/dev/null 2>&1; then
  echo "  nvidia-container-toolkit already installed, skipping."
else
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -sL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  sudo apt-get update -qq
  sudo apt-get install -y nvidia-container-toolkit
  echo "  nvidia-container-toolkit installed."
fi

# ================================
# 3. Docker 데몬 NVIDIA 런타임 설정
# ================================
echo "[3/4] Configuring Docker daemon for NVIDIA runtime..."

if docker info 2>/dev/null | grep -q "nvidia"; then
  echo "  NVIDIA runtime already configured, skipping."
else
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
  echo "  Docker daemon restarted."
fi

# ================================
# 4. GPU 접근 검증
# ================================
echo "[4/4] Verifying GPU access in Docker..."

if docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi; then
  echo ""
  echo "  GPU access OK. docker compose up -d 로 Ollama를 시작하세요."
else
  echo ""
  echo "  ERROR: GPU access failed."
  echo "  드라이버 또는 nvidia-container-toolkit 설치를 확인하세요."
  exit 1
fi
