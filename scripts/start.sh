#!/bin/bash
set -e
# Defaults
HW_MODE=g # a,b,g,n
BAND="2.4GHz"
KEYMGT="PSK"
WIFI_STANDARD="802.11g"
CHAN_WIDTH="20MHz"
# Set colors
MAGENTA='\e[0;35m'
RED='\e[0;31m'
GREEN='\e[0;32m'
BLUE='\e[0;34m'
NC='\e[0m'

# Compute VHT center frequency index for 80MHz channel width
function get_vht_center_freq() {
  local channel=$1
  case $channel in
    36|40|44|48) echo 42 ;;
    52|56|60|64) echo 58 ;;
    100|104|108|112) echo 106 ;;
    116|120|124|128) echo 122 ;;
    132|136|140|144) echo 138 ;;
    149|153|157|161) echo 155 ;;
    *) echo 0 ;;
  esac
}

# Cleanup function for graceful shutdown
function cleanup() {
  echo -e "\n[+] Shutting down..."
  echo "[+] Removing iptables NAT rules..."
  iptables -t nat -D POSTROUTING -s "${SUBNET}/24" -j MASQUERADE > /dev/null 2>&1 || true
  echo "[+] Flushing IP address from ${IFACE}..."
  ip addr flush dev "${IFACE}" 2>/dev/null || true
  echo "[+] Disabling IP forwarding..."
  echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
  echo "[+] Cleanup complete."
}

trap cleanup EXIT

# unblock wlan
rfkill unblock wlan
echo -e "[+] Configuring ${GREEN}${IFACE}${NC} as an Access Point..."
ip link set "${IFACE}" up
ip addr flush dev "${IFACE}"
ip addr add "${AP_ADDR}/24" dev "${IFACE}"
echo -e "${BLUE}[INFO]${NC} IP Address: ${GREEN}${AP_ADDR}/24${NC}"

echo "[+] Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[+] Setting IPTABLES for all interfaces..."
iptables -t nat -D POSTROUTING -s "${SUBNET}/24" -j MASQUERADE > /dev/null 2>&1 || true
iptables -t nat -A POSTROUTING -s "${SUBNET}/24" -j MASQUERADE
echo -e "${BLUE}[INFO]${NC} NAT POSTROUTING ${GREEN}${SUBNET}/24$ MASQUERADE${NC}"

if [ ${CHANNEL} -gt 14 ]; then
  HW_MODE=a
  BAND="5GHz"
fi

# Compute VHT center frequency for 80MHz configs
export VHT_CENTER_FREQ
VHT_CENTER_FREQ=$(get_vht_center_freq "${CHANNEL}")

echo "[+] Configuring hostapd..."
export IFACE="${IFACE}"
export HW_MODE="${HW_MODE}"
envsubst '$IFACE $HW_MODE $SSID $CHANNEL $PASSPHRASE $VHT_CENTER_FREQ' < /etc/hostapd.conf > /tmp/hostapd.conf
cp /tmp/hostapd.conf /etc/hostapd.conf
rm /tmp/hostapd.conf

# If VHT is configured but center freq is unknown, fall back to 20/40MHz
if grep -q "vht_oper_chwidth=1" /etc/hostapd.conf && [ "$VHT_CENTER_FREQ" -eq 0 ]; then
  echo -e "${MAGENTA}[!]${NC} Channel $CHANNEL does not map to an 80MHz group. Falling back to 20/40MHz."
  sed -i 's/vht_oper_chwidth=1/vht_oper_chwidth=0/' /etc/hostapd.conf
  sed -i '/vht_oper_centr_freq_seg0_idx/d' /etc/hostapd.conf
fi

# Apply WPA3-SAE if requested
if [ "${WPA_MODE}" == "wpa3" ]; then
  echo "[+] Applying WPA3-SAE configuration..."
  sed -i 's/wpa_key_mgmt=WPA-PSK/wpa_key_mgmt=SAE/' /etc/hostapd.conf
  sed -i 's/ieee80211w=.*/ieee80211w=2/' /etc/hostapd.conf
  # SAE uses sae_password instead of wpa_passphrase
  SAE_PASS=$(grep "^wpa_passphrase=" /etc/hostapd.conf | cut -d"=" -f2)
  echo "sae_password=${SAE_PASS}" >> /etc/hostapd.conf
  sed -i '/^wpa_passphrase=/d' /etc/hostapd.conf
fi

# Detect key management from final config
if grep -q "wep_key" /etc/hostapd.conf; then
  KEYMGT="WEP"
elif grep -q "wpa_key_mgmt=SAE" /etc/hostapd.conf; then
  if grep -q "WPA-PSK" /etc/hostapd.conf; then
    KEYMGT="WPA-PSK SAE (TRANSITION MODE)"
  else
    KEYMGT="SAE (WPA3)"
  fi
elif grep -q "wpa_key_mgmt=WPA-EAP" /etc/hostapd.conf; then
  KEYMGT="EAP"
fi

# Detect Wi-Fi standard from final config
if grep -q "ieee80211ax=1" /etc/hostapd.conf; then
  WIFI_STANDARD="802.11ax (Wi-Fi 6)"
elif grep -q "ieee80211ac=1" /etc/hostapd.conf; then
  WIFI_STANDARD="802.11ac (Wi-Fi 5)"
elif grep -q "ieee80211n=1" /etc/hostapd.conf; then
  WIFI_STANDARD="802.11n (Wi-Fi 4)"
else
  WIFI_STANDARD="802.11g (Legacy)"
fi

# Detect channel width
if grep -q "vht_oper_chwidth=1" /etc/hostapd.conf; then
  CHAN_WIDTH="80MHz"
elif grep -q "ieee80211n=1" /etc/hostapd.conf; then
  CHAN_WIDTH="20/40MHz"
fi

# Read final config values for display
SSID=$(grep "^ssid=" /etc/hostapd.conf | cut -d"=" -f2)
HW_MODE=$(grep "^hw_mode=" /etc/hostapd.conf | cut -d"=" -f2)
if [ "$HW_MODE" == "a" ]; then
  BAND="5GHz"
elif [ "$HW_MODE" == "g" ]; then
  BAND="2.4GHz"
fi
CHANNEL=$(grep "^channel=" /etc/hostapd.conf | cut -d"=" -f2)
PASSPHRASE=$(grep -E "^wpa_passphrase=|^wep_key=|^sae_password=" /etc/hostapd.conf | head -1 | cut -d"=" -f2)

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
dhcpd "${IFACE}" &> /dev/null

echo "[+] Starting HostAP Daemon ..."
echo -e "${BLUE}[INFO]${NC} Wi-Fi Standard:\t${GREEN}$WIFI_STANDARD${NC}"
echo -e "${BLUE}[INFO]${NC} Key Mgmt:\t${GREEN}$KEYMGT${NC}"
echo -e "${BLUE}[INFO]${NC} Interface:\t${GREEN}$IFACE${NC}"
echo -e "${BLUE}[INFO]${NC} SSID:\t\t${GREEN}$SSID${NC}"
echo -e "${BLUE}[INFO]${NC} Frequency Band:\t${GREEN}$BAND${NC}"
echo -e "${BLUE}[INFO]${NC} Channel:\t\t${GREEN}$CHANNEL${NC}"
echo -e "${BLUE}[INFO]${NC} Channel Width:\t${GREEN}$CHAN_WIDTH${NC}"
if [[ $KEYMGT == "PSK" || $KEYMGT == *"SAE"* ]]; then
  echo -e "${BLUE}[INFO]${NC} Passphrase:\t${GREEN}$PASSPHRASE${NC}"
elif [[ $KEYMGT == "WEP" ]]; then
  echo -e "${BLUE}[INFO]${NC} WEP Key:\t\t${GREEN}$PASSPHRASE${NC}"
fi
if grep -q "ieee80211w=2" /etc/hostapd.conf; then
  echo -e "${BLUE}[INFO]${NC} MFP:\t\t${GREEN}Required${NC}"
elif grep -q "ieee80211w=1" /etc/hostapd.conf; then
  echo -e "${BLUE}[INFO]${NC} MFP:\t\t${GREEN}Optional${NC}"
else
  echo -e "${BLUE}[INFO]${NC} MFP:\t\t${RED}Disabled${NC}"
fi
echo -e "${BLUE}[INFO]${NC} Press CTRL-C to stop..."
/usr/sbin/hostapd /etc/hostapd.conf
