#!/bin/bash
#
# Raspberry Pi Camera Monitoring - Installation Script
# Tested on: Debian Bookworm (RPi OS 64-bit)
#

set -e

echo "🚀 Raspberry Pi Camera Monitoring - Installer"
echo "=============================================="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please run without sudo. Script will ask for sudo when needed."
    exit 1
fi

# Update system
echo -e "\n📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Motion
echo -e "\n📦 Installing Motion..."
sudo apt install -y motion

# Install web server and PHP
echo -e "\n📦 Installing lighttpd and PHP..."
sudo apt install -y lighttpd php-cgi vnstat

# Enable PHP in lighttpd
echo -e "\n⚙️ Configuring lighttpd..."
sudo lighty-enable-mod fastcgi
sudo lighty-enable-mod fastcgi-php

# Create motion directory
echo -e "\n📁 Creating directories..."
sudo mkdir -p /var/lib/motion
sudo chown motion:motion /var/lib/motion

# Copy configuration files
echo -e "\n📄 Copying configuration files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/motion.conf" ]; then
    sudo cp "$SCRIPT_DIR/motion.conf" /etc/motion/motion.conf
    echo "   ✓ motion.conf installed"
fi

if [ -f "$SCRIPT_DIR/camera.html" ]; then
    sudo cp "$SCRIPT_DIR/camera.html" /var/www/html/
    echo "   ✓ camera.html installed"
fi

if [ -f "$SCRIPT_DIR/stats.php" ]; then
    sudo cp "$SCRIPT_DIR/stats.php" /var/www/html/
    echo "   ✓ stats.php installed"
fi

# Fix Motion systemd service for Bookworm
echo -e "\n⚙️ Configuring Motion systemd service..."
sudo mkdir -p /etc/systemd/system/motion.service.d
cat << 'EOF' | sudo tee /etc/systemd/system/motion.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/motion
EOF
sudo systemctl daemon-reload

# Add www-data to video group
echo -e "\n👤 Configuring permissions..."
sudo usermod -aG video www-data

# Add sudoers entry for vcgencmd
if ! sudo grep -q "www-data.*vcgencmd" /etc/sudoers; then
    echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/vcgencmd" | sudo EDITOR='tee -a' visudo
    echo "   ✓ sudoers configured"
fi

# Configure HTTP Basic Authentication
echo -e "\n🔐 Configuring HTTP Basic Authentication..."

# Copy auth config
if [ -f "$SCRIPT_DIR/lighttpd-auth.conf" ]; then
    sudo cp "$SCRIPT_DIR/lighttpd-auth.conf" /etc/lighttpd/conf-available/20-auth.conf
    echo "   ✓ auth config installed"
fi

# Create .htpasswd file with user credentials
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

# Enable auth module
sudo lighty-enable-mod auth 2>/dev/null || true

# Enable and start services
echo -e "\n🔄 Starting services..."
sudo systemctl enable vnstat lighttpd motion
sudo systemctl restart lighttpd
sudo systemctl start vnstat
sudo systemctl start motion

# Get IP address
IP=$(hostname -I | awk '{print $1}')

echo -e "\n✅ Installation complete!"
echo "=============================================="
echo "📺 Stream URL:     http://$IP:8081"
echo "🌐 Web Panel:      http://$IP/camera.html"
echo "⚙️ Motion Control: http://$IP:8080"
echo "=============================================="
echo ""
echo "🔐 Web panel requires authentication (user: $AUTH_USER)"
echo "   Note: Stream (8081) and Motion Control (8080) are not protected"
echo ""
echo "🔍 Check status with:"
echo "   sudo systemctl status motion"
echo "   sudo journalctl -u motion -f"
