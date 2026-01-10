# Copilot Instructions - RPi Camera Monitoring

## Project Overview
A Raspberry Pi 4 video monitoring server using Motion + Camera Module v3 (IMX708). The project provides shell scripts for automated installation and a web panel with real-time stats.

## Architecture

### Component Stack
```
┌─────────────────────┐     ┌────────────────────┐
│   camera.html       │────▶│   stats.php (JSON) │
│   (Frontend)        │     │   (PHP backend)    │
└─────────────────────┘     └────────────────────┘
         │                           │
         ▼                           ▼
┌─────────────────────┐     ┌────────────────────┐
│  Motion (port 8081) │     │  vcgencmd + sysfs  │
│  Video stream       │     │  System stats      │
└─────────────────────┘     └────────────────────┘
```

### Key Files
| File | Location on RPi | Purpose |
|------|-----------------|---------|
| `motion.conf` | `/etc/motion/motion.conf` | Motion daemon config |
| `camera.html` | `/var/www/html/` | Web dashboard |
| `stats.php` | `/var/www/html/` | Real-time stats API (JSON) |
| `lighttpd-auth.conf` | `/etc/lighttpd/conf-available/20-auth.conf` | HTTP Basic Auth |

### Ports
- **80** - lighttpd web server (camera.html, stats.php)
- **8080** - Motion webcontrol
- **8081** - Motion MJPEG stream

## Development Workflow

### Installation Scripts
Three scripts handle deployment:
1. `download.sh` - Fetches files from GitHub, auto-detects install/update
2. `install.sh` - Full installation (packages, permissions, systemd)
3. `update.sh` - Updates config files only, preserves credentials

### Testing Changes
Files are deployed to the RPi via `update.sh`. To test:
```bash
# On RPi: Pull latest and update
cd ~/rpi-camera-monitoring && ./update.sh
```

### Service Management
```bash
sudo systemctl restart motion    # Apply motion.conf changes
sudo systemctl restart lighttpd  # Apply PHP/HTML changes
```

## Conventions

### Shell Scripts
- Start with `set -e` for fail-fast behavior
- Check for root: scripts run as user, use `sudo` for privileged commands
- Use emoji prefixes in output: 📦 📄 ✓ ❌ ⚙️ 🔐

### Configuration Files
- Motion config uses `property value` format (no `=`)
- Comments start with `#`
- Include location hint: `# File: /etc/motion/motion.conf`

### PHP (stats.php)
- Return JSON with `Content-Type: application/json`
- Sanitize all shell command inputs (see `preg_match` for interface validation)
- Include PHPDoc header explaining requirements and permissions

### HTML/JS (camera.html)
- Dark theme (#1a1a1a background)
- Monospace font, green (#4CAF50) for headers
- Fetch stats every 5 seconds from `/stats.php`
- Auto-detect stream URL using `window.location.hostname`

## Critical Requirements

### Permissions (stats.php needs these on RPi)
```bash
sudo usermod -aG video www-data
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/vcgencmd" | sudo EDITOR='tee -a' visudo
```

### Motion Systemd Override (Debian Bookworm)
The default service uses `libcamerify` which may not exist. Scripts create override at `/etc/systemd/system/motion.service.d/override.conf`.

### Supported Resolutions (16:9 for full FOV)
- 1536x864 @ 30fps
- 2304x1296 @ 30fps (recommended)
- 4608x2592 @ 30fps

## Branch Strategy
- `main` - stable releases
- `develop` - active development (download.sh points here)

## External Dependencies
- Motion 4.7+ with V4L2 support
- lighttpd with PHP CGI (`php-cgi`)
- vnstat for network stats
- vcgencmd for CPU temperature (Raspberry Pi specific)
