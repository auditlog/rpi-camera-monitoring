# 📷 Raspberry Pi Camera Monitoring with Motion

Konfiguracja serwera monitoringu wideo na Raspberry Pi 4 z użyciem Motion + Camera Module v3 (IMX708).

## 📋 Spis treści

- [Wymagania sprzętowe](#-wymagania-sprzętowe)
- [Specyfikacja systemu](#-specyfikacja-systemu)
- [Instalacja](#-instalacja)
- [Konfiguracja Motion](#️-konfiguracja-motion)
- [Panel webowy ze statystykami](#-panel-webowy-ze-statystykami)
- [Diagnostyka](#-diagnostyka)
- [Dostęp](#-dostęp)
- [Rozwiązywanie problemów](#-rozwiązywanie-problemów)

## 🔧 Wymagania sprzętowe

| Komponent | Specyfikacja |
|-----------|--------------|
| Raspberry Pi | 4 Model B (testowane) |
| Kamera | Camera Module v3 (IMX708) |
| System | Debian GNU/Linux 12 (Bookworm) |
| Kernel | 6.12.47+rpt-rpi-v8 aarch64 |
| Karta SD | 16GB+ |
| Zasilanie | 5V/3A USB-C |

## 📊 Specyfikacja systemu

### Kamera IMX708

- Natywna rozdzielczość: 4608x2592 (10-bit)
- Kąt widzenia (FOV): 66° (standardowa) / 120° (Wide)
- Dostępne tryby:
  - 1536x864 @ 30fps
  - 2304x1296 @ 30fps
  - 4608x2592 @ 30fps

### Aktualna konfiguracja

- Rozdzielczość streamu: 2304x1296 (16:9, pełne FOV)
- Framerate: 25fps
- Kodek: H264 (sprzętowy V4L2 M2M)
- Jakość streamu: 50%
- Hostname: `rpi4las`

## 📦 Instalacja

### 1. Aktualizacja systemu

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Instalacja Motion

```bash
sudo apt install motion -y
```

### 3. Instalacja narzędzi pomocniczych

```bash
sudo apt install vnstat lighttpd php-cgi -y
```

### 4. Konfiguracja lighttpd z PHP

```bash
sudo lighty-enable-mod fastcgi
sudo lighty-enable-mod fastcgi-php
sudo systemctl restart lighttpd
```

### 5. Włączenie serwisów

```bash
sudo systemctl enable vnstat lighttpd motion
sudo systemctl start vnstat lighttpd
```

## ⚙️ Konfiguracja Motion

### Modyfikacja serwisu systemd (wymagane dla Bookworm)

Na Debian Bookworm domyślny serwis używa `libcamerify`, który może nie istnieć. Obejście:

```bash
sudo systemctl edit motion
```

Dodaj:

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/motion
```

```bash
sudo systemctl daemon-reload
```

### Główny plik konfiguracji

```bash
sudo nano /etc/motion/motion.conf
```

### Pełna konfiguracja

```ini
# === Podstawowe ===
daemon off
setup_mode off
log_level 6

# === Urządzenie kamery ===
video_device /dev/video0

# === Rozdzielczość i FPS ===
# 16:9 dla pełnego FOV Camera Module v3
width 2304
height 1296
framerate 25

# === Overlay tekstu ===
text_scale 3
text_left %Y-%m-%d %T\nHost: %{host}
text_right FPS: %{fps}\nMotion: %q

# === Detekcja ruchu ===
emulate_motion off
threshold 1000
despeckle_filter EedDl
minimum_motion_frames 1
event_gap 60
pre_capture 3
post_capture 0

# === Zdjęcia ===
picture_output off
picture_filename %Y%m%d%H%M%S-%q

# === Nagrywanie wideo ===
movie_output on
movie_max_time 60
movie_quality 75
movie_codec h264_v4l2m2m
movie_filename %t-%v-%Y%m%d%H%M%S

# === Streaming ===
stream_quality 50
stream_maxrate 25
stream_port 8081
stream_localhost off

# === Webcontrol ===
webcontrol_port 8080
webcontrol_localhost off
webcontrol_parms 0

# === Katalog nagrań ===
target_dir /var/lib/motion
```

### Utworzenie katalogu nagrań

```bash
sudo mkdir -p /var/lib/motion
sudo chown motion:motion /var/lib/motion
```

### Uruchomienie Motion

```bash
sudo systemctl start motion
sudo systemctl status motion
```

## 🌐 Panel webowy ze statystykami

Panel wyświetla stream z kamery oraz statystyki w czasie rzeczywistym (temperatura CPU, transfer sieciowy).

### Strona HTML

```bash
sudo nano /var/www/html/camera.html
```

```html
<!DOCTYPE html>
<html>
<head>
    <title>Camera Monitor - rpi4las</title>
    <style>
        body { background: #1a1a1a; color: #fff; font-family: monospace; margin: 20px; }
        .container { display: flex; gap: 20px; flex-wrap: wrap; }
        .stream { border: 2px solid #333; max-width: 100%; }
        .stats { background: #222; padding: 15px; border-radius: 5px; min-width: 200px; }
        .stats div { margin: 10px 0; }
        .label { color: #888; }
        h2 { color: #4CAF50; }
    </style>
</head>
<body>
    <h2>📷 rpi4las</h2>
    <div class="container">
        <img class="stream" src="http://10.0.1.26:8081" alt="Camera stream">
        <div class="stats">
            <div><span class="label">Status:</span> <span id="status">Loading...</span></div>
            <div><span class="label">Temp:</span> <span id="temp">-</span></div>
            <div><span class="label">RX:</span> <span id="rx">-</span></div>
            <div><span class="label">TX:</span> <span id="tx">-</span></div>
            <div><span class="label">Interface:</span> <span id="iface">-</span></div>
            <div><span class="label">Updated:</span> <span id="time">-</span></div>
        </div>
    </div>
    <script>
        async function updateStats() {
            try {
                const res = await fetch('/stats.php');
                const data = await res.json();
                document.getElementById('status').textContent = '🟢 Online';
                document.getElementById('temp').textContent = data.temp;
                document.getElementById('rx').textContent = data.rx;
                document.getElementById('tx').textContent = data.tx;
                document.getElementById('iface').textContent = data.iface;
                document.getElementById('time').textContent = new Date().toLocaleTimeString();
            } catch(e) {
                document.getElementById('status').textContent = '🔴 Error';
            }
        }
        updateStats();
        setInterval(updateStats, 5000);
    </script>
</body>
</html>
```

### Skrypt PHP ze statystykami real-time

```bash
sudo nano /var/www/html/stats.php
```

```php
<?php
header('Content-Type: application/json');

// Temperatura CPU
$temp = shell_exec('sudo vcgencmd measure_temp 2>&1');
preg_match('/temp=([\d.]+)/', $temp, $m);

// Aktywny interfejs sieciowy
$iface = trim(shell_exec("ip route | grep default | head -1 | awk '{print \$5}'"));

// Transfer real-time (pomiar 0.5s)
$rx1 = file_get_contents("/sys/class/net/$iface/statistics/rx_bytes");
$tx1 = file_get_contents("/sys/class/net/$iface/statistics/tx_bytes");
usleep(500000);
$rx2 = file_get_contents("/sys/class/net/$iface/statistics/rx_bytes");
$tx2 = file_get_contents("/sys/class/net/$iface/statistics/tx_bytes");

// Oblicz prędkość (bytes/s -> kbit/s)
$rx_speed = (($rx2 - $rx1) * 2 * 8) / 1000;
$tx_speed = (($tx2 - $tx1) * 2 * 8) / 1000;

function formatSpeed($kbits) {
    if ($kbits > 1000) {
        return round($kbits / 1000, 2) . ' Mbit/s';
    }
    return round($kbits, 1) . ' kbit/s';
}

echo json_encode([
    'temp' => ($m[1] ?? '?') . '°C',
    'rx' => formatSpeed($rx_speed),
    'tx' => formatSpeed($tx_speed),
    'iface' => $iface
]);
```

### Konfiguracja uprawnień

```bash
# Dodaj www-data do grupy video
sudo usermod -aG video www-data

# Zezwól na vcgencmd bez hasła
sudo visudo
```

Dodaj na końcu pliku sudoers:

```
www-data ALL=(ALL) NOPASSWD: /usr/bin/vcgencmd
```

```bash
# Restart lighttpd
sudo systemctl restart lighttpd
```

## 🔍 Diagnostyka

### Sprawdzenie statusu usług

```bash
sudo systemctl status motion
sudo systemctl status lighttpd
sudo systemctl status vnstat
```

### Logi Motion

```bash
sudo journalctl -u motion -n 50
sudo journalctl -u motion -f  # follow
```

### Test kamery

```bash
rpicam-hello --list-cameras
```

### Sprawdzenie portów

```bash
sudo ss -tlnp | grep -E "8080|8081|80"
```

### Test streamu

```bash
curl -I http://localhost:8081
```

### Test statystyk

```bash
curl http://localhost/stats.php
```

## 📡 Dostęp

| Usługa | URL |
|--------|-----|
| Stream video (MJPEG) | `http://10.0.1.26:8081` |
| Panel webowy | `http://10.0.1.26/camera.html` |
| Webcontrol Motion | `http://10.0.1.26:8080` |

> **Uwaga:** Zamień `10.0.1.26` na aktualny adres IP Raspberry Pi (`hostname -I`)

## 🐛 Rozwiązywanie problemów

| Problem | Przyczyna | Rozwiązanie |
|---------|-----------|-------------|
| `ERR_CONNECTION_REFUSED` | Stream nasłuchuje tylko lokalnie | Ustaw `stream_localhost off` |
| `No cameras available` | Kamera nie wykryta | Sprawdź taśmę CSI, reboot |
| `libcamerify not found` | Brak wrappera libcamera | Edytuj serwis systemd (patrz wyżej) |
| `Permission denied` dla nagrań | Brak uprawnień katalogu | `sudo chown motion:motion /var/lib/motion` |
| Obraz przycięty po bokach | Zły aspect ratio | Użyj rozdzielczości 16:9 |
| Temperatura 100°C w stats | Brak uprawnień vcgencmd | Dodaj www-data do grupy video |
| `800x6000` w logach | Literówka w config | Popraw height na np. 600 lub 720 |

## 🔄 Przydatne komendy

```bash
# Restart Motion
sudo systemctl restart motion

# Podgląd temperatury
vcgencmd measure_temp

# Transfer sieciowy
vnstat

# Real-time transfer
vnstat -tr 2

# Lista urządzeń video
v4l2-ctl --list-devices

# Dostępne rozdzielczości
v4l2-ctl -d /dev/video0 --list-formats-ext
```

## 📚 Źródła

- [Motion Project](https://github.com/Motion-Project/motion)
- [PiMyLifeUp Tutorial](https://pimylifeup.com/raspberry-pi-webcam-server/)
- [Raspberry Pi Camera Documentation](https://www.raspberrypi.com/documentation/computers/camera_software.html)
- [Camera Module v3 Datasheet](https://www.raspberrypi.com/documentation/accessories/camera.html)

## 📝 Changelog

- **2026-01-07** - Pierwsza wersja dokumentacji
  - Konfiguracja Motion 4.7.1 na Debian Bookworm
  - Panel webowy z real-time statystykami
  - Sprzętowe kodowanie H264 (V4L2 M2M)

---

*Hostname: rpi4las | Camera: IMX708 | Resolution: 2304x1296@25fps*
