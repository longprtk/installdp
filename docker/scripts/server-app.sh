#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# CONFIG
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

REPO_URL="https://github.com/vulebaolong/devops_04.git"
REPO_DIR="$TARGET_HOME/devops_04"
COMPOSE_DIR="$REPO_DIR/docker-compose"


# ============================================================
# FUNCTIONS
# ============================================================

title() {
    echo
    echo "========================================"
    echo " $1"
    echo "========================================"
}

error_exit() {
    echo
    echo "[ERROR] $1"
    exit 1
}


# ============================================================
# START
# ============================================================

clear

title "SETUP APPLICATION SERVER"

echo "User: $TARGET_USER"
echo "Home: $TARGET_HOME"
echo

echo "Máy này sẽ tự động:"
echo
echo "  1. Update Ubuntu"
echo "  2. Cài Git"
echo "  3. Cài Docker + Docker Compose"
echo "  4. Clone / update devops_04"
echo "  5. Copy .env.example -> .env"
echo "  6. Docker Compose Up"
echo "  7. Cài Nginx"
echo


# ============================================================
# 1. UPDATE SYSTEM + INSTALL GIT
# ============================================================

title "1/7 - UPDATE SYSTEM & INSTALL GIT"

sudo apt update

if command -v git >/dev/null 2>&1; then
    echo "[OK] Git đã được cài:"
    git --version
else
    sudo apt install -y git

    echo "[OK] Git installed:"
    git --version
fi


# ============================================================
# 2. INSTALL DOCKER
# ============================================================

title "2/7 - INSTALL DOCKER"

if [ ! -f "$SCRIPT_DIR/docker.sh" ]; then
    error_exit "Không tìm thấy $SCRIPT_DIR/docker.sh"
fi

bash "$SCRIPT_DIR/docker.sh"

echo
echo "[OK] Docker:"
sudo docker --version

echo
echo "[OK] Docker Compose:"
sudo docker compose version

echo
echo "[OK] Docker daemon:"
sudo docker info >/dev/null
echo "Docker daemon đang chạy."


# ============================================================
# 3. CLONE / UPDATE DEVOPS_04
# ============================================================

title "3/7 - CLONE / UPDATE DEVOPS_04"

if [ -d "$REPO_DIR/.git" ]; then

    echo "Repo đã tồn tại:"
    echo "$REPO_DIR"
    echo

    cd "$REPO_DIR"

    echo "Đang cập nhật source..."

    git pull --ff-only

else

    echo "Đang clone:"
    echo "$REPO_URL"
    echo

    git clone "$REPO_URL" "$REPO_DIR"

    cd "$REPO_DIR"

fi

echo
echo "[OK] Source code:"
echo "$REPO_DIR"


# ============================================================
# 4. COPY .ENV.EXAMPLE -> .ENV
# ============================================================

title "4/7 - CREATE ENV FILES"

ENV_COUNT=0

while IFS= read -r -d '' env_example
do
    folder="$(dirname "$env_example")"
    env_file="$folder/.env"

    if [ -f "$env_file" ]; then

        echo "[SKIP] Đã tồn tại:"
        echo "       $env_file"

    else

        cp "$env_example" "$env_file"

        echo "[OK] $env_example"
        echo "  -> $env_file"

    fi

    ENV_COUNT=$((ENV_COUNT + 1))

done < <(
    find "$REPO_DIR" \
        -type f \
        -name ".env.example" \
        -not -path "*/.git/*" \
        -print0
)

echo

if [ "$ENV_COUNT" -eq 0 ]; then
    echo "[WARNING] Không tìm thấy file .env.example"
else
    echo "[OK] Đã kiểm tra $ENV_COUNT file .env.example"
fi


# ============================================================
# 5. CHECK DOCKER COMPOSE
# ============================================================

title "5/7 - CHECK DOCKER COMPOSE"

if [ ! -d "$COMPOSE_DIR" ]; then
    error_exit "Không tìm thấy thư mục $COMPOSE_DIR"
fi

cd "$COMPOSE_DIR"

if [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"

elif [ -f "docker-compose.yaml" ]; then
    COMPOSE_FILE="docker-compose.yaml"

elif [ -f "compose.yml" ]; then
    COMPOSE_FILE="compose.yml"

elif [ -f "compose.yaml" ]; then
    COMPOSE_FILE="compose.yaml"

else
    error_exit "Không tìm thấy Docker Compose file trong $COMPOSE_DIR"
fi


echo "[OK] Compose directory:"
echo "$COMPOSE_DIR"

echo
echo "[OK] Compose file:"
echo "$COMPOSE_FILE"

echo
echo "Kiểm tra cấu hình Docker Compose..."

if sudo docker compose -f "$COMPOSE_FILE" config -q; then
    echo "[OK] Docker Compose config hợp lệ."
else
    error_exit "Docker Compose config không hợp lệ."
fi


# ============================================================
# 6. START DOCKER COMPOSE
# ============================================================

title "6/7 - START DOCKER COMPOSE"

cd "$COMPOSE_DIR"

echo "Đang build images..."
echo

sudo docker compose -f "$COMPOSE_FILE" build

echo
echo "Đang start containers..."
echo

sudo docker compose -f "$COMPOSE_FILE" up -d


echo
echo "----------------------------------------"
echo "DOCKER CONTAINERS"
echo "----------------------------------------"

sudo docker compose -f "$COMPOSE_FILE" ps


# ============================================================
# 7. INSTALL NGINX
# ============================================================

title "7/7 - INSTALL NGINX"

if command -v nginx >/dev/null 2>&1; then

    echo "[OK] Nginx đã được cài."

else

    echo "Installing Nginx..."

    sudo apt install -y nginx

fi

sudo systemctl enable nginx

echo
echo "Kiểm tra cấu hình Nginx..."

sudo nginx -t

sudo systemctl restart nginx

echo
echo "[OK] Nginx:"
nginx -v


# ============================================================
# FINISHED
# ============================================================

title "APPLICATION SERVER SETUP COMPLETED"

echo
echo "Git:"
git --version

echo
echo "Docker:"
sudo docker --version

echo
echo "Docker Compose:"
sudo docker compose version

echo
echo "Nginx:"
nginx -v

echo
echo "Project:"
echo "$REPO_DIR"

echo
echo "Docker Compose:"
echo "$COMPOSE_DIR"

echo
echo "----------------------------------------"
echo "RUNNING CONTAINERS"
echo "----------------------------------------"

cd "$COMPOSE_DIR"

sudo docker compose -f "$COMPOSE_FILE" ps

echo
echo "----------------------------------------"
echo "LISTENING PORTS"
echo "----------------------------------------"

sudo ss -lntp || true

echo
echo "========================================"
echo " DONE"
echo "========================================"
