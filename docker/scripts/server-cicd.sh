#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo "========================================"
echo "       SETUP CI/CD SERVER"
echo "========================================"

echo
echo "[1/5] Updating system..."
sudo apt update

echo
echo "[2/5] Installing Docker..."

if [ ! -f "$SCRIPT_DIR/docker.sh" ]; then
    echo "[ERROR] Không tìm thấy $SCRIPT_DIR/docker.sh"
    exit 1
fi

bash "$SCRIPT_DIR/docker.sh"

echo
echo "[3/5] Installing Nginx..."

sudo apt install -y nginx
sudo systemctl enable --now nginx

echo
echo "[4/5] Installing Java 21..."

sudo apt install -y \
    fontconfig \
    openjdk-21-jre \
    wget

java -version

echo
echo "[5/5] Installing Jenkins..."

sudo install -m 0755 -d /etc/apt/keyrings

sudo wget -q \
    -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

sudo chmod a+r /etc/apt/keyrings/jenkins-keyring.asc

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null

sudo apt update
sudo apt install -y jenkins

sudo systemctl enable --now jenkins

echo
echo "Adding Jenkins user to Docker group..."

sudo usermod -aG docker jenkins

# Restart Jenkins để process nhận group docker mới.
# Không cần restart Docker daemon.
sudo systemctl restart jenkins

echo
echo "Checking Jenkins Docker permission..."

if sudo -u jenkins docker ps >/dev/null 2>&1; then
    echo "[OK] Jenkins có thể sử dụng Docker."
else
    echo "[WARNING] Jenkins chưa truy cập được Docker."
    id jenkins || true
    ls -l /var/run/docker.sock || true
fi

echo
echo "========================================"
echo " CI/CD SERVER SETUP COMPLETED"
echo "========================================"

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
echo "Java:"
java -version

echo
echo "Jenkins status:"
sudo systemctl --no-pager status jenkins || true

echo
echo "----------------------------------------"
echo "Jenkins unlock password:"
echo "----------------------------------------"

JENKINS_PASSWORD_FILE="/var/lib/jenkins/secrets/initialAdminPassword"

if [ -f "$JENKINS_PASSWORD_FILE" ]; then
    sudo cat "$JENKINS_PASSWORD_FILE"
else
    echo "Không tìm thấy initialAdminPassword."
    echo "Có thể Jenkins đã được setup trước đó."
fi

echo
echo
echo "Jenkins chạy mặc định tại:"
echo "http://<EC2-PUBLIC-IP>:8080"
echo
