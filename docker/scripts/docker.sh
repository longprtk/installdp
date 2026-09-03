#!/usr/bin/env bash

set -e

echo
echo "========================================"
echo " INSTALL DOCKER"
echo "========================================"

# Nếu Docker đã tồn tại thì không cài lại
if command -v docker >/dev/null 2>&1; then
    echo "Docker đã được cài."
    docker --version
    exit 0
fi

echo "[1/5] Update apt..."
sudo apt update

echo "[2/5] Install dependencies..."
sudo apt install -y \
    ca-certificates \
    curl

echo "[3/5] Add Docker GPG key..."

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "[4/5] Add Docker repository..."

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

echo "[5/5] Install Docker..."

sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

# Cho user hiện tại chạy docker không cần sudo
sudo usermod -aG docker "$USER"

echo
echo "Docker installed:"
sudo docker --version
sudo docker compose version

echo
echo "Docker cài đặt thành công."