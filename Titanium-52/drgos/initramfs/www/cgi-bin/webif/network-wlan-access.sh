#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh
. /usr/lib/webif/oxsh.sh

config_cb() {
        local cfg_type="$1"
        local cfg_name="$2"

#        case $cfg_type in
#        interface)
#                append network_devices "$cfg_name" "$N"
#                ;;
#        esac
}


! empty "$FORM_new_wlan_device" && {
validate <<EOF
mac|FORM_mac|@TR<<MAC Address>>||$FORM_mac
EOF
	if equal "$?" 0; then
          if [ "$FORM_mac" ]; then

	    # Convert MAC formats - xx:xx:xx:xx:xx:xx -> xxxx.xxxx.xxxx
	    mac=`echo $FORM_mac | sed 's/://g' | sed 's/.\{8\}/&./' | sed 's/.\{4\}/&./'`

            oxconfig "interface wlan1; wlan access-control "$mac

	  else
		ERROR="@TR<<Error: MAC Address must be specified>> <br />"
	  fi

	  # Make changes permanent
	  [ -z "$ERROR" ] && oxwrite
	fi
}

! empty "$FORM_display_edit_device" && {
        FORM_mac=$FORM_display_edit_device

	# UCI may contain 00:00:00:00:00:00 if no MAC address has been
	# assigned. Don't display this
	if [ "$FORM_mac" == "00:00:00:00:00:00" ]; then
	  FORM_mac=""
	fi
}

! empty "$FORM_save_edit_device" && {
	# Get the previous values, so they can be deleted
        device_mac=$FORM_device_mac

validate <<EOF
mac|FORM_mac|@TR<<MAC Address>>|required|$FORM_mac
mac|FORM_device_mac|@TR<<Original MAC Address>>|required|$FORM_device_mac
EOF
	if equal "$?" 0; then
          if [ "$FORM_mac" ]; then

	    # Convert MAC formats - xx:xx:xx:xx:xx:xx -> xxxx.xxxx.xxxx
	    mac=`echo $device_mac | sed 's/://g' | sed 's/.\{8\}/&./' | sed 's/.\{4\}/&./'`

	    # First have to remove the current MAC as CLI does not allow
	    # modification of this command
	    oxconfig "interface wlan1; no wlan access-control "$mac

	    # Convert MAC formats - xx:xx:xx:xx:xx:xx -> xxxx.xxxx.xxxx
	    mac=`echo $FORM_mac | sed 's/://g' | sed 's/.\{8\}/&./' | sed 's/.\{4\}/&./'`
	    # Now store the new MAC
	    oxconfig "interface wlan1; wlan access-control "$mac

	  else
		ERROR="@TR<<Error: MAC Address must be specified>> <br />"
	  fi

	  # Make changes permanent
	  [ -z "$ERROR" ] && oxwrite
	fi
}

! empty "$FORM_delete" && {

validate <<EOF
mac|FORM_delete|@TR<<MAC Address>>|required|$FORM_delete
EOF

	if equal "$?" 0; then
	    # Convert MAC formats - xx:xx:xx:xx:xx:xx -> xxxx.xxxx.xxxx
	    mac=`echo $FORM_delete | sed 's/://g' | sed 's/.\{8\}/&./' | sed 's/.\{4\}/&./'`

	    oxconfig "interface wlan1; no wlan access-control "$mac

	    # Make changes permanent
	    [ -z "$ERROR" ] && oxwrite
	fi
}

! empty "$FORM_submit_wlan_access_settings" && {

validate <<EOF
string|FORM_wlan_access_policy|WLAN policy|required|$FORM_wlan_policy
EOF

	if equal "$?" 0; then

		if [ "$FORM_wlan_policy" == "reject" ] || 
		[ "$FORM_wlan_policy" == "allow" ]; then
			oxconfig "interface wlan1; wlan access-policy "$FORM_wlan_policy

			# Make changes permanent
			[ -z "$ERROR" ] && oxwrite

		elif [ "$FORM_wlan_policy" == "disable" ]; then
			oxconfig "interface wlan1; no wlan access-policy"

			# Make changes permanent
			[ -z "$ERROR" ] && oxwrite
		else
			ERROR="Invalid policy"
		fi
	fi
}

# Need to reload the dhcp values because may have been changed above
uci_load "wireless"

	config_get FORM_wlan_policy vif0 accessPolicy
	FORM_wlan_policy=${FORM_wlan_policy:-"disable"}
	config_get FORM_wlan_control vif0 accessControl
		

header "Network" "WLAN Access" "@TR<<WLAN Access Configuration>>"

wlan_policy="field|@TR<<WLAN Filter>>
	select|wlan_policy|$FORM_wlan_policy
       	option|disable|Disabled
       	option|allow|Allow
       	option|reject|Reject"


display_form<<EOF
onchange|modechange
start_form|@TR<<WLAN Access Policy>>
formtag_begin|submit_wlan_access_settings|$SCRIPT_NAME
$wlan_policy
field||spacer1
string|<br />
submit|submit_wlan_access_settings|@TR<<Save WLAN Access Settings>>
submit||@TR<<Cancel>>
formtag_end
helpitem|WLAN Access Policy
helptext|Helptext WLAN Access Policy#The policy can be either to allow or reject access to devices defined in the device list. The default is for access control to be disabled.
helptext|Helptext WLAN Access Policy#Disabled: WLAN access policies are not applied.
helptext|Helptext WLAN Access Policy#Allow: The WLAN policy allows access to any devices listed in the WLAN Access Control List. Devices which are not in the list are not permitted to access the network.
helptext|Helptext WLAN Access Policy#Reject: The WLAN policy rejects access to any devices listed in the WLAN Access Control List. Devices which are not in the list are permitted to access the network.
end_form
EOF

static_heading="string|<div class=\"address\">
	string|<h3><strong>@TR<<WLAN Access Control:>></strong></h3>
	string|<table style=\"width: 60%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<WLAN Device>>\">
	string|<tr>
	string|<th>@TR<<Device MAC Address>></th>
	string|<th>@TR<<Action>></th>
	string|</tr>"

static_edit_heading="string|<div class=\"address\">
	string|<table style=\"width: 60%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<WLAN Device>>\">
	string|<tr>
	string|<th>@TR<<Device MAC Address>></th>
	string|</tr>"

static_footer="string|</div>"

display_form <<EOF
$static_heading
EOF


for i in $FORM_wlan_control; do

	# UCI may contain 00:00:00:00:00:00 if no MAC address has been
	# assigned. Don't display this
	if [ "$i" == "00:00:00:00:00:00" ]; then
	  continue	# Skip this one
	fi

display_form <<EOF
string|<tr>
string|<td>$i</td>

string|<td><a href="$SCRIPT_NAME?action=modify&amp;display_edit_device=$i">@TR<<edit>></a>
string|/
string|<a href="$SCRIPT_NAME?action=modify&amp;delete=$i">@TR<<delete>></a>
string|</td></tr>
EOF

done
echo "</table></div>"

display_form <<EOF
onchange|modechange
start_form
field||spacer1
string|<br />
formtag_begin|add_wlan_device|$SCRIPT_NAME
submit|add_wlan_device|@TR<<Add WLAN Device>>
formtag_end
helpitem|WLAN Device
helptext|Helptext WLAN Device#Specify WLAN devices by MAC address. The list of devices is subject to the access policy, i.e. if the policy is to allow access, then all listed devices can access the WLAN. Or if the policy is reject, then all listed devices cannot access the WLAN.
helpitem|MAC Address
helptext|Helptext Device MAC#Enter the MAC address in XX:XX:XX:XX:XX:XX format.
end_form
EOF

! empty "$FORM_add_wlan_device" && {

display_form <<EOF
onchange|modechange
start_form|@TR<<New WLAN Device>>
formtag_begin|new_wlan_device|$SCRIPT_NAME
$static_edit_heading
string|<tr>
string|<td>
text|mac|$FORM_mac
string|</td></tr>
field||spacer1
string|<br />
submit|new_wlan_device|@TR<<Save>>
submit||@TR<<Cancel>>
formtag_end
end_form
EOF
}

! empty "$FORM_display_edit_device" && {

display_form <<EOF
onchange|modechange
start_form|@TR<<Edit WLAN Device>>
formtag_begin|save_edit_device|$SCRIPT_NAME?action=modify
string|<td>
string|<input id="device_mac" type="hidden" name="device_mac" value="$FORM_display_edit_device" />
string|</td>
string|<td>
text|mac|$FORM_mac
string|</td>
field||spacer1
string|<br />
submit|save_edit_device|@TR<<Save>>
submit||@TR<<Cancel>>
formtag_end
end_form
EOF
}

footer ?>
<!--
##WEBIF:name:Network:301:WLAN Access
-->
