#!/usr/bin/env bash

set -e
echo
echo "========================================"
echo " INSTALL DOCKER"
echo "========================================"

# User thật đang chạy script
TARGET_USER="${SUDO_USER:-$USER}"

echo "User: $TARGET_USER"

# ============================================================
# Kiểm tra Docker + Docker Compose
# ============================================================

if command -v docker >/dev/null 2>&1; then
    echo "Phát hiện Docker:"
    docker --version || true

    if docker compose version >/dev/null 2>&1; then
        echo "Docker Compose:"
        docker compose version

        echo
        echo "Docker + Docker Compose đã được cài đầy đủ."
        exit 0
    fi

    echo
    echo "Docker đã tồn tại nhưng Docker Compose chưa có."
    echo "Tiếp tục cài Docker Compose / Docker official..."
fi

# ============================================================
# Kiểm tra Ubuntu
# ============================================================

if [ ! -f /etc/os-release ]; then
    echo "Không xác định được hệ điều hành."
    exit 1
fi

. /etc/os-release

if [ "$ID" != "ubuntu" ]; then
    echo "Script này chỉ hỗ trợ Ubuntu."
    echo "OS hiện tại: $ID"
    exit 1
fi

echo "Ubuntu: $VERSION_ID"
echo "Codename: ${UBUNTU_CODENAME:-$VERSION_CODENAME}"
echo

# ============================================================
# Update apt
# ============================================================

echo "[1/6] Update apt..."

sudo apt update

# ============================================================
# Dependencies
# ============================================================

echo "[2/6] Install dependencies..."

sudo apt install -y \
    ca-certificates \
    curl

# ============================================================
# Remove Docker packages có thể conflict
# ============================================================

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
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "Remove: $pkg"
        sudo apt remove -y "$pkg"
    fi
done

# ============================================================
# Docker GPG key
# ============================================================

echo "[4/6] Add Docker GPG key..."

sudo install -m 0755 -d /etc/apt/keyrings

sudo rm -f /etc/apt/keyrings/docker.asc

sudo curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

# ============================================================
# Docker repository
# ============================================================

echo "[5/6] Add Docker repository..."

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

# ============================================================
# Install Docker
# ============================================================

echo "[6/6] Install Docker Engine + Compose..."

sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Enable + start Docker
sudo systemctl enable --now docker

# ============================================================
# Add user vào docker group
# ============================================================

if id "$TARGET_USER" >/dev/null 2>&1; then
    sudo usermod -aG docker "$TARGET_USER"
fi

# ============================================================
# Verify
# ============================================================

echo
echo "========================================"
echo " VERIFY DOCKER"
echo "========================================"

sudo docker --version
sudo docker compose version

echo
echo "Test Docker daemon..."

sudo docker info >/dev/null

echo
echo "========================================"
echo " Docker installed successfully"
echo "========================================"
echo
echo "User '$TARGET_USER' đã được thêm vào group docker."
echo "Đăng xuất SSH và đăng nhập lại để có thể chạy docker"
echo "không cần sudo."
echo
