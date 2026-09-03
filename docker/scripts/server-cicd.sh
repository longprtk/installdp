#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo "========================================"
echo "       SETUP CI/CD SERVER"
echo "========================================"


# =========================================================
# 1. Update
# =========================================================

echo
echo "[1/5] Updating system..."

sudo apt update


# =========================================================
# 2. Docker
# =========================================================

echo
echo "[2/5] Installing Docker..."

bash "$SCRIPT_DIR/docker.sh"


# =========================================================
# 3. Nginx
# =========================================================

echo
echo "[3/5] Installing Nginx..."

sudo apt install -y nginx

sudo systemctl enable nginx
sudo systemctl start nginx


# =========================================================
# 4. Java 21
# =========================================================

echo
echo "[4/5] Installing Java 21..."

sudo apt install -y \
    fontconfig \
    openjdk-21-jre \
    wget

java -version


# =========================================================
# 5. Jenkins
# =========================================================

echo
echo "[5/5] Installing Jenkins..."

sudo mkdir -p /etc/apt/keyrings

sudo wget \
    -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update

sudo apt install -y jenkins

sudo systemctl enable jenkins
sudo systemctl start jenkins


# =========================================================
# Cho Jenkins dùng Docker
# =========================================================

echo
echo "Adding Jenkins user to Docker group..."

sudo usermod -aG docker jenkins

sudo systemctl restart docker
sudo systemctl restart jenkins


# =========================================================
# Finished
# =========================================================

echo
echo "========================================"
echo " CI/CD SERVER SETUP COMPLETED"
echo "========================================"

echo
echo "Docker:"
sudo docker --version

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

sudo cat /var/lib/jenkins/secrets/initialAdminPassword

echo
echo
echo "Jenkins chạy mặc định tại:"
echo "http://<EC2-PUBLIC-IP>:8080"
echo