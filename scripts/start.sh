#!/bin/bash -e
set -e
# Set colors
# TODO Figure out why colors don't work :(
MAGENTA='\e[0;35m'
RED='\e[0;31m'
GREEN='\e[0;32m'
BLUE='\e[0;34m'
NC='\e[0m'

# unblock wlan
rfkill unblock wlan

echo -e "[+] Configuring ${GREEN}${IFACE}${NC} as an Access Point..."
ip link set ${IFACE} up
ip addr flush dev ${IFACE}
ip addr add ${AP_ADDR}/24 dev ${IFACE}
echo -e "${BLUE}[INFO]${NC} IP Address: ${GREEN}${AP_ADDR}/24${NC}"

echo "[+] Setting IPTABLES for all interfaces..."
iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -j MASQUERADE > /dev/null 2>&1 || true
iptables -t nat -A POSTROUTING -s ${SUBNET}/24 -j MASQUERADE
echo -e "${BLUE}[INFO]${NC} NAT POSTROUTING ${GREEN}${SUBNET}/24$ MASQUERADE${NC}"

echo "[+] Configuring hostapd..."
export IFACE=${IFACE}
cat /etc/hostapd.conf | envsubst > /tmp/hostapd.conf
cp /tmp/hostapd.conf /etc/hostapd.conf
rm /tmp/hostapd.conf


echo "[+] Configuring DHCP server..."

cat > "/etc/dhcp/dhcpd.conf" <<EOF
option domain-name-servers 8.8.8.8, 8.8.4.4;
option subnet-mask 255.255.255.0;
option routers ${AP_ADDR};
subnet ${SUBNET} netmask 255.255.255.0 {
  range ${SUBNET::-1}100 ${SUBNET::-1}200;
}
EOF
echo -e "${BLUE}[INFO]${NC} DNS: ${GREEN}8.8.8.8 8.8.4.4${NC}"
echo -e "${BLUE}[INFO]${NC} NETMASK: ${GREEN}255.255.255.0${NC}"
echo -e "${BLUE}[INFO]${NC} ROUTERS: ${GREEN}${AP_ADDR}${NC}"
echo -e "${BLUE}[INFO]${NC} SUBNET: ${GREEN}${SUBNET} RANGE: 100-200${NC}"


echo "[+] Starting DHCP server .."
dhcpd ${IFACE} &> /dev/null

echo "Starting HostAP daemon ..."
echo -e "${BLUE}[INFO]${NC} Press CTRL-C to stop..."
/usr/sbin/hostapd /etc/hostapd.conf
