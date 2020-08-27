#!/bin/bash

apt -y install dnsmasq dhcpcd hostapd

parent_device="wlan0"
ssid="PICAM"
pass="picam4tw"
ipaddress="192.168.16.1/24"
dhcprange="192.168.16.50,192.168.16.200,255.255.255.0,24h"

options=$(getopt -o s: --long ssid: -- "$@")

if [[ $? -ne 0 ]]; then
  echo
  echo "usage: $0 [OPTION]"
  echo "setup wifi access point in parallel to existing client"
  echo
  echo " -s, --ssid <SSID>	Network name"
  echo
  echo "please change ip address/range and passphrase in source file: $0"
fi

eval set -- $options
while true; do
  case "$1" in
    -s|--ssid) ssid=$2; shift; shift ;;
    --) shift; break ;;
    *)  break ;;
  esac
done


#------------------------------------------------------------------------
#- determine country and channel
#- Raspberry3 phys interface has one channel only
#------------------------------------------------------------------------
#country='NZ' #$(awk -F '=' '/^country/ {print $2}' /etc/wpa_supplicant/wpa_supplicant.conf)
#channel=$(iwlist $parent_device channel | awk '/Current Frequency/ { sub(/\)$/,"",$NF); print $NF }')

# is country a valid 2 character code?
#[[ "$country" =~ ^[A-Z][A-Z]$ ]] || country='US'
# is channel a valid integer?
#[[ "$channel" =~ ^[0-9]+$ ]] || channel=7

#echo "channel: $channel"
#echo "country: $country"

#------------------------------------------------------------------------
#- exclude ap0 from dhcp service
#------------------------------------------------------------------------
#grep -q 'denyinterfaces ap0' /etc/dhcpcd.conf || echo 'denyinterfaces ap0' >> /etc/dhcpcd.conf

# Configure wlan0
grep -q "auto wlan0" /etc/network/interfaces 2>/dev/null
if [[ $? -ne 0 ]]
then
  cat >> /etc/network/interfaces <<EOF
auto wlan0
iface wlan0 inet static
  address 192.168.16.1
  netmask 255.255.255.0
EOF
fi
#------------------------------------------------------------------------
#- Populate hostapd.conf
#------------------------------------------------------------------------
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=${ssid}
ieee80211n=1
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${pass}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

#------------------------------------------------------------------------
#- Populate `/etc/default/hostapd`
#------------------------------------------------------------------------
grep -q '^DAEMON_CONF=' /etc/default/hostapd
if [[ $? -ne 0 ]]
then
  cat > /etc/default/hostapd << EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF
fi

#------------------------------------------------------------------------
#- Populate `/etc/dnsmasq.conf`
#------------------------------------------------------------------------
cat > /etc/dnsmasq.conf << EOF

# wlan access point
interface=wlan0
dhcp-range=${dhcprange}
EOF

#------------------------------------------------------------------------
# setup wlan0
# iwlist scan
# iw list
#------------------------------------------------------------------------
ip a s dev wlan0 > /dev/null 2>&1
if [[ $? -ne 0 ]]
then
  echo "Setting up AP: $ssid"
  systemctl start hostapd
  systemctl restart dnsmasq
  systemctl restart dhcpcd
  systemctl enable dnsmasq
  systemctl enable hostapd
else
  echo "Error starting up AP $ssid. Check wlan0 is configured correctly?"
fi
