#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "========================================"
echo " INSTALL DOCKER"
echo "========================================"

TARGET_USER="${SUDO_USER:-$USER}"

# Nếu Docker + Compose đã có đầy đủ thì không cài lại
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "[OK] Docker + Docker Compose đã được cài."
    docker --version
    docker compose version

    sudo systemctl enable --now docker
    sudo groupadd -f docker
    sudo usermod -aG docker "$TARGET_USER"

    exit 0
fi

echo "[1/6] Update apt..."
sudo apt update

echo "[2/6] Install dependencies..."
sudo apt install -y \
    ca-certificates \
    curl

echo "[3/6] Remove conflicting Docker packages..."

for pkg in \
    docker.io \
    docker-compose \
    docker-compose-v2 \
    docker-doc \
    docker-buildx \
    podman-docker \
    containerd \
    runc
do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
        sudo apt remove -y "$pkg"
    fi
done

echo "[4/6] Add Docker GPG key..."

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "[5/6] Add Docker repository..."

. /etc/os-release

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

echo "[6/6] Install Docker Engine + Compose..."

sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable --now docker

sudo groupadd -f docker
sudo usermod -aG docker "$TARGET_USER"

echo
echo "Docker:"
sudo docker --version

echo
echo "Docker Compose:"
sudo docker compose version

echo
echo "Docker daemon:"
sudo docker info >/dev/null
echo "[OK] Docker daemon đang chạy."

echo
echo "Docker cài đặt thành công."
echo "User '$TARGET_USER' đã được thêm vào group docker."
echo "Đăng nhập SSH lại nếu muốn chạy docker không cần sudo."
