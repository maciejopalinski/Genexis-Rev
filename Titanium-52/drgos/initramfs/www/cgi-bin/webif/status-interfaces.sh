#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh
uci_load network

header "Status" "Interfaces" "@TR<<Interfaces>>"

config_get wan_ifname lan natexternaliface

if [ -n "$wan_ifname" ]; then
# echo $wan_ifname >> /tmp/foo

#case "$wan_ifname" in
#	vlan*)
#		wan_ifname=`echo $wan_ifname | sed 's/vlan/eth0./g'`
#		;;
#	wan | *)
#		wan_ifname=`echo $wan_ifname | sed 's//wan/eth0/g'`
#		;;
#esac
#echo $wan_ifname >> /tmp/foo

wan_devname=`uci get network.$wan_ifname.ifname`
wan_ifname=`uci get -P /var/state network.$wan_ifname.ifname`
# echo $wan_ifname >> /tmp/foo

# Truncate the interface name - only 9 chars allowed by ifconfig
wan_ifname=${wan_ifname:0:9}

# get WAN status
wan_config=$(ifconfig $wan_ifname 2>&1)
msconfig_speed=$(msconfig WAN speed)
msconfig_status=$(msconfig WAN status)
fi

if [ -n "$wan_config" ]; then
wan_ip_addr=$(echo "$wan_config" | grep "inet addr" | cut -d: -f 2 | sed s/Bcast//g)
wan_netmask=$(echo "$wan_config" | grep "inet addr" | cut -d: -f 4)
wan_gateway=`netstat -nr | grep UG | awk '{print $2}'`

wan_mac_addr=$(echo "$wan_config" | grep "HWaddr" | cut -d'H' -f 2 | cut -d' ' -f 2)
# for PPP interface, the eth interface should be used
if [ -z "$wan_mac_addr" ]; then
  wan_dev_config=$(ifconfig $wan_devname 2>&1)

  if [ -n "$wan_dev_config" ]; then
    wan_mac_addr=$(echo "$wan_dev_config" | grep "HWaddr" | cut -d'H' -f 2 | cut -d' ' -f 2)
  fi
fi

wan_tx_packets=$(echo "$wan_config" | grep "TX packets" | sed s/'TX packets:'//g | cut -d' ' -f 11 | int2human)
wan_rx_packets=$(echo "$wan_config" | grep "RX packets" | sed s/'RX packets:'//g | cut -d' ' -f 11 | int2human)
wan_tx_bytes=$(echo "$wan_config" | grep "TX bytes" | sed s/'TX bytes:'//g | sed s/'RX bytes:'//g | cut -d'(' -f 3)
wan_rx_bytes=$(echo "$wan_config" | grep "TX bytes" | sed s/'TX bytes:'//g | sed s/'RX bytes:'//g | cut -d'(' -f 2 | cut -d ')' -f 1)

wan_link=$(echo "$msconfig_status" | grep link | cut -d: -f 2 | tr [:lower:] [:upper:])
wan_speed=$(echo "$msconfig_speed" | cut -d' ' -f 2 | cut -d: -f 2)
wan_duplex=$(echo "$msconfig_speed" | cut -d' ' -f 3 | cut -d: -f 2)
if [ "$wan_duplex" = "full" ]; then
  wan_duplex="FD"
else
  wan_duplex="HD"
fi
wan_status="Speed: $wan_speed$wan_duplex, Link: $wan_link"
fi

# get LAN status
# echo $CONFIG_lan_ifname >> /tmp/foo
lan_config=$(ifconfig -a 2>&1 | grep -A 8 "$CONFIG_lan_ifname[[:space:]]")
if [ "$(uci get network.lan.type)" = "bridge" ]; then
lan_ip_addr=$(ifconfig br-lan 2>&1 | grep "inet addr" | cut -d: -f 2 | sed s/Bcast//g)
lan_netmask=$(ifconfig br-lan 2>&1 | grep "inet addr" | cut -d: -f 4)
else
lan_ip_addr=$(echo "$lan_config" | grep "inet addr" | cut -d: -f 2 | sed s/Bcast//g)
lan_netmask=$(echo "$lan_config" | grep "inet addr" | cut -d: -f 4)
fi
lan_mac_addr=$(echo "$lan_config" | grep "HWaddr" | cut -d'H' -f 2 | cut -d' ' -f 2)
lan_tx_packets=$(echo "$lan_config" | grep "TX packets" | sed s/'TX packets:'//g | cut -d' ' -f 11 | int2human)
lan_rx_packets=$(echo "$lan_config" | grep "RX packets" | sed s/'RX packets:'//g | cut -d' ' -f 11 | int2human)
lan_tx_bytes=$(echo "$lan_config" | grep "TX bytes" | sed s/'TX bytes:'//g | sed s/'RX bytes:'//g | cut -d'(' -f 3)
lan_rx_bytes=$(echo "$lan_config" | grep "TX bytes" | sed s/'TX bytes:'//g | sed s/'RX bytes:'//g | cut -d'(' -f 2 | cut -d ')' -f 1)

# get WLAN status
wlan1_devname=`uci get wireless.vif0.device`
wlan_type=`uci get wireless.$wlan1_devname.type`
if [ -n "$wlan1_devname" ]; then
    wlan_config=$(iwconfig $wlan1_devname)
else
    wlan_config=$(iwconfig 2>&1 | grep -v 'no wireless' | grep '\w')
fi

wlan_ssid=$(echo "$wlan_config" | grep 'ESSID' | cut -d':' -f 2 | cut -d' ' -f 1 | sed s/'"'//g)
if [ "$wlan_type" = "aquila" ]; then
    wlan_mode=$(echo "$wlan_config" | grep "IEEE" | cut -d' ' -f 8)
    #workaround for now, show frequency
    wlan_channel=$(echo "$wlan_config" | grep "Mode:" | cut -d':' -f3 | cut -d' ' -f1)
    wlan_channel="Frequency:$wlan_channel GHz"
    wlan_ap=$(echo "$wlan_config" | grep "Mode:" | cut -d' ' -f 18)
    wlan_bitrate=$(echo "$wlan_config" | grep "Bit Rate:" | cut -d ':' -f2 | cut -d ' ' -f1)

else
    wlan_mode=$(echo "$wlan_config" | grep "Mode:" | cut -d':' -f 2 | cut -d' ' -f 1)
    wlan_channel=$(echo "$wlan_config" | grep "Mode:" | cut -d':' -f 2 | cut -d' ' -f 3 | cut -d'=' -f 2)
    wlan_ap=$(echo "$wlan_config" | grep "Mode:" | cut -d' ' -f 17)
    wlan_bitrate=$(echo "$wlan_config" | grep "Bit Rate=" | cut -d'=' -f 2)
fi

#wlan_freq=$(echo "$wlan_config" | grep "Mode:" | cut -d':' -f 3 | cut -d' ' -f 1)
#wlan_txpwr=$(echo "$wlan_config" | grep Tx-Power | cut -d'-' -f2 | cut -d':' -f 2 | cut -d' ' -f 1 | sed s/"dBm"//g)
#wlan_key=$(echo "$wlan_config" | grep "Encryption key:" | sed s/"Encryption key:"//)
#wlan_tx_retries=$(echo "$wlan_config" | grep "Tx excessive retries" | cut -d':' -f 2 | cut -d' ' -f 1)
#wlan_tx_invalid=$(echo "$wlan_config" | grep "Tx excessive retries" | cut -d':' -f 3 | cut -d' ' -f 1)
#wlan_tx_missed=$(echo "$wlan_config" | grep "Missed beacon" | cut -d':' -f 4 | cut -d' ' -f 1)
#wlan_rx_invalid_nwid=$(echo "$wlan_config" | grep "Rx invalid nwid:" | cut -d':' -f 2 | cut -d' ' -f 1)
#wlan_rx_invalid_crypt=$(echo "$wlan_config" | grep "Rx invalid nwid:" | cut -d':' -f 3 | cut -d' ' -f 1)
#wlan_rx_invalid_frag=$(echo "$wlan_config" | grep "Rx invalid nwid:" | cut -d':' -f 4 | cut -d' ' -f 1)
#wlan_noise=$(echo "$wlan_config" | grep "Link Noise level:" | cut -d':' -f 2 | cut -d' ' -f 1)

CONFIG_wlan_ifname="$wlan1_devname"
wlan_config=$(ifconfig -a 2>&1 | grep -A 8 "$CONFIG_wlan_ifname[[:space:]]")
# echo $wlan_config >> /tmp/foo
wlan_tx_packets=$(echo "$wlan_config" | grep "TX packets" | sed s/'TX packets:'//g | cut -d' ' -f 11 | int2human)
wlan_rx_packets=$(echo "$wlan_config" | grep "RX packets" | sed s/'RX packets:'//g | cut -d' ' -f 11 | int2human)
wlan_tx_bytes=$(echo "$wlan_config" | grep "TX bytes" | sed s/'TX bytes:'//g | sed s/'RX bytes:'//g | cut -d'(' -f 3)
wlan_rx_bytes=$(echo "$wlan_config" | grep "TX bytes" | sed s/'TX bytes:'//g | sed s/'RX bytes:'//g | cut -d'(' -f 2 | cut -d ')' -f 1)

##Find noise for atheros cards
#if [ -z "$wlan_noise" ]; then
#	wlan_noise=$(echo "$wlan_config" | grep "Noise level" | cut -d'=' -f 4 | cut -d' ' -f 1)
#fi

dns_resolver="/tmp/resolv.conf.auto"

# set unset vars
wlan_freq="${wlan_freq:-0}"
wlan_noise="${wlan_noise:-0}"
wlan_txpwr="${wlan_txpwr:-0}"

# enumerate WAN nameservers
form_dns_servers=$(awk '
	BEGIN { counter=1 }
	/nameserver/ {print "field|@TR<<DNS Server>> " counter "|dns_server_" counter "\n string|" $2 "\n" ;counter+=1}
	' $dns_resolver 2> /dev/null)

if [ -n "$wan_config" ]; then
display_form <<EOF
start_form|@TR<<WAN>>
field|@TR<<WAN Status>>|wan_status
string|$wan_status
field|@TR<<MAC Address>>|wan_mac_addr
string|<div class="mac-address">$wan_mac_addr</div>
field|@TR<<IP Address>>|wan_ip_addr
string|$wan_ip_addr
field|@TR<<Netmask>>|wan_netmask
string|$wan_netmask
field|@TR<<Gateway>>|wan_gateway
string|$wan_gateway
$form_dns_servers
field|@TR<<Received>>|wan_rx
string|$wan_rx_packets @TR<<status_interfaces_pkts#pkts>> &nbsp;($wan_rx_bytes)
field|@TR<<Transmitted>>|wan_tx
string|$wan_tx_packets @TR<<status_interfaces_pkts#pkts>> &nbsp; ($wan_tx_bytes
helpitem|WAN
helptext|WAN WAN#Wide Area Network connection is usually the upstream connection to the Internet. The connection details are given for the routed data interface used by hosts on the LAN.
end_form
EOF
else
display_form <<EOF
start_form|@TR<<WAN>>
string|@TR<<No Internet interface defined. Please contact your Internet provider.>>
helpitem|WAN
helptext|WAN WAN#Wide Area Network connection is usually the upstream connection to the Internet. The connection details are given for the routed data interface used by hosts on the LAN.
end_form
EOF
fi

display_form <<EOF
start_form|@TR<<LAN>>
field|@TR<<MAC Address>>|lan_mac_addr
string|$lan_mac_addr
field|@TR<<IP Address>>|lan_ip_addr
string|$lan_ip_addr
field|@TR<<Netmask>>|lan_netmask
string|$lan_netmask
field|@TR<<Received>>|lan_rx
string|$lan_rx_packets @TR<<status_interfaces_pkts#pkts>> &nbsp;($lan_rx_bytes)
field|@TR<<Transmitted>>|lan_tx
string|$lan_tx_packets @TR<<status_interfaces_pkts#pkts>> &nbsp;($lan_tx_bytes
helpitem|LAN
helptext|LAN LAN#Local Area Network interface information, including statistics for all host devices on LAN.
end_form

start_form|@TR<<WLAN>>
field|@TR<<Access Point>>|wlan_ap
string|$wlan_ap
field|@TR<<Mode>>|wlan_mode
string|$wlan_mode
field|@TR<<SSID>>|wlan_ssid
string|$wlan_ssid
field|@TR<<Channel>>|wlan_channel
string|$wlan_channel
field|@TR<<Bitrate>>|wlan_bitrate
string|$wlan_bitrate Mbps
field|@TR<<Received>>|wlan_rx
string|$wlan_rx_packets @TR<<status_interfaces_pkts#pkts>> &nbsp;($wlan_rx_bytes)
field|@TR<<Transmitted>>|wlan_tx
string|$wlan_tx_packets @TR<<status_interfaces_pkts#pkts>> &nbsp;($wlan_tx_bytes
helpitem|WLAN
helptext|WLAN LAN#Wireless Local Area Network interface information, including statistics for all host devices on WLAN.
end_form
EOF


footer ?>
<!--
##WEBIF:name:Status:150:Interfaces
-->
