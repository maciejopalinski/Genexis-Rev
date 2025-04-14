#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh
. /usr/lib/webif/oxsh.sh

config_cb() {
        local cfg_type="$1"
        local cfg_name="$2"

        case $cfg_type in
        interface)
                append network_devices "$cfg_name" "$N"
                ;;
        host)
#                append hosts "$cfg_name" "$N"
#                append hosts2 "$cfg_name"
                ;;
        esac
}

uci_load "network"
uci_load "dhcp"


! empty "$FORM_new_host" && {
validate <<EOF
hostname|FORM_name|@TR<<Hostname>>|nospaces nodots max=63|$FORM_name
mac|FORM_mac|@TR<<MAC Address>>||$FORM_mac
ip|FORM_ipaddr|@TR<<IP Address>>|required|$FORM_ipaddr
int|FORM_leasetime|@TR<<Leasetime>>|min=120 max=4294967295|$FORM_leasetime
EOF
	if equal "$?" 0; then
          if [ "$FORM_mac" -o "$FORM_name" ]; then

	    # Convert MAC formats - xx:xx:xx:xx:xx:xx -> xxxx.xxxx.xxxx
	    mac=`echo $FORM_mac | sed 's/://g' | sed 's/.\{8\}/&./' | sed 's/.\{4\}/&./'`

            oxconfig "dhcp server lease "$mac" "$FORM_name" "$FORM_ipaddr" "$FORM_leasetime

	  else
		ERROR="@TR<<Error: Hostname or MAC Address must be specified>> <br />"
	  fi

	  # Make changes permanent
	  [ -z "$ERROR" ] && oxwrite
	fi
}

! empty "$FORM_display_edit_host" && {
        lease=$FORM_display_edit_host
        FORM_name=${name:-$(uci get dhcp.@host[$lease].name)}
        FORM_mac=${mac:-$(uci get dhcp.@host[$lease].mac)}
        FORM_ipaddr=${ipaddr:-$(uci get dhcp.@host[$lease].ip)}
        FORM_leasetime=${leasetime:-$(uci get dhcp.@host[$lease].leasetime)}
        FORM_hostid=${hostid:-}

	# UCI may contain 00:00:00:00:00:00 if no MAC address has been
	# assigned. Don't display this
	if [ "$FORM_mac" == "00:00:00:00:00:00" ]; then
	  FORM_mac=""
	fi
}

! empty "$FORM_delete" && {
        lease=$FORM_delete
        FORM_name=${name:-$(uci get dhcp.@host[$lease].name)}
        FORM_mac=${mac:-$(uci get dhcp.@host[$lease].mac)}
        FORM_ipaddr=${ipaddr:-$(uci get dhcp.@host[$lease].ip)}
        FORM_leasetime=${leasetime:-$(uci get dhcp.@host[$lease].leasetime)}
}

! empty "$FORM_save_edit_host" && {
	# Get the previous values, so they can be deleted
        lease=$FORM_leaseid
        PREV_name=${name:-$(uci get dhcp.@host[$lease].name)}
        PREV_mac=${mac:-$(uci get dhcp.@host[$lease].mac)}
        PREV_ipaddr=${ipaddr:-$(uci get dhcp.@host[$lease].ip)}
        PREV_leasetime=${leasetime:-$(uci get dhcp.@host[$lease].leasetime)}

validate <<EOF
hostname|FORM_name|@TR<<Hostname>>|nospaces nodots max=63|$FORM_name
mac|FORM_mac|@TR<<MAC Address>>||$FORM_mac
ip|FORM_ipaddr|@TR<<IP Address>>|required|$FORM_ipaddr
int|FORM_leasetime|@TR<<Leasetime>>|min=120 max=4294967295|$FORM_leasetime
int|FORM_leaseid|@TR<<Host Identifier>>|required|$FORM_leaseid
EOF
	if equal "$?" 0; then
          if [ "$FORM_mac" -o "$FORM_name" ]; then

	    # Convert MAC formats - xx:xx:xx:xx:xx:xx -> xxxx.xxxx.xxxx
	    mac=`echo $PREV_mac | sed 's/://g' | sed 's/.\{8\}/&./' | sed 's/.\{4\}/&./'`

	    # First have to remove the current lease as CLI does not allow
	    # modification of this command
	    oxconfig "no dhcp server lease "$mac" "$PREV_name" "$PREV_ipaddr" "$PREV_leasetime

	    # Convert MAC formats - xx:xx:xx:xx:xx:xx -> xxxx.xxxx.xxxx
	    mac=`echo $FORM_mac | sed 's/://g' | sed 's/.\{8\}/&./' | sed 's/.\{4\}/&./'`
	    oxconfig "dhcp server lease "$mac" "$FORM_name" "$FORM_ipaddr" "$FORM_leasetime

	  else
		ERROR="@TR<<Error: Hostname or MAC Address must be specified>> <br />"
	  fi

	  # Make changes permanent
	  [ -z "$ERROR" ] && oxwrite
	fi
}

! empty "$FORM_delete" && {
	
	# Convert MAC formats - xx:xx:xx:xx:xx:xx -> xxxx.xxxx.xxxx
	mac=`echo $FORM_mac | sed 's/://g' | sed 's/.\{8\}/&./' | sed 's/.\{4\}/&./'`

	oxconfig "no dhcp server lease "$mac" "$FORM_name" "$FORM_ipaddr

	# Make changes permanent
	[ -z "$ERROR" ] && oxwrite
}

! empty "$FORM_submit_dhcp_settings" && {
    	let FORM_dhcp_num=$FORM_dhcp_end-$FORM_dhcp_start+1

validate <<EOF
boolean|FORM_dhcp_disabled|DHCP enable|required|$FORM_dhcp_disabled
int|FORM_dhcp_start|DHCP start|min=1 max=253|$FORM_dhcp_start
int|FORM_dhcp_num|DHCP num|min=1 max=253|$FORM_dhcp_num
int|FORM_dhcp_lease|DHCP lease time|min=120 max=4294967295|$FORM_dhcp_lease
string|FORM_dhcp_domain_name|DHCP domain name|max=255 nospaces|$FORM_dhcp_domain_name
EOF

	if equal "$?" 0; then

		case "$FORM_dhcp_disabled" in
		0)	negate="no"
			;;
		*)	negate=
			;;
		esac
		oxconfig "$negate dhcp server disable"

		oxconfig "dhcp server pool "$FORM_dhcp_start" "$FORM_dhcp_num

		if [ -n "$FORM_dhcp_lease" ]; then
			oxconfig "dhcp server option lease-time "$FORM_dhcp_lease
		else
			oxconfig "no dhcp server option lease-time"
		fi

		if [ -n "$FORM_dhcp_domain_name" ]; then
			oxconfig "dhcp server option domain-name "$FORM_dhcp_domain_name
		else
			oxconfig "no dhcp server option domain-name"
		fi

		# Make changes permanent
		[ -z "$ERROR" ] && oxwrite
	fi
}

# Need to reload the dhcp values because may have been changed above
uci_load "dhcp"

	FORM_iface="lan"
	config_get FORM_dhcp_disabled ${FORM_iface} ignore
	config_get FORM_dhcp_start ${FORM_iface} start
	config_get dhcp_num ${FORM_iface} limit
	config_get dhcp_option dhcp_option dhcp_option
		
	FORM_dhcp_lease=${FORM_dhcp_lease:-86400}
	# cut is to fix for cases where an IP address got stuck in this instead of mere integer
	FORM_dhcp_start=$(echo "$FORM_dhcp_start" | cut -d '.' -f 4)
	FORM_dhcp_iface=${FORM_iface:-"lan"}
	let FORM_dhcp_end=$FORM_dhcp_start+$dhcp_num
	FORM_dhcp_domain_name=""

	# Extract DHCP option values
	for option in $dhcp_option; do
		number=${option%%,0,*}
		case "$number" in
		15)	FORM_dhcp_domain_name=${option##15,0,} ;;
		51)	FORM_dhcp_lease=${option##51,0,} ;;
		*)	;;
		esac
	done
		
	config_get ipaddr ${FORM_iface} ipaddr

	if [ -n "$ipaddr" ]; then
		config_get netmask ${FORM_iface} netmask
		config_get start ${FORM_iface} start
		config_get num ${FORM_iface} limit
		
#		eval $(ipcalc.sh $ipaddr $netmask ${start:-64} ${num:-189})

NET=`echo $ipaddr | cut -d "." -f 1-3`

#echo "display: start="$FORM_dhcp_start" end="$FORM_dhcp_end >> /tmp/dhcp_calc

	if [ "$FORM_dhcp_disabled" = 0 ]; then
		checked="checked=\"checked\" "
	else
		checked=
	fi

header "Network" "DHCP" "@TR<<DHCP Server Configuration>>"

display_form<<EOF
onchange|modechange
start_form|@TR<<DHCP Server>>
formtag_begin|submit_dhcp_settings|$SCRIPT_NAME
string|<tr>
string|<td width="40%">@TR<<Enable DHCP Server>></td>
string|<td width="60%"><input id="dhcp_disabled_0" type="checkbox" name="dhcp_disabled" value="0" $checked onchange="modechange(this)" /></td>
string|</tr>
field|@TR<<DHCP Address Start>>
string|$NET.
text|dhcp_start|$FORM_dhcp_start
field|@TR<<DHCP Address End>>
string|$NET.
text|dhcp_end|$FORM_dhcp_end
field|@TR<<Lease Duration>>
text|dhcp_lease|$FORM_dhcp_lease
field|@TR<<Domain Name>>
text|dhcp_domain_name|$FORM_dhcp_domain_name
field||spacer1
string|<br />
submit|submit_dhcp_settings|@TR<<Save DHCP Server Settings>>
submit||@TR<<Cancel>>
formtag_end
helpitem|DHCP Server Addresses
helptext|Helptext DHCP Server Addresses#The start and end addresses define the extent of the DHCP server address pool.
helpitem|Lease Duration
helptext|Helptext Lease Duration#The duration is specified in seconds. The minimum is 120s.
helpitem|Domain Name
helptext|Helptext Domain Name#Defines the LAN domain name provided to clients.
end_form
EOF

static_heading="string|<div class=\"address\">
	string|<h3><strong>@TR<<Static Address Assignment>></strong></h3>
	string|<table style=\"width: 60%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<Static Address>>\">
	string|<tr>
	string|<th>@TR<<Hostname>></th>
	string|<th>@TR<<MAC Address>></th>
	string|<th>@TR<<IP Address>></th>
	string|<th>@TR<<Leasetime>></th>
	string|<th>@TR<<Action>></th>
	string|</tr>"

static_edit_heading="string|<div class=\"address\">
	string|<table style=\"width: 60%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<Static Address>>\">
	string|<tr>
	string|<th>@TR<<Hostname>></th>
	string|<th>@TR<<MAC Address>></th>
	string|<th>@TR<<IP Address>></th>
	string|<th>@TR<<Leasetime>></th>
	string|</tr>"

static_footer="string|</div>"

# Display table of existing static leases
leases=`uci sections dhcp host | sed 's/[^0-9 ]//g'`

display_form <<EOF
$static_heading
EOF

for i in $leases; do
	name=`uci get dhcp.@host[$i].name`
	ipaddr=`uci get dhcp.@host[$i].ip`
	mac=`uci get dhcp.@host[$i].mac`
	leasetime=`uci get dhcp.@host[$i].leasetime`

	# UCI may contain 00:00:00:00:00:00 if no MAC address has been
	# assigned. Don't display this
	if [ "$mac" == "00:00:00:00:00:00" ]; then
	  mac=""
	fi

display_form <<EOF
string|<tr>
string|<td>$name</td>
string|<td>$mac</td>
string|<td>$ipaddr</td>
string|<td>$leasetime</td>

string|<td><a href="$SCRIPT_NAME?action=modify&amp;iface=$ifname&amp;display_edit_host=$i">@TR<<edit>></a>
string|/
string|<a href="$SCRIPT_NAME?action=modify&amp;iface=$ifname&amp;delete=$i">@TR<<delete>></a>
string|</td></tr>
EOF

done
echo "</table></div>"

display_form <<EOF
onchange|modechange
start_form
field||spacer1
string|<br />
formtag_begin|new_static_host|$SCRIPT_NAME
submit|new_static_host|@TR<<Add Static Host>>
formtag_end
helpitem|Static Hosts
helptext|Helptext Static Hosts#A static host entry allows one to define a specific IP address for a host based on its MAC address or hostname. If the host is using DHCP, then the DHCP server will assign the defined IP address to the host for each lease. Additionally it will be possible to address the host using its name rather than it IP address. This is useful for local servers. Note that one must enter either the hostname as used by the host, or its MAC address.
helpitem|Hostname
helptext|Helptext Static Host Hostname#If you know the client hostname, or if you want to define the hostname for DNS enter it here.
helpitem|MAC Address
helptext|Helptext Static Host MAC#Enter the MAC address in XX:XX:XX:XX:XX:XX format.
helpitem|IP Address
helptext|Helptext Static Host IP#Enter the IP address to be assigned to the host.
helpitem|Leasetime
helptext|Helptext Static Host Leasetime#Optionally, enter the leasetime if you want the host to have a leasetime which is different from that used by other hosts.
end_form
EOF

! empty "$FORM_new_static_host" && {

display_form <<EOF
onchange|modechange
start_form|@TR<<New Static Address>>
formtag_begin|new_host|$SCRIPT_NAME
$static_edit_heading
string|<tr>
string|<td>
text|name|$FORM_name
string|</td><td>
text|mac|$FORM_mac
string|</td><td>
text|ipaddr|$FORM_ipaddr
string|</td><td>
text|leasetime|$FORM_leasetime
string|</td></tr>
field||spacer1
string|<br />
submit|new_host|@TR<<Save>>
submit||@TR<<Cancel>>
formtag_end
end_form
EOF
}

! empty "$FORM_display_edit_host" && {

display_form <<EOF
onchange|modechange
start_form|@TR<<Edit Static Address>>
formtag_begin|save_edit_host|$SCRIPT_NAME?action=modify&amp;iface=lan
string|<td>
string|<input id="leaseid" type="hidden" name="leaseid" value="$FORM_display_edit_host" />
string|</td><td>
text|name|$FORM_name
string|</td><td>
text|mac|$FORM_mac
string|</td><td>
text|ipaddr|$FORM_ipaddr
string|</td><td>
text|leasetime|$FORM_leasetime
string|</td>
field||spacer1
string|<br />
submit|save_edit_host|@TR<<Save>>
submit||@TR<<Cancel>>
formtag_end
end_form
EOF
}
	fi

footer ?>
<!--
##WEBIF:name:Network:425:DHCP
-->
