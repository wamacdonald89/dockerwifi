# DockerWIFI

## Summary

DockerWIFI is a dockerized hostapd/dhcp/iptables bundle that makes setting up and deploying software-based access points (APs) easy.

## How It Works

DockerWIFI runs hostapd, a DHCP server, and iptables NAT rules inside a Docker container with host networking. The main script (`dockerwifi`) runs on the host and handles:

- Validating the wireless interface and its AP mode support
- Stopping NetworkManager to avoid conflicts
- Building and launching the Docker container

Inside the container (`scripts/start.sh`):

- Configures the wireless interface with a static IP (default: `192.168.254.1/24`)
- Enables IP forwarding and sets up NAT masquerading
- Starts the DHCP server (range: `.100` - `.200` on the AP subnet)
- Launches hostapd with the provided configuration

When the container stops (Ctrl+C), cleanup handlers restore iptables rules, IP configuration, and NetworkManager on the host.

## Requirements

- Linux with a wireless card that supports AP mode
- Docker
- Root privileges (`sudo`)

To check if your card supports AP mode:

```bash
iw list | grep -A 10 "Supported interface modes" | grep AP
```

## Setup

```bash
git clone https://github.com/wamacdonald89/dockerwifi.git
```

## Run

```bash
sudo ./dockerwifi -i <interface> -c 36 --ssid dockerwifi --passphrase s3cureP@ss
```

### Arguments

| Argument | Description |
|---|---|
| `-i`, `--interface` | Wireless interface to use (required) |
| `-c`, `--channel` | Channel number (default: 1) |
| `--ssid` | Network name (default: dockerwifi) |
| `--passphrase` | WPA passphrase (default: password123 - change this!) |
| `--wifi` | Wi-Fi generation: `4`, `5`, or `6` (see below) |
| `--wpa3` | Enable WPA3-SAE authentication |
| `--config` | Path to a custom hostapd.conf template |
| `-h`, `--help` | Show help |
| `--version` | Print version |

### Wi-Fi Generations

Use the `--wifi` flag to select a modern Wi-Fi standard:

| Flag | Standard | Band | Channel Width | Config |
|---|---|---|---|---|
| *(none)* | 802.11g (legacy) | 2.4GHz | 20MHz | `configs/default.conf` |
| `--wifi 4` | 802.11n (Wi-Fi 4) | 2.4GHz or 5GHz | 20/40MHz | `configs/wifi4.conf` |
| `--wifi 5` | 802.11ac (Wi-Fi 5) | 5GHz only | 80MHz | `configs/wifi5.conf` |
| `--wifi 6` | 802.11ax (Wi-Fi 6) | 5GHz only | 80MHz | `configs/wifi6.conf` |

`--wifi 5` and `--wifi 6` require a 5GHz channel (channel > 14). The VHT center frequency is computed automatically from the selected channel.

**Examples:**

```bash
# Wi-Fi 4 on 2.4GHz
sudo ./dockerwifi -i wlan0 -c 6 --wifi 4 --passphrase s3cureP@ss

# Wi-Fi 5 on 5GHz channel 36
sudo ./dockerwifi -i wlan0 -c 36 --wifi 5 --passphrase s3cureP@ss

# Wi-Fi 6 with WPA3 on 5GHz channel 36
sudo ./dockerwifi -i wlan0 -c 36 --wifi 6 --wpa3 --passphrase s3cureP@ss
```

### WPA3 Support

The `--wpa3` flag switches authentication from WPA2-PSK to WPA3-SAE:

- Replaces `wpa_key_mgmt=WPA-PSK` with `wpa_key_mgmt=SAE`
- Enables mandatory Management Frame Protection (`ieee80211w=2`)
- Uses `sae_password` instead of `wpa_passphrase`

This works with any config (default, `--wifi`, or `--config`). Note that some older clients do not support WPA3. If you need backwards compatibility, use a custom config with WPA2/WPA3 transition mode (`wpa_key_mgmt=WPA-PSK SAE` and `ieee80211w=1`).

### Custom Configuration

The `--config` option accepts a hostapd.conf template file. The following variables are substituted automatically via `envsubst`:

| Variable | Description |
|---|---|
| `${IFACE}` | Wireless interface name |
| `${HW_MODE}` | Hardware mode (`a` for 5GHz, `g` for 2.4GHz) |
| `${SSID}` | Network name |
| `${CHANNEL}` | Channel number |
| `${PASSPHRASE}` | WPA passphrase |
| `${VHT_CENTER_FREQ}` | VHT center frequency index (auto-computed for 80MHz channels) |

See `configs/default.conf` for the simplest template or `configs/wifi6.conf` for a full-featured example.

### Network Defaults

| Setting | Value |
|---|---|
| AP IP Address | `192.168.254.1` |
| Subnet | `192.168.254.0/24` |
| DHCP Range | `192.168.254.100` - `192.168.254.200` |
| DNS | `8.8.8.8`, `8.8.4.4` |

## Notes

- The default config uses legacy 802.11g. Use `--wifi 4/5/6` for modern standards.
- NetworkManager is automatically stopped when DockerWIFI starts and restored when it exits.
- The container runs with `NET_ADMIN` and `NET_RAW` capabilities (not full `--privileged`).
- Wi-Fi 6 (802.11ax) requires hostapd 2.10+, which ships with Ubuntu 22.04.
- Your wireless card's firmware and driver must support the selected Wi-Fi generation.
