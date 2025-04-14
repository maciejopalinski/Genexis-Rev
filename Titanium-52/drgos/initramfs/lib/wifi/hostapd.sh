hostapd_setup_vif() {
# mindspeed_sdk7.1/package/aquila/files/lib/wifi/aquila.sh
	local dev="$1"
	local driver="$2"
	local hostapd_cfg=
	local vif_idx=`echo $dev | cut -d'h' -f 2`
	local vif="vif$vif_idx"

	# Examples:
	# psk-mixed/tkip 	=> WPA1+2 PSK, TKIP
	# wpa-psk2/tkip+aes	=> WPA2 PSK, CCMP+TKIP
	# wpa2/tkip+aes 	=> WPA2 RADIUS, CCMP+TKIP
	# ...

	# TODO: move this parsing function somewhere generic, so that
	# later it can be reused by drivers that don't use hostapd

	# crypto defaults: WPA2 vs WPA1
	case "$auth" in
		wpa2|WPA2|wpa2psk|WPA2PSK)
#	case "$enc" in
#		wpa2*|WPA2*|*PSK2*|*psk2*)
			wpa=2
			key_mgmt=WPA-PSK
#			crypto="CCMP"
		;;
		*mixed*)
			wpa=3
#			crypto="CCMP TKIP"
		;;
		*wep*|*Wep*|*WEP*)
			echo "hostapd.sh: hostapd is not starting since the enc is WEP" > /dev/console
			return
		;;
		*)
			wpa=1
			key_mgmt=WPA-PSK
#			crypto="TKIP"
		;;
	esac

	# explicit override for crypto setting
	case "$enc" in
		TKIPAES|tkipaes) crypto="CCMP TKIP";;
		TKIP|tkip) crypto="TKIP";;
		*) crypto="CCMP";;
	esac

	# use crypto/auth settings for building the hostapd config
	dbg_log "hostapd: enc:$enc auth:$auth"
	case "$auth" in
#	case "$enc" in
		*psk*|*PSK*)
			config_get psk "$vif" key
			append hostapd_cfg "wpa_passphrase=$psk" "$N"
		;;
#		*wpa*|*WPA*)
		wpa|WPA|wpa2|WPA2)
		# FIXME: add wpa+radius here
		# TODO: since our current config is using the name wpa2 without psk, copy 2 lines above to here
			config_get psk "$vif" key
			append hostapd_cfg "wpa_passphrase=$psk" "$N"
		;;
		*)
			return 0;
		;;
	esac
	# TODO: Find here the correct settings!
	#config_get ifname_vif "$vif" ifname
	config_get bridge "$vif" bridge
	config_get ssid "$vif" ssid
	dbg_log "hostapd: bridge_vif:$bridge_vif ssid_vif:$ssid_vif"
	config_get ifname "$dev" ifname
	dbg_log "hostapd: ifname:$ifname"
	# TODO: Remove below once above ifname is confirmed
	ifname=$dev

#Create topology file

	mkdir -p /tmp/hostapd
	echo "bridge none" > /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "{" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	if [ -z $bridge ]; then
		# TODO: Here it is hardcoded by mindspeed but normally in hostapd_sdk8_707.sh and
		#hostapd_dev_wpa2.sh this is a "read" value
		echo "interface ath0" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	fi
	echo "}" >> /tmp/hostapd/hostapd-topology-$ifname.conf

	if [ -z $bridge ]; then
		echo "bridge br0" >> /tmp/hostapd/hostapd-topology-$ifname.conf
		echo "{" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	else
		echo "bridge $bridge" >> /tmp/hostapd/hostapd-topology-$ifname.conf
		echo "{" >> /tmp/hostapd/hostapd-topology-$ifname.conf
		echo "interface ath0" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	fi

	echo "}" >> /tmp/hostapd/hostapd-topology-$ifname.conf

	# TODO: Here it is hardcoded by mindspeed but normally in hostapd_sdk8_707.sh and
	#	hostapd_dev_wpa2.sh this is a "read" value
	echo "radio wifi0" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "{" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "	ap" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "	{" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "		bss ath0" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "		{" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "			config 	/tmp/hostapd/bss-sec-$ifname.conf" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "		}" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "	}" >> /tmp/hostapd/hostapd-topology-$ifname.conf
	echo "}" >> /tmp/hostapd/hostapd-topology-$ifname.conf

# create Bss configuration file
	cp /lib/wifi/security.conf /tmp/hostapd/bss-sec-$ifname.conf
	echo "ssid=$ssid" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "wpa=$wpa" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "wpa_key_mgmt=$key_mgmt" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "wpa_pairwise=$crypto" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "$hostapd_cfg" >> /tmp/hostapd/bss-sec-$ifname.conf
	# TODO: It says unknown option so for now disable it!
	# echo "wps_disable=1" >> /tmp/hostapd/bss-sec-$ifname.conf

	# TODO: Look to hostapd_dev_wpa2.sh to add here more lines! (if neccessary)
	echo "driver=atheros" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "interface=$ifname" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "${bridge:+bridge=$bridge}" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "debug=$debug_wifi" >> /tmp/hostapd/bss-sec-$ifname.conf
#	cat > /var/run/hostapd-$ifname.conf <<EOF

	# WPS configuration (AP configured, do not allow external WPS Registrars)
	echo "wps_state=2" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "ap_setup_locked=0" >> /tmp/hostapd/bss-sec-$ifname.conf
	#echo "config_methods=label display push_button keypad virtual_display virtual_push_button" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "config_methods=usba ethernet label display ext_nfc_token int_nfc_token nfc_interface push_button keypad virtual_display physical_display virtual_push_button physical_push_button" >> /tmp/hostapd/bss-sec-$ifname.conf
	# echo "pbc_in_m1=1" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "eap_server=1" >> /tmp/hostapd/bss-sec-$ifname.conf
	# echo "wps_pin_requests=/var/run/hostapd_wps_pin_requests" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "device_name=Genexis wireless router" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "manufacturer=Genexis B.V." >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "model_name=`uci get usp.product.prodmktg`" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "model_number=`uci get usp.product.prodname`" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "serial_number=`uci get usp.product.serialnum`" >> /tmp/hostapd/bss-sec-$ifname.conf
	# device type is "Network Infrastructure / AP"
	echo "device_type=6-0050F204-2" >> /tmp/hostapd/bss-sec-$ifname.conf
	#echo "os_version=0" >> /tmp/hostapd/bss-sec-$ifname.conf
	echo "ap_pin=`uci get wireless.$ifname.Wscpin`" >> /tmp/hostapd/bss-sec-$ifname.conf

	# WPS RF Bands (a = 5G, b = 2.4G, g = 2.4G, ag = dual band)
	# This value should be set according to RF band(s) supported by the AP if
	# hw_mode is not set. For dual band dual concurrent devices, this needs to be
	# set to ag to allow both RF bands to be advertized.
	#echo "wps_rf_bands=ag" >> /tmp/hostapd/bss-sec-$ifname.conf

#driver=$driver
#interface=$ifname
#${bridge:+bridge=$bridge}
#ssid=$ssid
#debug=0
#wpa=$wpa
#wpa_pairwise=$crypto
#$hostapd_cfg
#EOF
#	hostapd -B /var/run/hostapd-$ifname.conf
	# TODO: if complains, use -v
	hostapd -B /tmp/hostapd/bss-sec-$ifname.conf
	# hostapd /tmp/hostapd/hostapd-topology-$ifname.conf -B
	dbg_log "hostapd: returns:$?"
}

