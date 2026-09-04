#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_URL="vulebaolong/devops_04.git"
REPO_DIR="$HOME/devops_04"
COMPOSE_DIR="$REPO_DIR/docker-compose"

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

clear

title "SETUP APPLICATION SERVER"

echo "Máy này sẽ tự động:"
echo
echo "  1. Update Ubuntu + cài Git"
echo "  2. Cài Docker + Docker Compose"
echo "  3. Clone / update devops_04"
echo "  4. Copy .env.example -> .env"
echo "  5. Kiểm tra Docker Compose"
echo "  6. Build + start containers"
echo "  7. Cài Nginx"
echo

title "1/7 - UPDATE SYSTEM & INSTALL GIT"

sudo apt update

if command -v git >/dev/null 2>&1; then
    echo "[OK] Git đã được cài:"
    git --version
else
    sudo apt install -y git
    git --version
fi

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

title "3/7 - CLONE / UPDATE DEVOPS_04"

if [ -d "$REPO_DIR/.git" ]; then
    echo "Repo đã tồn tại: $REPO_DIR"
    echo "Đang git pull..."

    cd "$REPO_DIR"
    git pull --ff-only
else
    echo "Đang clone: $REPO_URL"
    git clone "$REPO_URL" "$REPO_DIR"
fi

echo
echo "[OK] Source code: $REPO_DIR"

title "4/7 - CREATE ENV FILES"

ENV_COUNT=0

while IFS= read -r -d '' env_example
do
    folder="$(dirname "$env_example")"
    env_file="$folder/.env"

    if [ -f "$env_file" ]; then
        echo "[SKIP] $env_file"
    else
        cp "$env_example" "$env_file"
        echo "[OK] $env_example -> $env_file"
    fi

    ENV_COUNT=$((ENV_COUNT + 1))
done < <(find "$REPO_DIR" -type f -name ".env.example" -not -path "*/.git/*" -print0)

if [ "$ENV_COUNT" -eq 0 ]; then
    echo "[WARNING] Không tìm thấy file .env.example"
else
    echo "[OK] Đã kiểm tra $ENV_COUNT file .env.example"
fi

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

echo "[OK] Compose file: $COMPOSE_DIR/$COMPOSE_FILE"

sudo docker compose -f "$COMPOSE_FILE" config -q
echo "[OK] Docker Compose config hợp lệ."

title "6/7 - START DOCKER COMPOSE"

echo "Đang build và start containers..."
sudo docker compose -f "$COMPOSE_FILE" up -d --build

echo
echo "----------------------------------------"
echo "DOCKER CONTAINERS"
echo "----------------------------------------"

sudo docker compose -f "$COMPOSE_FILE" ps

title "7/7 - INSTALL NGINX"

if command -v nginx >/dev/null 2>&1; then
    echo "[OK] Nginx đã được cài."
else
    sudo apt install -y nginx
fi

sudo systemctl enable --now nginx
sudo nginx -t

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
echo "----------------------------------------"
echo "RUNNING CONTAINERS"
echo "----------------------------------------"

cd "$COMPOSE_DIR"
sudo docker compose -f "$COMPOSE_FILE" ps

echo
echo "========================================"
echo " DONE"
echo "========================================"
