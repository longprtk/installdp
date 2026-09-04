#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOMAIN="jenkins.longh.org"

SSL_DIR="/etc/nginx/ssl"
SSL_CERT="$SSL_DIR/longh-public.crt"
SSL_KEY="$SSL_DIR/longh-private.key"

NGINX_SITE="/etc/nginx/sites-available/$DOMAIN"
NGINX_SITE_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

echo
echo "========================================"
echo "       SETUP CI/CD SERVER"
echo "========================================"

# ============================================================
# 1. Update system
# ============================================================

echo
echo "[1/6] Updating system..."

sudo apt update

# ============================================================
# 2. Docker
# ============================================================

echo
echo "[2/6] Installing Docker..."

if [ ! -f "$SCRIPT_DIR/docker.sh" ]; then
    echo "[ERROR] Không tìm thấy $SCRIPT_DIR/docker.sh"
    exit 1
fi

bash "$SCRIPT_DIR/docker.sh"

# ============================================================
# 3. Nginx
# ============================================================

echo
echo "[3/6] Installing Nginx..."

sudo apt install -y nginx

sudo systemctl enable nginx
sudo systemctl start nginx

# ============================================================
# 4. Java 21
# ============================================================

echo
echo "[4/6] Installing Java 21..."

sudo apt install -y \
    fontconfig \
    openjdk-21-jre \
    wget

echo
echo "Java version:"
java -version

# ============================================================
# 5. Jenkins
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

sudo systemctl enable jenkins
sudo systemctl start jenkins

# ============================================================
# Jenkins -> Docker permission
# ============================================================

echo
echo "Adding Jenkins user to Docker group..."

sudo usermod -aG docker jenkins

# Restart Jenkins để process Jenkins nhận group docker mới
sudo systemctl restart jenkins

echo
echo "Checking Jenkins Docker permission..."

if sudo -u jenkins docker ps >/dev/null 2>&1; then
    echo "[OK] Jenkins có thể sử dụng Docker."
else
    echo "[WARNING] Jenkins chưa truy cập được Docker."

    echo
    echo "Jenkins user:"
    id jenkins || true

    echo
    echo "Docker socket:"
    ls -l /var/run/docker.sock || true
fi

# ============================================================
# 6. Nginx Reverse Proxy + SSL
# ============================================================

echo
echo "[6/6] Configuring Nginx reverse proxy + SSL..."

# ============================================================
# Create SSL directory
# ============================================================

echo
echo "Creating SSL directory..."

sudo install -d -m 0755 "$SSL_DIR"

# ============================================================
# SSL Private Key
# ============================================================

echo
echo "Creating SSL private key..."

sudo tee "$SSL_KEY" >/dev/null <<'EOF'
-----BEGIN PRIVATE KEY-----
-----BEGIN PRIVATE KEY-----
MIIEuwIBADANBgkqhkiG9w0BAQEFAASCBKUwggShAgEAAoIBAQC9krPpdvLQ/T6b
JAJzSy23T6//xelLaI6J9YF+h8E+UwLGISc91ObpKBPpgXbyBsMMjfZqCCMSNGKJ
UIVewm4tXlVfsL6WLKZdOx5LrakxWEafu2EYYKqTMO0voqIB6ywCxgPOhzIxxhTL
HffvnfpNz6d011E9Bx1OxwS3+XKmU4uTjiyODgLBsUblfy2lM+T+ztLEvwXnjD8K
OWdaS5DFV1X/4IDYXNfAlEK2igjq4F2/MCHo8ADaMzGgB1y4zy34gCW5LUeP6aFW
EgMLovFMk3H+BtflUVVhaMT2PD3x2MEx1mXwnaSd88O7T/cc2cY5JVUdz3mhOq9A
NjI7lMlxAgMBAAECgf5Tcn2vxw+m5NH5GOdV16AytrZ5bJieZWgDudOIOrPVYjFq
NjOo3uG6L2tZiv2jCSw70LTlgTRxKqvSw52xqQizl/kB5BrgMnKYqL2dDSwnwH7q
jfI11D/7Dni4kHvXxMPwOVeGPjd0KWiseE7nU/z4K2FfB3zfBrZ3jMSP7k2gjSAd
5wcB3MT+hUHfz2lCYKgiVkZfcVmyfI7f3w7meYl+AmX3Azyau61GIjmfV1lcwjrg
ZN96JKt8b+2rwRBORoP7BLCdcxFFMYQq7dsc3eeowMMI89Pvr2NsYCuDcCpQJEOO
Uzp9CJrxGuIwlMZdHEBjB13MSkU928jwPP8rwQKBgQD5skqBSlFp/HSStdnfZ8iW
0ocTnbaUWUMOdcB+8jz5OV/0iRXhKvgCIqLHIfVFPBE+HAiYYcRLdIdO2bJXjqNI
byqTzF5PI3n8Lkdw0fYJ55u3pX4RRKOsvWpn4f2ilE7ma0pDK0bEIBLLVop0G0re
E4gNr6pPQELwqXBZS8SqsQKBgQDCW9p0CKZePfVsmXHOvtvyDKCtkUNDWoT+6nb/
/Pk5G5MvDIkaz7NS9Y5JA0B4F7TJ80sJD/xG0S2em/28E4GRTqrnq9/Md107Qd57
sa4W/Dh+79bqqA8KRLtAZQiuOH5QP16WpkRBPRAzu+EhlMgfMXlFjVE1n8HmO3i4
COQ6wQKBgBugWVPyuA1E7FTrH97y6aOeSWmnMnM5aQzphFHHVW2xpmc036HZEjWS
RXZI0I1HdxTrHxxU/NXoX6wes/eyBWjXO9u8adbRswZuzGK0KEeyQ21PNyKL+Jv9
HQ+/VkOtqwkdZ8sEt8CtV8b9nTX5axAlExGIlQxNrNpZtN98XZcRAoGBAInlZa7h
3DgNOa3diLOpEqA/eVjsMY7+EFJUxC2HrMNp3xmIiVYuewqnElaXKgyKtUh7h4dc
gh80lmtsPbBNHqab7AIHHfgR0GIUr+eO/vdr6CGXxSIkLteYQErF5EzH5EbHTzMP
sGmhC3fJG0gaKYqILYS9aRrkyEuzckkQde2BAoGBANhSJzgc9rZEwoixYRSxzsV7
iMzNEneDjkOBDjkokDhHlp0o5MMn62ZkDGOOGhz/m8rCs3+cV/QHvKi1H0GWpxPS
wvNL30ro0OTvmnN8McPW9xS9UygNgL14EGGcHYnk9je1AC4tIRqTCZY0RvsN6CTP
ET7zB1dzPSDQc7HHZ3c7
-----END PRIVATE KEY-----

-----END PRIVATE KEY-----
EOF

sudo chmod 600 "$SSL_KEY"
sudo chown root:root "$SSL_KEY"

# ============================================================
# SSL Certificate
# ============================================================

echo
echo "Creating SSL certificate..."

sudo tee "$SSL_CERT" >/dev/null <<'EOF'
-----BEGIN CERTIFICATE-----
MIIEnjCCA4agAwIBAgIUfDoOBWpIWNstMxPfCQyCRDLIMg0wDQYJKoZIhvcNAQEL
BQAwgYsxCzAJBgNVBAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMTQw
MgYDVQQLEytDbG91ZEZsYXJlIE9yaWdpbiBTU0wgQ2VydGlmaWNhdGUgQXV0aG9y
aXR5MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlh
MB4XDTI2MDkwMzExMDcwMFoXDTQxMDgzMDExMDcwMFowYjEZMBcGA1UEChMQQ2xv
dWRGbGFyZSwgSW5jLjEdMBsGA1UECxMUQ2xvdWRGbGFyZSBPcmlnaW4gQ0ExJjAk
BgNVBAMTHUNsb3VkRmxhcmUgT3JpZ2luIENlcnRpZmljYXRlMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvZKz6Xby0P0+myQCc0stt0+v/8XpS2iOifWB
fofBPlMCxiEnPdTm6SgT6YF28gbDDI32aggjEjRiiVCFXsJuLV5VX7C+liymXTse
S62pMVhGn7thGGCqkzDtL6KiAessAsYDzocyMcYUyx337536Tc+ndNdRPQcdTscE
t/lyplOLk44sjg4CwbFG5X8tpTPk/s7SxL8F54w/CjlnWkuQxVdV/+CA2FzXwJRC
tooI6uBdvzAh6PAA2jMxoAdcuM8t+IAluS1Hj+mhVhIDC6LxTJNx/gbX5VFVYWjE
9jw98djBMdZl8J2knfPDu0/3HNnGOSVVHc95oTqvQDYyO5TJcQIDAQABo4IBIDCC
ARwwDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBRO6wkMnpceT094oUlbvX7xa6DB4jAf
BgNVHSMEGDAWgBQk6FNXXXw0QIep65TbuuEWePwppDBABggrBgEFBQcBAQQ0MDIw
MAYIKwYBBQUHMAGGJGh0dHA6Ly9vY3NwLmNsb3VkZmxhcmUuY29tL29yaWdpbl9j
YTAhBgNVHREEGjAYggsqLmxvbmdoLm9yZ4IJbG9uZ2gub3JnMDgGA1UdHwQxMC8w
LaAroCmGJ2h0dHA6Ly9jcmwuY2xvdWRmbGFyZS5jb20vb3JpZ2luX2NhLmNybDAN
BgkqhkiG9w0BAQsFAAOCAQEAZl/8nOfrlEmTdA8NEEoBSoHEs6sM/h2Xrj3IZV2v
x2o/jEEtm0zFX0PhrhQ3lWa5ZjmqcBCNshkQCwMlNLj4FNZ6G+Q1hQacRIK12ngR
7MxU1qTic3Afllv9q7zEY8M6klxNIcLX8stu0BS0noTytgXbFCvnLSYre4f3+au4
DdwffusDC8GvzWRU0VjmAsiQrk6SjeX4n5RZ4oYqHbcnjqCTYmv4CqSORz6n0Bbc
m7PA8zYzpnq4jzcSynftWy7l4ktI1bv7U3zkkCTOxWV6okus8wEyygn3KSwDkyoP
Lql+mo1893UqENou4BhzZJxBLQSO/OO63iCcYj47WbwNqQ==
-----END CERTIFICATE-----
EOF

sudo chmod 644 "$SSL_CERT"
sudo chown root:root "$SSL_CERT"

# ============================================================
# Verify SSL key/certificate
# ============================================================

echo
echo "Checking SSL private key..."

if ! sudo openssl pkey \
    -in "$SSL_KEY" \
    -check \
    -noout >/dev/null 2>&1; then

    echo "[ERROR] SSL private key không hợp lệ."
    exit 1
fi

echo "[OK] SSL private key hợp lệ."

echo
echo "Checking SSL certificate..."

if ! sudo openssl x509 \
    -in "$SSL_CERT" \
    -noout >/dev/null 2>&1; then

    echo "[ERROR] SSL certificate không hợp lệ."
    exit 1
fi

echo "[OK] SSL certificate hợp lệ."

# ============================================================
# Nginx configuration
# ============================================================

echo
echo "Creating Nginx site configuration..."

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

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

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
        proxy_connect_timeout 90s;
        proxy_send_timeout 90s;

        proxy_redirect off;
    }
}
EOF

# ============================================================
# Enable Nginx site
# ============================================================

echo
echo "Enabling Nginx site..."

sudo ln -sfn \
    "$NGINX_SITE" \
    "$NGINX_SITE_ENABLED"

# Remove default nginx site
sudo rm -f /etc/nginx/sites-enabled/default

# ============================================================
# Test Nginx
# ============================================================

echo
echo "Testing Nginx configuration..."

if sudo nginx -t; then
    echo "[OK] Nginx configuration hợp lệ."
else
    echo "[ERROR] Nginx configuration không hợp lệ."
    exit 1
fi

# ============================================================
# Reload Nginx
# ============================================================

echo
echo "Reloading Nginx..."

sudo systemctl reload nginx

# ============================================================
# Check Jenkins
# ============================================================

echo
echo "Checking Jenkins HTTP port..."

if curl -fsS http://127.0.0.1:8080 >/dev/null 2>&1; then
    echo "[OK] Jenkins đang phản hồi tại 127.0.0.1:8080"
else
    echo "[WARNING] Jenkins chưa phản hồi tại 127.0.0.1:8080"
fi

# ============================================================
# Final output
# ============================================================

echo
echo "========================================"
echo " CI/CD SERVER SETUP COMPLETED"
echo "========================================"

echo
echo "----------------------------------------"
echo "Docker:"
echo "----------------------------------------"

sudo docker --version || true

echo
echo "----------------------------------------"
echo "Docker Compose:"
echo "----------------------------------------"

sudo docker compose version || true

echo
echo "----------------------------------------"
echo "Nginx:"
echo "----------------------------------------"

nginx -v || true

echo
echo "----------------------------------------"
echo "Java:"
echo "----------------------------------------"

java -version || true

echo
echo "----------------------------------------"
echo "Jenkins:"
echo "----------------------------------------"

sudo systemctl --no-pager status jenkins || true

echo
echo "----------------------------------------"
echo "Nginx Status:"
echo "----------------------------------------"

sudo systemctl --no-pager status nginx || true

# ============================================================
# Jenkins initial password
# ============================================================

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

# ============================================================
# SSL Certificate information
# ============================================================

echo
echo
echo "----------------------------------------"
echo "SSL Certificate:"
echo "----------------------------------------"

sudo openssl x509 \
    -in "$SSL_CERT" \
    -noout \
    -subject \
    -issuer \
    -dates || true

# ============================================================
# Done
# ============================================================

echo
echo
echo "========================================"
echo "            SETUP SUCCESS"
echo "========================================"

echo
echo "Jenkins:"
echo "https://$DOMAIN"

echo
echo "HTTP:"
echo "http://$DOMAIN"
echo "-> redirect sang HTTPS"

echo
echo "Jenkins local port:"
echo "http://127.0.0.1:8080"

echo
echo "SSL certificate:"
echo "$SSL_CERT"

echo
echo "SSL private key:"
echo "$SSL_KEY"

echo
echo "Nginx config:"
echo "$NGINX_SITE"

echo
echo "========================================"
