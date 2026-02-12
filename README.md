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
| `--config` | Path to a custom hostapd.conf template |
| `-h`, `--help` | Show help |
| `--version` | Print version |

### Custom Configuration

The `--config` option accepts a hostapd.conf template file. The following variables are substituted automatically via `envsubst`:

| Variable | Description |
|---|---|
| `${IFACE}` | Wireless interface name |
| `${HW_MODE}` | Hardware mode (`a` for 5GHz, `g` for 2.4GHz) |
| `${SSID}` | Network name |
| `${CHANNEL}` | Channel number |
| `${PASSPHRASE}` | WPA passphrase |

See `configs/default.conf` for the default template.

### Network Defaults

| Setting | Value |
|---|---|
| AP IP Address | `192.168.254.1` |
| Subnet | `192.168.254.0/24` |
| DHCP Range | `192.168.254.100` - `192.168.254.200` |
| DNS | `8.8.8.8`, `8.8.4.4` |

## Notes

- Currently supports WPA2 by default but is fully configurable by providing a custom hostapd.conf template
- NetworkManager is automatically stopped when DockerWIFI starts and restored when it exits
- The container runs with `NET_ADMIN` and `NET_RAW` capabilities (not full `--privileged`)
