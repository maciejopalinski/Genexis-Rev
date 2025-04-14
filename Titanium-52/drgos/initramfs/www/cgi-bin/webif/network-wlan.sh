#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh
. /usr/lib/webif/oxsh.sh

###################################################################
# Wireless configuration
#

###################################################################
# Parse Settings, this function is called when doing a config_load
config_cb() {
config_get TYPE "$CONFIG_SECTION" TYPE
case "$TYPE" in
        wifi-device)
                append DEVICES "$CONFIG_SECTION"
        ;;
        wifi-iface)
                append vface "$CONFIG_SECTION" "$N"
        ;;
        interface)
	        append network_devices "$CONFIG_SECTION"
        ;;
esac
}
uci_load network
#NETWORK_DEVICES="none $network_devices"
NETWORK_DEVICES="none"
uci_load webif
uci_load wireless


#####################################################################
# This is looped for every physical wireless card (wifi-device)
#
config_get card general card
config_get type general type
#DEVICES=$type

vface="vif0"		# TODO only support single interface for current release
#if [ "$card" = "1" ] ; then
for vif in $vface; do
    config_get device $vif device

        config_get FORM_def_key $vif def_key
        config_get FORM_def_ssid $vif def_ssid

	if empty "$FORM_submit_wlan"; then
	  config_get iftype "$device" type
#	  config_get country $device country
	  config_get FORM_mode_ap $device mode
	  config_get FORM_country $device countryCode
	  config_get FORM_channel $device channel
#	  config_get FORM_rate $device rate
	  config_get FORM_disabled $device disabled
	  config_get FORM_channel_width $device channel_width
	  config_get FORM_channel_ext $device channel_ext
#	  config_get FORM_band $device band
	  config_get FORM_ipaddr $vif ipaddr
	  config_get FORM_netmask $vif netmask
	  config_get FORM_wmm_enable $device wmm
	  config_get FORM_ssid $vif ssid
	  config_get FORM_hidden $vif hide
	  config_get FORM_encryption $vif authentication
	  config_get FORM_wpa_encryption $vif encryption
	  config_get FORM_wep_encryption $vif encryption
	  config_get FORM_key $vif key
	  config_get FORM_wep_key $vif keyindex
	  config_get FORM_wep_passphrase $vif key
	  case "$FORM_wep_key" in
	      1|2|3|4)
		  case "$FORM_encryption" in
		      wep|WEP) FORM_key="";;
		  esac
		  ;;
	      0) ;;
	      *) FORM_wep_key="";;
	  esac
	  textkeys=$(wepkeygen -s "$FORM_wep_passphrase"  |
	      awk 'BEGIN { count=0 };
		   { total[count]=$1, count+=1; }
		   END { print total[0] ":" total[1] ":" total[2] ":" total[3]}')
	  FORM_key0=$(echo "$textkeys" | cut -d ':' -f 0-13 | sed s/':'//g)
	  config_get FORM_key1 $vif key1
	  config_get FORM_key2 $vif key2
	  config_get FORM_key3 $vif key3
	  config_get FORM_key4 $vif key4

#	  config_get FORM_server $vif server
#	  config_get FORM_radius_port $vif port

	else
		config_get iftype "$device" type
#		config_get country $device country
		eval FORM_mode_ap="\$FORM_mode_ap_$device"
		eval FORM_country="\$FORM_country_$device"
		eval FORM_ssid="\$FORM_ssid_$device"
	        [ -z "$FORM_ssid" ] && FORM_ssid=$FORM_def_ssid
		case "$FORM_mode_ap" in
			11a) eval FORM_channel="\$FORM_achannel_$device";;
			*)eval FORM_channel="\$FORM_bgchannel_$device";;
		esac
		case "$FORM_mode_ap" in
			11b) eval FORM_rate="\$FORM_brateform_$device";;
			11g) eval FORM_rate="\$FORM_grateform_$device";;
			11bg) eval FORM_rate="\$FORM_grateform_$device";;
			11n) eval FORM_rate="\$FORM_nrateform_$device";;
			11gn) eval FORM_rate="\$FORM_gnrateform_$device";;
			11bgn) eval FORM_rate="\$FORM_bgnrateform_$device";;
		esac
		eval FORM_hidden="\$FORM_hidden_$device"
		eval FORM_disabled="\$FORM_disabled_$device"
		eval FORM_channel_width="\$FORM_channel_width_$device"
		eval FORM_channel_ext="\$FORM_channel_ext_$device"
#		eval FORM_band="\$FORM_band_$device"
		eval FORM_ipaddr="\$FORM_ipaddr_$device"
		eval FORM_netmask="\$FORM_netmask_$device"
		eval FORM_wmm_enable="\$FORM_wmm_enable_$device"
		eval FORM_encryption="\$FORM_encryption_$device"
		eval FORM_key="\$FORM_radius_key_$device"
		eval FORM_wpapskkey="\$FORM_wpapskkey_$device"
	        [ -z "$FORM_wpapskkey" ] && FORM_wpapskkey=$FORM_def_key
		case "$FORM_encryption" in
		  wpa|wpa2)
			eval FORM_key="\$FORM_wpapskkey"
			eval FORM_wpa_encryption="\$FORM_wpa_encryption_$device";;
		  wep)
			eval FORM_wep_encryption="\$FORM_wep_encryption_$device";;
#		  wpa|wpa2) eval FORM_key="\$FORM_radius_key_$device";;
		esac
#		eval FORM_server="\$FORM_server_$device"
#		eval FORM_radius_ipaddr="\$FORM_radius_ipaddr_$device"
#		eval FORM_radius_port="\$FORM_radius_port_$device"
		eval FORM_wep_key="\$FORM_wep_key_$device"
		eval FORM_wep_passphrase="\$FORM_wep_passphrase_$device"
		case "$FORM_wep_key" in
		    1|2|3|4)
			case "$FORM_encryption" in
			    wep|WEP) FORM_key="";;
			esac
			;;
		    0) ;;
		    *) FORM_wep_key="";;
		esac
		eval textkeys=$(wepkeygen -s "$FORM_wep_passphrase"  |
		    awk 'BEGIN { count=0 };
			 { total[count]=$1, count+=1; }
			 END { print total[0] ":" total[1] ":" total[2] ":" total[3]}')
		eval FORM_key0=$(echo "$textkeys" | cut -d ':' -f 0-13 | sed s/':'//g)
		eval FORM_key1="\$FORM_key1_$device"
		eval FORM_key2="\$FORM_key2_$device"
		eval FORM_key3="\$FORM_key3_$device"
		eval FORM_key4="\$FORM_key4_$device"


	fi
	
        append forms "start_form|@TR<<Wireless Interface Configuration>>" "$N"

	formtag="formtag_begin|submit_wlan|$SCRIPT_NAME"
        append forms "$formtag" "$N"
	
	
	if [ "$FORM_disabled" = 0 ]; then
		checked="checked=\"checked\" "
	else
		checked=
	fi
	mode_disabled="string|<tr>
			string|<td width=\"40%\">@TR<<Enable Radio>></td>
			string|<td width=\"60%\"><input id=\"disabled_ra0_0\" type=\"checkbox\" name=\"disabled_$device\" value=\"0\" $checked onchange=\"modechange(this)\" /></td>
			string|</tr>"

        append forms "$mode_disabled" "$N"
        	
        # Initialize channels based on country code
	country_form="field|@TR<<Country>>
			select|country_$device|$FORM_country"
			while read line; do
				code="${line%%\;*}"
				tmpv="${line#*;}"; country="${tmpv%%\;*}"
				country_form=$country_form"
					option|$code|@TR<<$country>>"
			done < "/etc/iso3166-countries.txt"
	append forms "$country_form" "$N"

        if [ "$iftype" = "atheros" ]; then
        	mode_fields="field|@TR<<Mode>>
			select|mode_ap_$device|$FORM_mode_ap"
#		echo "$dmesg_txt" |grep -q "${device}: 11g"
#		if [ "$?" = "0" ]; then
			mode_fields="$mode_fields
				option|11bg|@TR<<B + G>>
				option|11g|@TR<<G Only>>"
#		fi
#		echo "$dmesg_txt" |grep -q "${device}: 11b"
#		if [ "$?" = "0" ]; then
			mode_fields="$mode_fields
				option|11b|@TR<<B Only>>"
#		fi
#		echo "$dmesg_txt" |grep -q "${device}: 11a"
#		if [ "$?" = "0" ]; then
#			mode_fields="$mode_fields
#				option|11a|@TR<<A Only>>"
#		fi
        append forms "$mode_fields" "$N"
        fi
        	
        if [ "$iftype" = "rt2860" ]; then
        	mode_fields="field|@TR<<Mode>>
			select|mode_ap_$device|$FORM_mode_ap"
			mode_fields="$mode_fields
				option|11bg|@TR<<B + G>>
				option|11n|@TR<<N Only>>
				option|11b|@TR<<B Only>>
				option|11g|@TR<<G Only>>
				option|11bgn|@TR<<B + G + N>>"
        append forms "$mode_fields" "$N"
        fi
        
        if [ "$iftype" = "rt2870" ]; then
        	mode_fields="field|@TR<<Mode>>
			select|mode_ap_$device|$FORM_mode_ap"
			mode_fields="$mode_fields
				option|11bg|@TR<<B + G>>
				option|11n|@TR<<N Only>>
				option|11b|@TR<<B Only>>
				option|11g|@TR<<G Only>>
				option|11bgn|@TR<<B + G + N>>"
        append forms "$mode_fields" "$N"
        fi
        
        if [ "$iftype" = "rt2880" ]; then
        	mode_fields="field|@TR<<Mode>>
			select|mode_ap_$device|$FORM_mode_ap"
			mode_fields="$mode_fields
				option|11bg|@TR<<B + G>>
				option|11n|@TR<<N Only>>
				option|11b|@TR<<B Only>>
				option|11g|@TR<<G Only>>
				option|11bgn|@TR<<B + G + N>>"
        append forms "$mode_fields" "$N"
        fi

        if [ "$iftype" = "rt30xx" ]; then
        	mode_fields="field|@TR<<Mode>>
			select|mode_ap_$device|$FORM_mode_ap"
			mode_fields="$mode_fields
				option|11b|@TR<<802.11b>>
				option|11g|@TR<<802.11g>>
				option|11n|@TR<<802.11n>>
				option|11bg|@TR<<Mixed 802.11b and 802.11g>>
				option|11gn|@TR<<Mixed 802.11g and 802.11n>>
				option|11bgn|@TR<<Mixed 802.11b, 802.11g and 802.11n>>"
        append forms "$mode_fields" "$N"
	fi

        if [ "$iftype" = "aquila" ]; then
        	mode_fields="field|@TR<<Mode>>
			select|mode_ap_$device|$FORM_mode_ap"
			mode_fields="$mode_fields
				option|11b|@TR<<802.11b>>
				option|11g|@TR<<802.11g>>
				option|11n|@TR<<802.11n>>
				option|11bg|@TR<<Mixed 802.11b and 802.11g>>
				option|11gn|@TR<<Mixed 802.11g and 802.11n>>
				option|11bgn|@TR<<Mixed 802.11b, 802.11g and 802.11n>>"
        append forms "$mode_fields" "$N"
        fi
        
        if [ "$iftype" = "metalink" ]; then
        	mode_fields="field|@TR<<Mode>>
			select|mode_ap_$device|$FORM_mode_ap"
			mode_fields="$mode_fields
				option|11bg|@TR<<B + G>>
				option|11n|@TR<<N Only>>
				option|11b|@TR<<B Only>>
				option|11g|@TR<<G Only>>
				option|11bgn|@TR<<B + G + N>>"
        append forms "$mode_fields" "$N"
        fi
        
        if [ "$iftype" = "atherosmb81" ]; then
        	mode_fields="field|@TR<<Mode>>
			select|mode_ap_$device|$FORM_mode_ap"
			mode_fields="$mode_fields
				option|11bg|@TR<<B + G>>
				option|11n|@TR<<N Only>>
				option|11b|@TR<<B Only>>
				option|11g|@TR<<G Only>>
				option|11bgn|@TR<<B + G + N>>"
        append forms "$mode_fields" "$N"
        fi
        
	code=`uci get wireless.$device.countryCode | tr [:upper:] [:lower:]`
	region=`grep \$code /etc/iso3166-countries.txt | cut -f";" -f 3`
        # (--- hardly a switch here ---)
        case "$region" in
                All|all|ALL|JP) 
                   BGCHANNELS="1 2 3 4 5 6 7 8 9 10 11 12 13 14"; CHANNEL_MAX=14
                   ACHANNELS="36 40 42 44 48 50 52 56 58 60 64 149 152 153 157 160 161 156";;
                NA) 
                   BGCHANNELS="1 2 3 4 5 6 7 8 9 10 11"; CHANNEL_MAX=11
                   ACHANNELS="36 40 42 44 48 50 52 56 58 60 64 149 152 153 157 160 161 156";;
                *) 
                   BGCHANNELS="1 2 3 4 5 6 7 8 9 10 11 12 13"; CHANNEL_MAX=13
                   ACHANNELS="36 40 42 44 48 50 52 56 58 60 64 149 152 153 157 160 161 156";;
        esac
        
        BG_CHANNELS="field|@TR<<Channel>>|bgchannelform_$device|hidden
                select|bgchannel_$device|$FORM_channel
                option|auto|@TR<<Auto>>"
        for ch in $BGCHANNELS; do
                BG_CHANNELS="$BG_CHANNELS
                        option|$ch"
        done
        
#        A_CHANNELS="field|@TR<<Channel>>|achannelform_$device|hidden
#                select|achannel_$device|$FORM_channel"
#        for ch in $ACHANNELS; do
#                A_CHANNELS="$A_CHANNELS
#                        option|$ch"
#        done
	append forms "$BG_CHANNELS" "$N"
#	append forms "$A_CHANNELS" "$N"
		
	channel_width="field|@TR<<Channel Bandwidth>>|channel_width_$device|hidden
			select|channel_width_$device|$FORM_channel_width
			option|20|20
			option|40|40"
	append forms "$channel_width" "$N"

#	channel_ext="field|@TR<<Channel Ext>>|channel_ext_$device|hidden
#			select|channel_ext_$device|$FORM_channel_ext
#			option|0|Below
#			option|1|Above"
#	append forms "$channel_ext" "$N"

#	band="field|@TR<<Band>>|band_$device|hidden
#			select|band_$device|$FORM_band
#			option|2.4|2.4
#			option|5.2|5.2"
#	append forms "$band" "$N"
	
	BRATE="Auto 1 2 5.5 11"
	GRATE="Auto 1 2 5.5 6 9 11 12 18 24 36 48 54"
	NRATE="Auto MCS0 MCS1 MCS2 MCS3 MCS4 MCS5 MCS6 MCS7 MCS8 MCS9 MCS10 MCS11 MCS12 MCS13 MCS14 MCS15"
	GNRATE="Auto 1 2 6 9 12 18 24 36 48 54 MCS0 MCS1 MCS2 MCS3 MCS4 MCS5 MCS6 MCS7 MCS8 MCS9 MCS10 MCS11 MCS12 MCS13 MCS14 MCS15"
	BGNRATE="Auto 1 2 5.5 6 9 11 12 18 24 36 48 54 MCS0 MCS1 MCS2 MCS3 MCS4 MCS5 MCS6 MCS7 MCS8 MCS9 MCS10 MCS11 MCS12 MCS13 MCS14 MCS15"
	
	B_RATE="field|@TR<<Rate>>|brateform_$device|hidden
		select|brateform_$device|$FORM_rate"
	for rate in $BRATE; do
		B_RATE="$B_RATE
			option|$rate"
	done
	
	G_RATE="field|@TR<<Rate>>|grateform_$device|hidden
		select|grateform_$device|$FORM_rate"
	for rate in $GRATE; do
		G_RATE="$G_RATE
			option|$rate"
	done
	
	N_RATE="field|@TR<<Rate>>|nrateform_$device|hidden
		select|nrateform_$device|$FORM_rate"
	for rate in $NRATE; do
		N_RATE="$N_RATE
			option|$rate"
	done
	
	GN_RATE="field|@TR<<Rate>>|gnrateform_$device|hidden
		select|gnrateform_$device|$FORM_rate"
	for rate in $GNRATE; do
		GN_RATE="$GN_RATE
			option|$rate"
	done
	
	BGN_RATE="field|@TR<<Rate>>|bgnrateform_$device|hidden
		select|bgnrateform_$device|$FORM_rate"
	for rate in $BGNRATE; do
		BGN_RATE="$BGN_RATE
			option|$rate"
	done
	
# Enable these lines to enable rate setting if needed
#	append forms "$B_RATE" "$N"
#	append forms "$G_RATE" "$N"
#	append forms "$N_RATE" "$N"
#	append forms "$GN_RATE" "$N"
#	append forms "$BGN_RATE" "$N"

        wmm_enable="field|@TR<<WMM>>|wmm_enable_$device
		select|wmm_enable_$device|$FORM_wmm_enable
		option|1|@TR<<On>>
		option|0|@TR<<Off>>"
#        wmm_help="helpitem|WMM (Wireless Multi Media)
#        	helptext|WMM enables DSCP and VLAN tag based QoS"
#        append forms "$wmm_enable" "$N"
#	if [ "$iftype" = "rt2860" ]; then
#	        append forms "$wmm_help" "$N"
#	elif [ "$iftype" = "rt2870" ]; then
#		append forms "$wmm_help" "$N"
#	elif [ "$iftype" = "rt2880" ]; then
#		append forms "$wmm_help" "$N"
#	elif [ "$iftype" = "rt30xx" ]; then
#		append forms "$wmm_help" "$N"
#	fi

      ssid="field|@TR<<SSID>>|ssid_form_$device
        text|ssid_$device|$FORM_ssid"
      append forms "$ssid" "$N"
	
	if [ "$FORM_hidden" = 0 ]; then
		checked="checked=\"checked\" "
	else
		checked=
	fi
	hidden="string|<tr>
		string|<td width=\"40%\">@TR<<Broadcast SSID>></td>
		string|<td width=\"60%\"><input id=\"hidden_ra0_0\" type=\"checkbox\" name=\"hidden_$device\" value=\"0\" $checked onchange=\"modechange(this)\" /></td>
		string|</tr>"
	append forms "$hidden" "$N"

      encryption_forms="field|@TR<<Authentication Method>>
        select|encryption_$device|$FORM_encryption
        option|none|@TR<<Disabled>>
        option|wep|WEP
        option|wpa|WPA
        option|wpa2|WPA2"
      append forms "$encryption_forms" "$N"

      wpa_encryption_forms="field|@TR<<WPA Encryption>>|wpa_encryption_$device|hidden
	select|wpa_encryption_$device|$FORM_wpa_encryption
	option|aes|AES
	option|tkip|TKIP
	option|tkipaes|TKIP+AES"
      append forms "$wpa_encryption_forms" "$N"

      wep_encryption_forms="field|@TR<<WEP Encryption>>|wep_encryption_$device|hidden
	select|wep_encryption_$device|$FORM_wep_encryption
        option|open|@TR<<Open>>
        option|shared|@TR<<Shared>>"
      append forms "$wep_encryption_forms" "$N"

      wep="field|@TR<<Passphrase>>|wep_passphrase_$device|hidden
        password|wep_passphrase_$device|$FORM_wep_passphrase
        string|<br />
        field|@TR<<WEP Key generated from Passphrase>>|wep_key_0_$device|hidden
        radio|wep_key_$device|$FORM_wep_key|0
        text|key0_$device|$FORM_key0|||readonly|26|<br />
        field|@TR<<WEP Key 1>>|wep_key_1_$device|hidden
        radio|wep_key_$device|$FORM_wep_key|1
        text|key1_$device|$FORM_key1||||26|<br />
        field|@TR<<WEP Key 2>>|wep_key_2_$device|hidden
        radio|wep_key_$device|$FORM_wep_key|2
        text|key2_$device|$FORM_key2||||26|<br />
        field|@TR<<WEP Key 3>>|wep_key_3_$device|hidden
        radio|wep_key_$device|$FORM_wep_key|3
        text|key3_$device|$FORM_key3||||26|<br />
        field|@TR<<WEP Key 4>>|wep_key_4_$device|hidden
        radio|wep_key_$device|$FORM_wep_key|4
        text|key4_$device|$FORM_key4||||26|<br />"
      append forms "$wep" "$N"
      
      wpa_enterprise="field|WPA @TR<<PSK>>|wpapsk_$device|hidden
        password|wpa_psk_$device|$FORM_key
        field|@TR<<RADIUS IP Address>>|radius_ip_$device|hidden
        text|server_$device|$FORM_server
        field|@TR<<RADIUS Port>>|radius_port_form_$device|hidden
        text|radius_port_$device|$FORM_radius_port
        field|@TR<<RADIUS Server Key>>|radiuskey_$device|hidden
        text|radius_key_$device|$FORM_key"
      append forms "$wpa_enterprise" "$N"

      wpapskkey="field|@TR<<Encryption Key>>|wpapskkey_form_$device
	password|wpapskkey_$device|$FORM_key"
      append forms "$wpapskkey" "$N"

      
      append forms "helpitem|Enable Radio" "$N"
      append forms "helptext|HelpText Enable Radio#Enable or disable the wireless LAN radio." "$N"

      append forms "helpitem|Country" "$N"
      append forms "helptext|HelpText Country#Select the country where the DRG is installed. This ensures that the radio complies with national requirements for channel and power settings." "$N"

      append forms "helpitem|Mode" "$N"
      append forms "helptext|HelpText Mode#Selects the IEEE802.11 mode of operation. Select the mode which best fits the types of devices on your network. Do not select IEEE802.11b unless you need this for legacy equipment since it affects performance." "$N"

#      append forms "helpitem|Channel and Channel Width" "$N"
#      append forms "helptext|HelpText Channel#Selects the channel used by the wireless LAN radio. Unless you know that a specific channel is the best choice, use the AUTO setting. The channel bandwidth allows one to select wideband (40MHz) channels, which can improve throughput. Note however, that 40MHz channels will not be used if radio detects any other nearby wireless networks." "$N"

      append forms "helpitem|SSID" "$N"
      append forms "helptext|HelpText SSID#The name used to identify your wireless network. The default value will be used unless another name is defined. The default SSID value is located on the label on the CD and bottom of the DRG. The SSID value will be broadcast unless it is disabled." "$N"

      append forms "helpitem|Authentication Method" "$N"
      append forms "helptext|HelpText Authentication Method#Select the required authentication method. WPA2 is recommended as the most secure method available. Disabling, or using WEP, are not recommended as it is easy for someone else to view your network traffic, and therefore access your network." "$N"
      
      append forms "helpitem|Encryption Method" "$N"
      append forms "helptext|HelpText Encryption Method#Defines the type of encryption used when using the WPA2, WPA or WEP authentication methods." "$N"

      append forms "helpitem|Encryption Key" "$N"
      append forms "helptext|HelpText Encryption Key#WPA2 and WPA keys should be alphanumeric and between 8 and 63 characters in length. A 64 character hex key may be used instead. WEP keys should be alphanumeric, must not end with '0' and should be either 10 or 26 characters in length." "$N"

      append forms "field||spacer1" "$N"
      append forms "string|<br />" "$N"
      append forms "submit|submit_wlan|@TR<<Save WLAN Settings>>" "$N"
      append forms "submit||@TR<<Cancel>>" "$N"
      append forms "formtag_end" "$N"
      append forms "end_form" "$N"


	###################################################################
	# set JavaScript
	javascript_forms="
		v = isset('encryption_$device','wep');
		set_visible('wep_key_0_$device', v);
		set_visible('wep_key_1_$device', v);
		set_visible('wep_key_2_$device', v);
		set_visible('wep_key_3_$device', v);
		set_visible('wep_key_4_$device', v);
		set_visible('wep_passphrase_$device', v);
		set_visible('wep_keys_$device', v);
		set_visible('wep_encryption_$device', v);
		v = (isset('encryption_$device','wpa') || isset('encryption_$device','wpa2'));
		set_visible('wpa_encryption_$device', v);
		//
		// force encryption listbox to no selection if user tries
		// to set WPA (PSK) with Ad-hoc mode.
		//
		if (isset('mode_$device','adhoc'))
		{
			if (isset('encryption_$device','psk'))
			{
				document.getElementById('encryption_$device').value = 'off';
			}
		}
		//
		// force encryption listbox to no selection if user tries
		// to set WPA (Radius) with anything but AP mode.
		//
//		if (!isset('mode_$device','ap'))
//		{
//			if (isset('encryption_$device','wpa') || isset('encryption_$device','wpa2'))
//			{
//				document.getElementById('encryption_$device').value = 'off';
//			}
//		}
		v = (isset('mode_ap_$device','11b') || isset('mode_ap_$device','11bg') || isset('mode_ap_$device','11g') || isset('mode_ap_$device','11n') || isset('mode_ap_$device','11gn') || isset('mode_ap_$device','11bgn'));
		set_visible('bgchannelform_$device', v);
		v = (isset('mode_ap_$device','11a'));
		set_visible('achannelform_$device', v);
		v = (isset('mode_ap_$device','11b'));
		set_visible('brateform_$device', v);
		v = ((isset('mode_ap_$device','11g')) || (isset('mode_ap_$device','11bg')));
		set_visible('grateform_$device', v);
		v = (isset('mode_ap_$device','11n'));
		set_visible('nrateform_$device', v);
		v = (isset('mode_ap_$device','11gn'));
		set_visible('gnrateform_$device', v);
		v = (isset('mode_ap_$device','11bgn'));
		set_visible('bgnrateform_$device', v);
		v = (!isset('mode_$device','wds'));
		set_visible('ssid_form_$device', v);
                set_visible('country_$device', v);
                set_visible('hidden_$device', v);
		v = (isset('encryption_$device','psk') || isset('encryption_$device','psk2'));
		set_visible('wpapsk_$device', v);
//		v = (('$iftype'=='atheros') && (!isset('mode_$device','sta')) && (isset('encryption_$device','psk') || isset('encryption_$device','psk2') || isset('encryption_$device','wpa') || isset('encryption_$device','wpa2')));
//		set_visible('install_hostapd_$device', v);
//		v = (('$iftype'=='atheros') && (isset('mode_$device','sta')) && (isset('encryption_$device','psk') || isset('encryption_$device','psk2') || isset('encryption_$device','wpa') || isset('encryption_$device','wpa2')));
//		set_visible('install_wpa_supplicant_$device', v);
//              v = (isset('encryption_$device','wpa_enterprise') || isset('encryption_$device','wpa2_enterprise'));
//                set_visible('radiuskey_$device', v);
//		set_visible('radius_ip_$device', v);
//		set_visible('radius_port_form_$device', v);
                v = (isset('encryption_$device','wpa') || isset('encryption_$device','wpa2'));
                set_visible('wpapskkey_form_$device', v);
		v = (('$iftype'=='rt2860') || ('$iftype'=='rt2870') || ('$iftype'=='rt2880') || ('$iftype'=='rt30xx') || ('$iftype'=='aquila') || ('$iftype'=='metalink') || ('$iftype'=='atherosmb81'));
		set_visible('BG_CHANNELS_$device', v);
		set_visible('channel_width_$device', v);
		set_visible('channel_ext_$device', v);
//		v = ('$iftype'=='metalink');
//		set_visible('band_$device', v);
//		v = (('$iftype'=='rt2860') || ('$iftype'=='rt2870') || ('$iftype'=='rt2880') || ('$iftype'=='rt30xx') || ('$iftype'=='aquila'));
//		set_visible('wmm_enable_$device', v);
		"
	append js "$javascript_forms" "$N"
			
	###################################################################
	# set validate forms
	case "$FORM_encryption" in
		wpa|wpa2)
			append validate_forms "wpapsk|FORM_key_$device|@TR<<WPA PSK#WPA Pre-Shared Key>>||$FORM_wpapskkey" "$N"
			;;
		wep)
			append validate_forms "int|FORM_wep_key_$device|@TR<<Selected WEP Key>>|min=0 max=4|$FORM_wep_key" "$N"
			append validate_forms "wep|FORM_key0_$device|@TR<<WEP Key>>||$FORM_key0" "$N"
			append validate_forms "wep|FORM_key1_$device|@TR<<WEP Key>> 1||$FORM_key1" "$N"
			append validate_forms "wep|FORM_key2_$device|@TR<<WEP Key>> 2||$FORM_key2" "$N"
			append validate_forms "wep|FORM_key3_$device|@TR<<WEP Key>> 3||$FORM_key3" "$N"
			append validate_forms "wep|FORM_key4_$device|@TR<<WEP Key>> 4||$FORM_key4" "$N"
	esac
	append validate_forms "string|FORM_ssid_$device|@TR<<SSID>>|max=32|$FORM_ssid" "$N"
	#append validate_forms "int|FORM_distance_$device|@TR<<Wireless Distance>>||$FORM_distance" "$N"
	#append validate_forms "ip|FORM_ipaddr_$device|@TR<<IP Address>>|required|$FORM_ipaddr" "$N"
	#append validate_forms "ip|FORM_netmask_$device|@TR<<Netmask>>||$FORM_netmask" "$N"
	append validate_forms "boolean|FORM_disabled_$device|@TR<<Enable Radio>>|required|$FORM_disabled" "$N"
	append validate_forms "boolean|FORM_hidden_$device|@TR<<Broadcast SSID>>|required|$FORM_hidden" "$N"

done
#fi

if ! empty "$FORM_submit_wlan"; then
	empty "$FORM_generate_wep_128" && empty "$FORM_generate_wep_40" &&
	{
		validate <<EOF
$validate_forms
EOF
		equal "$?" 0 && {

vface="vif0"		# TODO only support single interface for current release
		    for vif in $vface; do
			config_get device $vif device

			#for device in $DEVICES; do
				eval FORM_mode_ap="\$FORM_mode_ap_$device"
				eval FORM_country="\$FORM_country_$device"
		case "$FORM_mode_ap" in
			11a) eval FORM_channel="\$FORM_achannel_$device";;
			*)eval FORM_channel="\$FORM_bgchannel_$device";;
		esac
		case "$FORM_mode_ap" in
			11b) eval FORM_rate="\$FORM_brateform_$device";;
			11g) eval FORM_rate="\$FORM_grateform_$device";;
			11bg) eval FORM_rate="\$FORM_grateform_$device";;
			11n) eval FORM_rate="\$FORM_nrateform_$device";;
			11gn) eval FORM_rate="\$FORM_gnrateform_$device";;
			11bgn) eval FORM_rate="\$FORM_bgnrateform_$device";;
		esac
		                eval FORM_disabled="\$FORM_disabled_$device"
				eval FORM_channel_width="\$FORM_channel_width_$device"
				eval FORM_channel_ext="\$FORM_channel_ext_$device"
#				eval FORM_band="\$FORM_band_$device"
				eval FORM_ipaddr="\$FORM_ipaddr_$device"
				eval FORM_netmask="\$FORM_netmask_$device"
				eval FORM_wmm_enable="\$FORM_wmm_enable_$device"
				eval FORM_ssid="\$FORM_ssid_$device"
				eval FORM_wpapskkey="\$FORM_wpapskkey_$device"
				eval FORM_hidden="\$FORM_hidden_$device"
				eval FORM_encryption="\$FORM_encryption_$device"
				eval FORM_wpa_encryption="\$FORM_wpa_encryption_$device"
				eval FORM_wep_encryption="\$FORM_wep_encryption_$device"
				eval FORM_server="\$FORM_server_$device"
				eval FORM_radius_port="\$FORM_radius_port_$device"
				eval FORM_radius_key="\$FORM_radius_key_$device"
				eval FORM_radius_ipaddr="\$FORM_radius_ipaddr_$device"
				eval FORM_wpa_psk="\$FORM_wpa_psk_$device"
				eval FORM_wep_key="\$FORM_wep_key_$device"
				eval FORM_wep_passphrase="\$FORM_wep_passphrase_$device"
				eval FORM_key0="\$FORM_key0_$device"
				if [ -n "$FORM_wep_passphrase" ]; then
				    eval textkeys=$(wepkeygen -s "\$FORM_wep_passphrase"  |
					awk 'BEGIN { count=0 };
					     { total[count]=$1, count+=1; }
					     END { print total[0] ":" total[1] ":" total[2] ":" total[3]}')
				    eval FORM_key0=$(echo "$textkeys" | cut -d ':' -f 0-13 | sed s/':'//g)
				fi
				eval FORM_key1="\$FORM_key1_$device"
				eval FORM_key2="\$FORM_key2_$device"
				eval FORM_key3="\$FORM_key3_$device"
				eval FORM_key4="\$FORM_key4_$device"

	oxconfig "wlan bandwidth $FORM_channel_width"
	oxconfig "wlan channel $FORM_channel"
	oxconfig "wlan country $FORM_country"
	oxconfig "wlan mode $FORM_mode_ap"
#	oxconfig "wlan txpower $FORM_xxxx"

	case "$FORM_disabled" in
	0)	negate="no"
		;;
	*)	negate=
		;;
	esac
	oxconfig "interface wlan1; $negate shutdown"

# echo "encryption = $FORM_encryption" >> /tmp/foo
	case "$FORM_encryption" in
		wep)
# echo "wep key = $FORM_wep_key" >> /tmp/foo
			case "$FORM_wep_key" in
			0)
				oxconfig "interface wlan1; wlan security authentication wep $FORM_wep_encryption passphrase"
				oxconfig "interface wlan1; wlan security passphrase $FORM_wep_passphrase"
				;;
			1|2|3|4)
				oxconfig "interface wlan1; wlan security authentication wep $FORM_wep_encryption key $FORM_wep_key"
				oxconfig "interface wlan1; wlan security key 1 hex $FORM_key1"
				oxconfig "interface wlan1; wlan security key 2 hex $FORM_key2"
				oxconfig "interface wlan1; wlan security key 3 hex $FORM_key3"
				oxconfig "interface wlan1; wlan security key 4 hex $FORM_key4"
				;;
			esac
			;;
		wpa|wpa2)
			oxconfig "interface wlan1; wlan security authentication $FORM_encryption $FORM_wpa_encryption"
			oxconfig "interface wlan1; wlan security passphrase "'"'$FORM_key'"'
			;;
		none)
			oxconfig "interface wlan1; wlan security authentication none"
#			oxconfig "interface wlan1; no wlan security key"
#			oxconfig "interface wlan1; no wlan security passphrase"
			;;
	esac

	case "$FORM_hidden" in
	0)	negate=
		;;
	*)	negate="no"
		;;
	esac
	oxconfig "interface wlan1; $negate wlan ssid broadcast"
	if [ -z "$FORM_ssid"]; then
		# This is a kludge to workaround the fact that CLI will not allow a zero
		# length SSID (which is legal) - the effect is to remove the SSID and so
		# use the default SSID
		oxconfig "interface wlan1; no wlan ssid"
	else
		oxconfig "interface wlan1; wlan ssid "'"'$FORM_ssid'"'
	fi

	# We're done, save the changes
	[ -z "$ERROR" ] && oxwrite 

	done
	}
	}
fi



#####################################################################
# modechange script
#
header "Network" "Wireless" "@TR<<Wireless Configuration>>" 'onload="modechange()"'
cat <<EOF
<script type="text/javascript" src="/webif.js"></script>
<script type="text/javascript">
<!--
function modechange()
{
	var v;
	$js

	hide('save');
	show('save');
}
-->
</script>

EOF


display_form <<EOF
onchange|modechange
$validate_error
$forms
EOF

footer ?>
<!--
##WEBIF:name:Network:300:Wireless
-->
