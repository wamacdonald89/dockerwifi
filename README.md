# DockerWIFI

## Summary

DockerWIFI is a dockerized hostapd/dhcp/iptables bundle that makes setting up and deploying software-based access points (APs) easy. 

## Dependencies

Docker

## Setup

```bash
git clone https://github.com/wamacdonald89/dockerwifi.git
```

## Run

```bash
sudo ./dockerwifi -i <interface>
```

## Notes

- Currently defaults to WPA2 access point
- Different configurations may be launched by modifying the configs/default.conf file as you would hostapd.conf
- TODO: Support multiple configurations with different config files and command line arguments

