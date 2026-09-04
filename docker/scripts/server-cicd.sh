#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOMAIN="jenkins.longh.org"

SSL_DIR="/etc/nginx/ssl"
SSL_CERT_NAME="longh-public.crt"
SSL_KEY_NAME="longh-private.key"

SSL_CERT_SOURCE="$SCRIPT_DIR/$SSL_CERT_NAME"
SSL_KEY_SOURCE="$SCRIPT_DIR/$SSL_KEY_NAME"

NGINX_SITE="/etc/nginx/sites-available/$DOMAIN"
NGINX_SITE_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

echo
echo "========================================"
echo "       SETUP CI/CD SERVER"
echo "========================================"

echo
echo "[1/6] Updating system..."
sudo apt update

# ============================================================
# Docker
# ============================================================

echo
echo "[2/6] Installing Docker..."

if [ ! -f "$SCRIPT_DIR/docker.sh" ]; then
    echo "[ERROR] Không tìm thấy $SCRIPT_DIR/docker.sh"
    exit 1
fi

bash "$SCRIPT_DIR/docker.sh"

# ============================================================
# Nginx
# ============================================================

echo
echo "[3/6] Installing Nginx..."

sudo apt install -y nginx
sudo systemctl enable --now nginx

# ============================================================
# Java 21
# ============================================================

echo
echo "[4/6] Installing Java 21..."

sudo apt install -y \
    fontconfig \
    openjdk-21-jre \
    wget

java -version

# ============================================================
# Jenkins
# ============================================================

echo
echo "[5/6] Installing Jenkins..."

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

# ============================================================
# Nginx Reverse Proxy + SSL
# ============================================================

echo
echo "[6/6] Configuring Nginx reverse proxy + SSL..."

echo
echo "Checking SSL certificate files..."

if [ ! -f "$SSL_CERT_SOURCE" ]; then
    echo "[ERROR] Không tìm thấy SSL certificate:"
    echo "        $SSL_CERT_SOURCE"
    exit 1
fi

if [ ! -f "$SSL_KEY_SOURCE" ]; then
    echo "[ERROR] Không tìm thấy SSL private key:"
    echo "        $SSL_KEY_SOURCE"
    exit 1
fi

echo
echo "Creating SSL directory..."

sudo install -d -m 0755 "$SSL_DIR"

echo
echo "Installing SSL certificate..."

sudo install \
    -m 0644 \
    "$SSL_CERT_SOURCE" \
    "$SSL_DIR/$SSL_CERT_NAME"

echo
echo "Installing SSL private key..."

sudo install \
    -m 0600 \
    "$SSL_KEY_SOURCE" \
    "$SSL_DIR/$SSL_KEY_NAME"

echo
echo "Creating Nginx site: $DOMAIN"

sudo tee "$NGINX_SITE" >/dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name $DOMAIN;

    ssl_certificate $SSL_DIR/$SSL_CERT_NAME;
    ssl_certificate_key $SSL_DIR/$SSL_KEY_NAME;

    location / {
        proxy_pass http://127.0.0.1:8080;

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 90s;
        proxy_redirect off;
    }
}
EOF

echo
echo "Enabling Nginx site..."

sudo ln -sfn "$NGINX_SITE" "$NGINX_SITE_ENABLED"

# Disable default Nginx site
if [ -L /etc/nginx/sites-enabled/default ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
fi

echo
echo "Testing Nginx configuration..."

sudo nginx -t

echo
echo "Reloading Nginx..."

sudo systemctl reload nginx

# ============================================================
# Final checks
# ============================================================

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
echo "Nginx status:"
sudo systemctl --no-pager status nginx || true

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
echo "========================================"
echo " Jenkins URL"
echo "========================================"
echo
echo "https://$DOMAIN"
echo
