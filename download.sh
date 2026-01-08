#!/bin/bash
#
# Raspberry Pi Camera Monitoring - Download & Update Script
# Downloads latest files from GitHub and runs update
#
# Usage: curl -sL https://raw.githubusercontent.com/auditlog/rpi-camera-monitoring/develop/download.sh | bash
#    or: wget -qO- https://raw.githubusercontent.com/auditlog/rpi-camera-monitoring/develop/download.sh | bash
#

set -e

REPO="auditlog/rpi-camera-monitoring"
BRANCH="develop"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"
DEST_DIR="$HOME/rpi-camera-monitoring"

echo "🔄 Raspberry Pi Camera Monitoring - Downloader"
echo "=============================================="
echo "Repository: $REPO"
echo "Branch:     $BRANCH"
echo "Target:     $DEST_DIR"
echo ""

# Create destination directory
mkdir -p "$DEST_DIR"
cd "$DEST_DIR"

# Files to download
FILES=(
    "camera.html"
    "stats.php"
    "motion.conf"
    "install.sh"
    "update.sh"
    "lighttpd-auth.conf"
)

echo "📥 Downloading files..."
for file in "${FILES[@]}"; do
    if wget -q -O "$file" "$BASE_URL/$file"; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file (failed)"
    fi
done

# Make scripts executable
chmod +x install.sh update.sh 2>/dev/null || true

echo ""
echo "✅ Download complete!"
echo "=============================================="
echo "Files saved to: $DEST_DIR"
echo ""

# Check if this is first install or update
if command -v motion &> /dev/null && [ -f /var/www/html/camera.html ]; then
    echo "📦 Existing installation detected."
    read -p "Run update.sh now? [Y/n]: " RUN_UPDATE
    RUN_UPDATE=${RUN_UPDATE:-Y}
    if [[ "$RUN_UPDATE" =~ ^[Yy]$ ]]; then
        ./update.sh
    fi
else
    echo "📦 No existing installation detected."
    read -p "Run install.sh now? [Y/n]: " RUN_INSTALL
    RUN_INSTALL=${RUN_INSTALL:-Y}
    if [[ "$RUN_INSTALL" =~ ^[Yy]$ ]]; then
        ./install.sh
    fi
fi
