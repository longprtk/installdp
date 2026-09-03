#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/vulebaolong/devops_04.git"
REPO_DIR="$HOME/devops_04"

echo "========================================"
echo " SETUP APPLICATION SERVER"
echo "========================================"

# -----------------------------------------
# 1. Install Git
# -----------------------------------------

sudo apt update
sudo apt install -y git


# -----------------------------------------
# 2. Install Docker
# -----------------------------------------

sudo apt install -y ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable --now docker


# -----------------------------------------
# 3. Clone devops_04
# -----------------------------------------

cd "$HOME"

if [ -d "$REPO_DIR/.git" ]; then
    echo "Repo đã tồn tại -> git pull"
    cd "$REPO_DIR"
    git pull
else
    git clone "$REPO_URL"
    cd "$REPO_DIR"
fi


# -----------------------------------------
# 4. Copy tất cả .env.example -> .env
# -----------------------------------------

echo
echo "========================================"
echo " CREATE ENV FILES"
echo "========================================"

find "$REPO_DIR" -type f -name ".env.example" | while read -r env_example
do
    folder="$(dirname "$env_example")"
    env_file="$folder/.env"

    if [ -f "$env_file" ]; then
        echo "[SKIP] $env_file"
    else
        cp "$env_example" "$env_file"
        echo "[OK] $env_example -> $env_file"
    fi
done


# -----------------------------------------
# 5. Docker Compose
# -----------------------------------------

echo
echo "========================================"
echo " START DOCKER COMPOSE"
echo "========================================"

cd "$REPO_DIR/docker-compose"

sudo docker compose up -d


# -----------------------------------------
# 6. Install Nginx
# -----------------------------------------

echo
echo "========================================"
echo " INSTALL NGINX"
echo "========================================"

sudo apt install -y nginx

sudo systemctl enable --now nginx


# -----------------------------------------
# Finished
# -----------------------------------------

echo
echo "========================================"
echo " FINISHED"
echo "========================================"

sudo docker compose ps