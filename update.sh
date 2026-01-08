#!/bin/bash
#
# Raspberry Pi Camera Monitoring - Update Script
# Updates existing installation with new configuration files
#

set -e

echo "🔄 Raspberry Pi Camera Monitoring - Updater"
echo "=============================================="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please run without sudo. Script will ask for sudo when needed."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if motion is installed
if ! command -v motion &> /dev/null; then
    echo "❌ Motion is not installed. Run install.sh first."
    exit 1
fi

# Update configuration files
echo -e "\n📄 Updating configuration files..."

if [ -f "$SCRIPT_DIR/motion.conf" ]; then
    sudo cp "$SCRIPT_DIR/motion.conf" /etc/motion/motion.conf
    echo "   ✓ motion.conf updated"
fi

if [ -f "$SCRIPT_DIR/camera.html" ]; then
    sudo cp "$SCRIPT_DIR/camera.html" /var/www/html/
    echo "   ✓ camera.html updated"
fi

if [ -f "$SCRIPT_DIR/stats.php" ]; then
    sudo cp "$SCRIPT_DIR/stats.php" /var/www/html/
    echo "   ✓ stats.php updated"
fi

# Update auth config if exists
if [ -f "$SCRIPT_DIR/lighttpd-auth.conf" ]; then
    sudo cp "$SCRIPT_DIR/lighttpd-auth.conf" /etc/lighttpd/conf-available/20-auth.conf
    echo "   ✓ lighttpd-auth.conf updated"

    # Enable auth module if not enabled
    if [ ! -L /etc/lighttpd/conf-enabled/20-auth.conf ]; then
        sudo lighty-enable-mod auth 2>/dev/null || true
        echo "   ✓ auth module enabled"
    fi
fi

# Check if .htpasswd exists, if not create it
if [ ! -f /etc/lighttpd/.htpasswd ]; then
    echo -e "\n🔐 No authentication configured. Setting up now..."
    echo -e "\n📝 Setup authentication credentials:"
    read -p "   Enter username [camera]: " AUTH_USER
    AUTH_USER=${AUTH_USER:-camera}

    while true; do
        read -s -p "   Enter password: " AUTH_PASS
        echo
        read -s -p "   Confirm password: " AUTH_PASS2
        echo
        if [ "$AUTH_PASS" = "$AUTH_PASS2" ]; then
            break
        fi
        echo "   ❌ Passwords don't match. Try again."
    done

    echo "$AUTH_USER:$AUTH_PASS" | sudo tee /etc/lighttpd/.htpasswd > /dev/null
    sudo chmod 600 /etc/lighttpd/.htpasswd
    sudo chown www-data:www-data /etc/lighttpd/.htpasswd
    echo "   ✓ credentials configured"
fi

# Restart services
echo -e "\n🔄 Restarting services..."
sudo systemctl restart lighttpd
sudo systemctl restart motion

# Get IP address
IP=$(hostname -I | awk '{print $1}')

echo -e "\n✅ Update complete!"
echo "=============================================="
echo "📺 Stream URL:     http://$IP:8081"
echo "🌐 Web Panel:      http://$IP/camera.html"
echo "⚙️ Motion Control: http://$IP:8080"
echo "=============================================="
echo ""
echo "🔍 Check status with:"
echo "   sudo systemctl status motion"
echo "   sudo systemctl status lighttpd"
