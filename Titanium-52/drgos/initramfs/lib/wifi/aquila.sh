#!/bin/sh
append DRIVERS "aquila"

debug_wifi=0
wifi_log_file=/tmp/wifi.log

[ -f /tmp/debug_wifi ] && {
  debug_wifi=1
  local msg="wifi[$0 $@] started at $(date)"

  logger -s -t wifi -p daemon.debug "$msg"
  echo "$msg" >> $wifi_log_file
}

dbg_log() {
	[ $debug_wifi = 1 ] && {
		msg="${date}: $@"
		logger -s -t wifi -p daemon.debug "${msg}"
		echo "$msg" >> $wifi_log_file
	}
	return 0
}

# Reference package/atheros/files/lib/wifi/atheros.sh and also ralink is the same
scan_aquila() {
	dbg_log "scan_aquila: 1:$1 2:$2"
	local device="$1"
}

# Reference mindspeed_sdk7.1/package/aquila/files/lib/wifi/aquila.sh
disable_aquila() (
	local device="$1"

	# kill all running hostapd and wpa_supplicant processes that
	# are running on atheros vifs
	# TODO: is each vif has a hostapd process or one for all vifs?
	#	If one for all, then put a check here and do not destroy!
	for pid in `pidof hostapd wpa_supplicant`; do
		# since hostapd shutdowns without changing led status.
		[ "$device" = "ath0" ] && echo -n "0" > /tmp/wps_busy_led
		grep $device /proc/$pid/cmdline >/dev/null && \
			kill $pid
	done

	# TODO: here check if the wifi0 stuff effects other up interfaces?
	include /lib/network
	cd /sys/class/net
	local address_wifi0=$(cat $device/address)
	address_wifi0=$(expr substr $address_wifi0 4 17)
	if [ -d /sys/class/net/$device ]
	then
	for dev in $device; do
		dbg_log "disable_aquila: dev:$dev device:$device"
		address_ath=$(cat $dev/address)
		address_ath=$(expr substr $address_ath 4 17)
		if [ $address_wifi0 == $address_ath ]
		then
			ifconfig "$dev" down
			unbridge "$dev"
			# Update the device list. Since when the VAP is re-created, hotplug
			# checks current list and brings up the interface, which should not
			# occur since the interface will be configured and brought up by
			# this script.
			local new_device_list
			local current_device_list=`uci_get_state network lan device 2>/dev/null`
			for each_device in $current_device_list; do
				[ $each_device = $dev ] || append new_device_list $each_device
			done
			uci_revert_state network lan device
			uci_set_state network lan device "$new_device_list"
		fi
	done
	fi

	return 0
)

# Reference mindspeed_sdk7.1/package/aquila/files/lib/wifi/aquila.sh
enable_aquila() {
	device=$1
	# TODO: here vifs is vif0 (I did not test if for ath1 it is vif1)
	config_get vifs "$device" vifs
	local vif_idx=`echo $device | cut -d'h' -f 2`
	local vif="vif$vif_idx"
	dbg_log "enable_aquila: device=$device vif=$vif vifs:$vifs"

	# For some physical parameters a disable call is required, if VAP is up, means
	# that it is configured before. So disable it.
	ifconfig | grep -o $device > /dev/null 2>&1
	[ $? -eq 0 ] && disable_aquila "$device"

	#for some physical parameters a destroy is required
	wlanconfig "$device" destroy

	config_get disable "$device" disabled
	if [ "$disable" = "0" ]; then
		config_get rate "$device" rate
		# TODO: there are not such values (fr_threshold,rts_threshold) they return empty, disable now, look later!
		# config_get frag "advance" fr_threshold
		# config_get rts "advance" rts_threshold

		#countrycode
		#the driver wants upper case
		# TODO: Check US and multiple standard countries
		local dev_idx=`echo $device | cut -d'h' -f 2`
		local count_prev=0
		for vap_idx in 0 1 2 3; do
			if [ $vap_idx -lt $dev_idx ]; then
				config_get pre_disable "ath$vap_idx" disabled
				if [ "$disable" = "0" ]; then
					#indicate the country code is set from previous interface already
					let count_prev=$count_prev+1
				fi
			fi
		done
		if [ $count_prev -eq 0 ]; then
			config_get countrycode "$device" countryCode
			countrycode=`echo $countrycode | tr [:lower:] [:upper:]`
			current_countrycode=`iwpriv wifi0 getCountry | cut -d':' -f 2`
			# Set country code only if it is not set before, since re-setting can start unneccessary
			# scanning
			[ "$countrycode" = "$current_countrycode" ] || iwpriv wifi0 setCountry $countrycode
		fi

		# TODO: mode_if is the mode of the wireless interface (i.e. ap, managed etc.)
		# config_get mode "$device" mode
		mode_if=ap
		nosbeacon=

#		[ "$mode" = sta ] && config_get nosbeacon "$device" nosbeacon

		wlanconfig "$device" create wlandev wifi0 wlanmode "$mode_if" ${nosbeacon:+nosbeacon}
		[ $? -ne 0 ] && {
			#echo "enable_atheros($device): Failed to set up $mode dev $device" >&2
			# TODO: revert the echo method to above
			dbg_log "enable_atheros($device): Failed to set up $mode_if dev $device"
			continue
		}

		dbg_log "enable_aquila: device:$device"
		ifconfig $device txqueuelen 1000
		# TODO: check for multiple interfaces since this $first is to set the radio settings once! Use ath0!?
		# only need to change freq band and channel on the first dev
		config_get agnmode "$device" mode
		shortgi=0
		cwmmode=0

		case "$agnmode" in
			*a)
				agnmode=11A
				;;
			*b)
				agnmode=11B
				;;
			11bg)
				agnmode=11G
				;;
			11g)
				agnmode=11G
				iwpriv "$device" pureg 1
				;;
			11an)
				config_get channel_width ${device} channel_width
				case "$channel_width" in
					20)
						shortgi=1
						cwmmode=0
						agnmode=11NAHT20
					;;
					*|40)
						shortgi=1
						cwmmode=1
						agnmode=11NAHT40
					;;
				esac
				;;
			11n|11gn)
				config_get channel_width ${device} channel_width
				case "$channel_width" in
					20)
						shortgi=1
						cwmmode=0
						[ "$agnmode" = "11n" ] && iwpriv "$device" puren 1
						agnmode=11NGHT20
					;;
					*|40)
						shortgi=1
						cwmmode=1
						[ "$agnmode" = "11n" ] && iwpriv "$device" puren 1
						agnmode=11NGHT40
					;;
				esac
				;;
			11bgn)
				config_get channel_width ${device} channel_width
				case "$channel_width" in
					20)
						shortgi=1
						cwmmode=0
						agnmode=11NGHT20
					;;
					*|40)
						shortgi=1
						cwmmode=1
						config_get channel "$device" channel
						if [ "$channel" = "auto" ]; then
							agnmode=11NGHT40PLUS
						else
							[ "$channel" -lt "9" ] && agnmode=11NGHT40PLUS || agnmode=11NGHT40MINUS
						fi
					;;
				esac
				;;
			*)
				agnmode=auto
				;;
		esac

		case "$agnmode" in
			11N*)
			frag="off"
			rts="off"
			# Enabling shorr gaurd interval
			iwpriv "$device" shortgi "$shortgi"
			# iwpriv "$device" cwmmode "$cwmmode"
			;;
		esac

		# Setting mode
		iwpriv "$device" mode "$agnmode"

#		iwpriv "$device" doth 0
		config_get channel "$device" channel
		case "$channel" in
		1|2|3|4|5|6|7|8|9|10|11|12|13|14)
			iwconfig $device channel $channel
			dbg_log "iwconfig $device channel $channel"
			;;
		auto)
			# trigger auto selection
			iwconfig "$device" channel 0
			# TODO: It is done above
			# iwconfig $device channel auto
			dbg_log "iwconfig $device channel auto"
			;;
		*)
			dbg_log "unknow channel command"
			;;
		esac
		case "$agnmode" in
			11N*)
			#Setting extension channel
			config_get channel_ext ${device} channel_ext
			case "$channel_ext" in
# Observed that, extension chennel offset -1 is not working.
#					0)
#					iwpriv "$device" extoffset -1
#					;;
#					*|1)
#					iwpriv "$device" extoffset +1
#					;;
			esac

			# Sets the channel spacing for protection frames sent on the extension (secondary) channel
			# when using 40 MHz channels. The default is 1 (25MHz). It is set to 0 (20MHz) since
			# Mindspeed SDK8.0 aquila.sh does so.
			iwpriv "$device" extprotspac 0



			#Enabling HT Element for intel interoperability
			# echo 1 > /proc/sys/dev/ath/htdupieenable
		esac

		config_get ssid $vif ssid
		iwconfig "$device" essid $ssid

		ifconfig "$device" txqueuelen 1000
		# TODO: Since atheros document AP_CLI_User_Guide_MKG-15363 says that once the if is up
		#	the afterwards settings are not issued.
		ifconfig "$device" up


#		iwconfig "$device" rate "$rate" >/dev/null 2>/dev/null
		# TODO: Check whether above this settings are taken, then they can enabled
		# TODO: iwconfig "$device" rts "$rts" >/dev/null 2>/dev/null
		# TODO: iwconfig "$device" frag "$frag" >/dev/null 2>/dev/null
		iwpriv "$device" mcast_rate 36000

		# TODO: Check whether this bool function call is working otherwise change it to config_get
		config_get_bool hidden "$vif" hide 0
		dbg_log  "enable($device): hidden:$hidden"
		iwpriv "$device" hide_ssid "$hidden"

#		config_get_bool ff "$vif" ff 0
#		iwpriv "$device" ff "$ff"

#		config_get wds "$vif" wds
#		case "$wds" in
#			1|on|enabled) wds=1;;
#			*) wds=0;;
#		esac
#		iwpriv "$device" wds "$wds"

		wpa=
#		case "$enc" in

#			WEP|wep)
#				iwpriv "$device" authmode 2
		config_get auth "$vif" authentication
		config_get enc "$vif" encryption
		case "$enc" in
		open|shared)
			case "$auth" in
			WEP|wep)
				case "$auth" in
				open)
					iwpriv "$device" authmode 1
					;;
				shared)
					iwpriv "$device" authmode 2
					;;
				esac
				for idx in 1; do
					config_get key "$vif" "key${idx}"
					iwconfig "$device" key "[$idx]" "${key:-off}"
				done
				config_get key "$vif" key
				key="${key:-1}"
				case "$key" in
					*)
						iwconfig "$device" key "[$key]"
					;;
				esac
			;;
			esac
		;;
		*)
			config_get key "$vif" key
		;;
		esac
#			PSK|psk|PSK2|psk2)
#				config_get key "$vif" key
#			;;
#		esac

		case "$mode_if" in
			wds)
				config_get addr "$vif" bssid
				iwpriv "$device" wds_add "$addr"
			;;
			adhoc|ahdemo)
				config_get addr "$vif" bssid
				[ -z "$addr" ] || {
					iwconfig "$device" ap "$addr"
				}
			;;
		esac
		config_get ssid "$vif" ssid

		[ "$mode_if" = "sta" ] && {
			config_get_bool bgscan "$vif" bgscan 1
			iwpriv "$device" bgscan "$bgscan"
		}

#		config_get_bool antdiv "$device" diversity 1
#		sysctl -w dev."$device".diversity="$antdiv" >&-

#		config_get antrx "$device" rxantenna
#		if [ -n "$antrx" ]; then
#			sysctl -w dev."$device".rxantenna="$antrx" >&-
#		fi

#		config_get anttx "$device" txantenna
#		if [ -n "$anttx" ]; then
#			sysctl -w dev."$device".txantenna="$anttx" >&-
#		fi
#
#		config_get distance "$device" distance
#		if [ -n "$distance" ]; then
#			athctrl -i "$device" -d "$distance" >&-
#		fi

		config_get txpwr "$device" txPower
		if [ -n "$txpwr" ]; then
			# Get and save the maximum transmit power to calculate the requested percentage power
			iwconfig $device txpower 30 &
			sleep 1
			max_txpower_in_current_config=`iwconfig ath0 | grep "Tx-Power=" | cut -d'=' -f 2 | cut -d' ' -f 1`
			let dbm_power=$max_txpower_in_current_config*$txpwr
			let dbm_power=$dbm_power/100
			iwconfig "$device" txpower $dbm_power
		fi

		config_get ipaddr $vif ipaddr
		if [ -n "$ipaddr" ]; then
			ifconfig ${device} $ipaddr
		fi

		config_get netmask $vif netmask
		if [ -n "$netmask" ]; then
			ifconfig ${device} netmask $netmask up
		fi


		local net_cfg bridge
		net_cfg="$(find_net_config "$vif")"
		[ -z "$net_cfg" ] || {
			bridge="$(bridge_interface "$net_cfg")"
			config_set "$vif" bridge "$bridge"
			start_net "$device" "$net_cfg"
		}

		case "$mode_if" in
			ap)
				# TODO there is not such a parameter, so check it, now it should be 0
				config_get_bool isolate "$vif" isolate 0
				dbg_log "enable_aquila: isolate:$isolate"
				iwpriv "$device" ap_bridge "$((isolate^1))"

				if eval "type hostapd_setup_vif" 2>/dev/null >/dev/null; then
					dbg_log "enable_aquila: as default it should come here: hostapd"
					hostapd_setup_vif "$device" aquila || {
						# echo "enable_atheros($device): Failed to set up wpa for interface $device" >&2
						# TODO: revert the echo method to above
						dbg_log "enable_aquila($device): Failed to set up wpa for interface $device"
						# make sure this wifi interface won't accidentally stay open without encryption
						# TODO: For now, do not destroy, so that you can debug!
						#ifconfig "$device" down
						#wlanconfig "$device" destroy
						#continue
					}
				fi
			;;
#			wds|sta)
#				case "$enc" in
#					PSK|psk|PSK2|psk2)
#						case "$enc" in
#							PSK|psk)
#								proto='proto=WPA';;
#							PSK2|psk2)
#								proto='proto=RSN';;
#						esac
#						cat > /var/run/wpa_supplicant-$device.conf <<EOF
#ctrl_interface=/var/run/wpa_supplicant
#network={
#	scan_ssid=1
#	ssid="$ssid"
#	key_mgmt=WPA-PSK
#	$proto
#	psk="$key"
#}
#EOF
#					;;
#					WPA|wpa|WPA2|wpa2)
#						#add wpa_supplicant calls here
#					;;
#				esac
#				[ -z "$proto" ] || wpa_supplicant ${bridge:+ -b $bridge} -Bw -D wext -i "$device" -c /var/run/wpa_supplicant-$device.conf
#			;;
		esac
		# TODO: why here it is hardcoded to be ath0? This sets HT20/HT40 Coexistence support,
		# see AP_CLI_User_Guide_MKG-15363 file! For now single wifi card is used, so this line
		# is commented out (leave it as default); if dual card is used; review this line.
		# iwpriv ath0 disablecoext 1

		# When the channel width 40MHz, channel number must be re-set after the interface is up,
		# to get 300Mbit. If the interface is still coming up, wait untill it is properly up.
		case $channel_width in
			*40*)
				config_get channel "$device" channel
				if [ "$channel" = "auto" ]; then
					channel=`iwlist $device channel | grep Current | grep -o "Channel [1-9]*" | cut -d' ' -f 2`
				fi
				wait_count=1
				while [ $wait_count -lt 10 ]; do
					iwconfig $device | grep -o "Bit Rate:[1-9]" >/dev/null 2>&1
					retval=$?
					if [ $retval -eq "0" ]; then
						iwconfig $device channel $channel
						break
					fi
					sleep 1
					let wait_count=$wait_count+1
				done
				;;
		esac

		# If the encyription is TKIP then enable TKIP in HT mode, default was disabled
		config_get enc "$vif" encryption
		case "$enc" in *tkip*|*TKIP*) iwpriv $device htweptkip 1 ;; esac

		# flush in case there is an older list
		iwpriv $device maccmd 3
		config_get wlan_access_policy $vif accessPolicy
		case "$wlan_access_policy" in
			allow|reject)
				config_get access_mac_addr_list $vif accessControl
				for each_mac_access  in $access_mac_addr_list; do
					iwpriv $device addmac $each_mac_access
				done
				[ "$wlan_access_policy" = "allow" ] && iwpriv $device maccmd 1 || iwpriv $device maccmd 2
				;;
			*)
				iwpriv $device maccmd 0
				;;
		esac
	fi
}


# Reference is package/rt3090ap/files/lib/wifi/rt30xx.sh as a logic!
detect_aquila() {
	platform=`uci get usp.product.platform`
	[ `echo $?` != "0" ] &&  {
		msg="failed to read usp.product.platform"
		logger -s -t Wifi -p daemon.debug "$msg"
		return
	}
	[ "HRG1000" = "$platform" ] || return

	wlan=`uci get usp.hwcfg.wlan`
	[ `echo $?` != "0" ] &&  {
		msg="failed to read wlan usp config"
		logger -s -t Wifi -p daemon.debug "$msg"
		return
	}

	[ "$wlan" = "1" ] || return

	#load the driver
	adfko=`cat /proc/modules | cut -d' ' -f 1 | grep adf`
	[ -z "$adfko" ] && insmod /lib/modules/*/adf.ko
	asfko=`cat /proc/modules | cut -d' ' -f 1 | grep asf`
	[ -z "$asfko" ] && insmod /lib/modules/*/asf.ko
	ath_halko=`cat /proc/modules | cut -d' ' -f 1 | grep ath_hal`
	[ -z "$ath_halko" ] && insmod /lib/modules/*/ath_hal.ko
	ath_rate_atherosko=`cat /proc/modules | cut -d' ' -f 1 | grep ath_rate_atheros`
	[ -z "$ath_rate_atherosko" ] && insmod /lib/modules/*/ath_rate_atheros.ko
	ath_dfsko=`cat /proc/modules | cut -d' ' -f 1 | grep ath_dfs`
	[ -z "$ath_dfsko" ] && insmod /lib/modules/*/ath_dfs.ko
	ath_devko=`cat /proc/modules | cut -d' ' -f 1 | grep ath_dev`
	[ -z "$ath_devko" ] && insmod /lib/modules/*/ath_dev.ko
	umacko=`cat /proc/modules | cut -d' ' -f 1 | grep umac`
	[ -z "$umacko" ] && insmod /lib/modules/*/umac.ko
	ath_pktlogko=`cat /proc/modules | cut -d' ' -f 1 | grep ath_pktlog`
	[ -z "$ath_pktlogko" ] && insmod /lib/modules/*/ath_pktlog.ko

	#set base mac address on wifi
	local wanmac=""
	[ -s "/etc/config/usp" ] && wanmac=`uci get usp.eth.ethaddr`
	#valid length then set the address
	if [ "$(echo ${#wanmac})" = "17" ]; then
		mac_already_set=`iwpriv wifi0 getHwaddr | cut -d'r' -f 2 | tail -c 18 | tr [:upper:] [:lower:]`
		[ "$mac_already_set" = "${wanmac:0:16}4" ] || iwpriv wifi0 setHwaddr ${wanmac:0:16}4
	fi


	# TODO: Instead of "wifi0" use a "radio" parameter
	#set physical parameters (hardcoded for now)
	iwpriv wifi0 AMPDU 1  2>&- >&-
	iwpriv wifi0 AMPDUFrames 32  2>&- >&-
	iwpriv wifi0 AMPDULim 50000  2>&- >&-
	ifconfig wifi0 txqueuelen 1000  2>&- >&-
	iwpriv wifi0 txchainmask 7  2>&- >&-
	iwpriv wifi0 rxchainmask 7  2>&- >&-

	#ifconfig wifi0 up
	for i in 0 1 2 3; do
		cat /proc/net/wireless | grep ath$i >/dev/null 2>&1
		[ $? -eq 1 ] && wlanconfig "ath$i" create wlandev wifi0 wlanmode ap
	done
	# Since the last check (already_up) is returning 1, /sbin/wifi script, complains, however
	# this function does what it need to do, so return 0 at the end to indicate caller script.
	return 0
}


#set default data for Atheros!
#Important, do not change the name and purpose of the parameters,
#these parameters are used by mgmt!
set_default_config()
{
    local uci_confdir="/etc/config/"
    local cfg="wireless"

    local ssid="GENSSID"
    local wpapsk="pfse1234"
    local wpspin="1234"
    local wepkey="12345"

    if [ -s "/etc/config/usp" ]; then
	usp_ssid=`uci get usp.wlan.ssid`
	usp_psk=`uci get usp.wlan.wpapsk`
	usp_pin=`uci get usp.wlan.wpspin`
    fi

    [ "$usp_ssid" = "" ] || ssid=$usp_ssid
    [ "$usp_pin" = "" ] || wpspin=$usp_pin
    if [ "$usp_psk" != "" ]; then
	wpapsk=$usp_psk
	wepkey=`wepkeygen -s $usp_psk | sed 's/://g;' | sed 'N;N;s/\n/ /g' | sed 's/ //g;'`
	wepkey=$(echo ${wepkey%\0000})
    fi

    for i in 0 1 2 3; do

	uci setdefault $uci_confdir/$cfg.ath$i="wifi-device"
	uci setdefault $uci_confdir/$cfg.ath$i.type="aquila"
	uci setdefault $uci_confdir/$cfg.ath$i.index="$i"
	if [ "$i" = "0" ]; then
	    uci setdefault $uci_confdir/$cfg.ath$i.disabled="0"
	    uci setdefault $uci_confdir/$cfg.ath$i.def_disabled="0"
	else
	    uci setdefault $uci_confdir/$cfg.ath$i.disabled="1"
	    uci setdefault $uci_confdir/$cfg.ath$i.def_disabled="1"
	fi
	    #
	uci setdefault $uci_confdir/$cfg.ath$i.countryCode="se"
            #bgn
	uci setdefault $uci_confdir/$cfg.ath$i.mode="11bgn"
	uci setdefault $uci_confdir/$cfg.ath$i.channel="auto"
	uci setdefault $uci_confdir/$cfg.ath$i.rate="15"
	uci setdefault $uci_confdir/$cfg.ath$i.txPower="100"
	uci setdefault $uci_confdir/$cfg.ath$i.channel_width="20"
	uci setdefault $uci_confdir/$cfg.ath$i.channel_ext="1"
	uci setdefault $uci_confdir/$cfg.ath$i.wmm="0"
	uci setdefault $uci_confdir/$cfg.ath$i.Wscpin="$wpspin"
	uci setdefault $uci_confdir/$cfg.ath$i.vendorWscpin="$wpspin"

    done

    ##virtual##
    for i in 0 1 2 3; do
	vif="vif$i"
	uci setdefault $uci_confdir/$cfg.$vif="wifi-iface"
	uci setdefault $uci_confdir/$cfg.$vif.network="lan"
	uci setdefault $uci_confdir/$cfg.$vif.device="ath$i"
	uci setdefault $uci_confdir/$cfg.$vif.ipaddr=""
	uci setdefault $uci_confdir/$cfg.$vif.netmask=""
	if [ "$i" = "0" ]; then
	    vssid="$ssid"
 	else
	    vssid="$ssid$i"
 	fi

	uci setdefault $uci_confdir/$cfg.$vif.ssid="$vssid"
	uci setdefault $uci_confdir/$cfg.$vif.def_ssid="$vssid"

        #OPEN,SHARED,WEPAUTO, WPAPSK, WPA, WPA2PSK, WPA2, WPA1WPA2, WPAPSKWPA2PSK
	uci setdefault $uci_confdir/$cfg.$vif.authentication="wpa2"
        #NONE(authMode:OPEN), WEP(authMode:OPEN, SHARED), TKIP(WPA,WPA2), AES(WPA,WPA2), TKIPAES(MIX)
	uci setdefault $uci_confdir/$cfg.$vif.encryption="AES"
        #
	uci setdefault $uci_confdir/$cfg.$vif.key="$wpapsk"
	uci setdefault $uci_confdir/$cfg.$vif.def_key="$wpapsk"

	uci setdefault $uci_confdir/$cfg.$vif.def_wepkey="$wepkey"
	uci setdefault $uci_confdir/$cfg.$vif.keyindex="1"
	uci setdefault $uci_confdir/$cfg.$vif.key1="$wepkey"
	uci setdefault $uci_confdir/$cfg.$vif.key2="$wepkey"
	uci setdefault $uci_confdir/$cfg.$vif.key3="$wepkey"
	uci setdefault $uci_confdir/$cfg.$vif.key4="$wepkey"

        #
	uci setdefault $uci_confdir/$cfg.$vif.accessPolicy="disabled"
	uci setdefault $uci_confdir/$cfg.$vif.accessControl=""
	uci setdefault $uci_confdir/$cfg.$vif.hide="0"
    done
}