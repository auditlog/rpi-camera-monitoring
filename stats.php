<?php
/**
 * Real-time system statistics for Raspberry Pi
 * Returns JSON with CPU temperature and network transfer rates
 * 
 * File: /var/www/html/stats.php
 * 
 * Requirements:
 * - sudo usermod -aG video www-data
 * - Add to sudoers: www-data ALL=(ALL) NOPASSWD: /usr/bin/vcgencmd
 */

header('Content-Type: application/json');
header('Cache-Control: no-cache');

// CPU Temperature
$temp = shell_exec('sudo vcgencmd measure_temp 2>&1');
preg_match('/temp=([\d.]+)/', $temp, $m);

// Active network interface
$iface = trim(shell_exec("ip route | grep default | head -1 | awk '{print \$5}'"));

// Real-time transfer measurement (0.5s sample)
$rx1 = @file_get_contents("/sys/class/net/$iface/statistics/rx_bytes");
$tx1 = @file_get_contents("/sys/class/net/$iface/statistics/tx_bytes");
usleep(500000); // 0.5 seconds
$rx2 = @file_get_contents("/sys/class/net/$iface/statistics/rx_bytes");
$tx2 = @file_get_contents("/sys/class/net/$iface/statistics/tx_bytes");

// Calculate speed (bytes/s -> kbit/s)
$rx_speed = (($rx2 - $rx1) * 2 * 8) / 1000;
$tx_speed = (($tx2 - $tx1) * 2 * 8) / 1000;

/**
 * Format speed to human readable
 */
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
    'iface' => $iface,
    'timestamp' => date('Y-m-d H:i:s')
]);
