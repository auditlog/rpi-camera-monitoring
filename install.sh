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

if [ -f "$SCRIPT_DIR/config/motion.conf" ]; then
    sudo cp "$SCRIPT_DIR/config/motion.conf" /etc/motion/motion.conf
    echo "   ✓ motion.conf installed"
fi

if [ -f "$SCRIPT_DIR/www/camera.html" ]; then
    sudo cp "$SCRIPT_DIR/www/camera.html" /var/www/html/
    echo "   ✓ camera.html installed"
fi

if [ -f "$SCRIPT_DIR/www/stats.php" ]; then
    sudo cp "$SCRIPT_DIR/www/stats.php" /var/www/html/
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
echo "⚠️  Remember to update IP address in camera.html if needed!"
echo ""
echo "🔍 Check status with:"
echo "   sudo systemctl status motion"
echo "   sudo journalctl -u motion -f"
