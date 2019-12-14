#!/bin/bash
set -e
# Defaults
HW_MODE=g # a,b,g,n
BAND="2.4GHz"
KEYMGT="PSK"
# Set colors
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

if [ ${CHANNEL} -gt 14 ]; then
  HW_MODE=a
  BAND="5GHz"
fi

# Check for WEP
if grep -q "wep_key" /etc/hostapd.conf
then
  KEYMGT="WEP"
fi

# TODO EAP prep
if [[ $KEYMGT == "EAP" ]]; then
  openssl dhparam 2048 > dhparam.pem
  openssl genrsa -out server.key 2048
  openssl req -new -sha256 -key server.key -out csr.csr
  openssl req -x509 -sha256 -days 365 -key server.key -in csr.csr -out server.pem
  ln -s server.pem ca.pem
fi


echo "[+] Configuring hostapd..."
export IFACE=${IFACE}
export HW_MODE=${HW_MODE}
cat /etc/hostapd.conf | envsubst > /tmp/hostapd.conf
cp /tmp/hostapd.conf /etc/hostapd.conf
rm /tmp/hostapd.conf

SSID=$(cat /etc/hostapd.conf | grep "ssid" | cut -d"=" -f2)
BAND=$(cat /etc/hostapd.conf | grep "hw_mode" | cut -d"=" -f2)
CHANNEL=$(cat /etc/hostapd.conf | grep "channel" | cut -d"=" -f2)
PASSPHRASE=$(cat /etc/hostapd.conf | grep -E "wpa_passphrase|wep_key" | cut -d"=" -f2)

echo "[+] Configuring DHCP server..."

cat > "/etc/dhcp/dhcpd.conf" <<EOF
option domain-name-servers 8.8.8.8, 8.8.4.4;
option subnet-mask 255.255.255.0;
option routers ${AP_ADDR};
subnet ${SUBNET} netmask 255.255.255.0 {
  range ${SUBNET::-1}100 ${SUBNET::-1}200;
}
EOF
echo -e "${BLUE}[INFO]${NC} DNS:\t\t${GREEN}8.8.8.8 8.8.4.4${NC}"
echo -e "${BLUE}[INFO]${NC} NETMASK:\t\t${GREEN}255.255.255.0${NC}"
echo -e "${BLUE}[INFO]${NC} ROUTERS:\t\t${GREEN}${AP_ADDR}${NC}"
echo -e "${BLUE}[INFO]${NC} SUBNET:\t\t${GREEN}${SUBNET} RANGE: 100-200${NC}"


echo "[+] Starting DHCP server .."
dhcpd ${IFACE} &> /dev/null

echo "Starting HostAP daemon ..."
echo -e "${BLUE}[INFO]${NC} Key Mgmt:\t${GREEN}$KEYMGT${NC}"
echo -e "${BLUE}[INFO]${NC} Interface:\t${GREEN}$IFACE${NC}"
echo -e "${BLUE}[INFO]${NC} SSID:\t\t${GREEN}$SSID${NC}"
echo -e "${BLUE}[INFO]${NC} Frequency Band:\t${GREEN}$BAND${NC}"
echo -e "${BLUE}[INFO]${NC} Channel:\t\t${GREEN}$CHANNEL${NC}"
if [ $KEYMGT == "PSK" ]; then
  echo -e "${BLUE}[INFO]${NC} Passphrase:\t${GREEN}$PASSPHRASE${NC}"
elif [ $KEYMGT == "WEP" ]; then
  echo -e "${BLUE}[INFO]${NC} WEP Key:\t\t${GREEN}$PASSPHRASE${NC}"
fi
echo -e "${BLUE}[INFO]${NC} Press CTRL-C to stop..."
/usr/sbin/hostapd /etc/hostapd.conf
