#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear

echo "========================================"
echo "       AWS DEVOPS LAB SETUP"
echo "========================================"
echo
echo "1) SERVER APP"
echo "   Docker + Git + project + Compose + Nginx"
echo
echo "2) SERVER CI/CD"
echo "   Docker + Nginx + Jenkins"
echo
echo "0) Exit"
echo

read -rp "Lựa chọn: " choice

case "$choice" in
    1)
        bash "$SCRIPT_DIR/scripts/server-app.sh"
        ;;
    2)
        bash "$SCRIPT_DIR/scripts/server-cicd.sh"
        ;;
    0)
        echo "Thoát."
        exit 0
        ;;
    *)
        echo "Lựa chọn không hợp lệ."
        exit 1
        ;;
esac
