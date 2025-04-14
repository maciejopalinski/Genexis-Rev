#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh
. /usr/lib/webif/oxsh.sh

config_cb() {
	local cfg_type="$1"
	local cfg_name="$2"

	case $cfg_type in
	nat)
		append nat "$cfg_name" "$N"
		;;
	esac
}


# port_count()	Count the number of ports in a list of ports and ranges
port_count() {
	local count=0
	local port_range_start=0
	local port_range_end=0
	local port_range=0
	local hyphen=0

	IFS=','				# FIXME - not reverting IFS value to default
	for port in $1; do
		# Check each value for a range
		hyphen=`echo $port | sed 's/-/ /g' | wc -w`
		if [ "$hyphen" -gt 1 ]; then
			port_range_start=${port%%\-*}
			port_range_end=${port##*\-}
			let port_range=port_range_end-port_range_start

			let count=count+port_range+1
		else
			# Single port
			let count=count+1
		fi

	done

	# Return the port count
	echo $count
}


! empty "$FORM_new_rule" && {
	# Strip whitespace from public and private port lists
	FORM_local_port=`echo $FORM_local_port | tr -d ' '`
	FORM_wan_port=`echo $FORM_wan_port | tr -d ' '`

validate <<EOF
string|FORM_name|@TR<<Service Name>>||$FORM_name
ports|FORM_wan_port|@TR<<Public Ports>>|required|$FORM_wan_port
ip|FORM_local_ipaddr|@TR<<Local IP Address>>|required|$FORM_local_ipaddr
ports|FORM_local_port|@TR<<Local Ports>>||$FORM_local_port
string|FORM_protocol|@TR<<Protocol>>|required|$FORM_protocol
EOF
	equal "$?" 0 && {
	if [ -z $FORM_local_port ]; then
		port=$FORM_wan_port
	else
		port=$FORM_local_port
	fi

	# Check that the number of ports is same and no ranges if redirecting
	hyphen_count=`echo $FORM_local_port | sed 's/-/ /g' | wc -w`
	[ -n "$FORM_local_port" ] && [ "$hyphen_count" -gt 1 ] && [ "$FORM_local_port" != "$FORM_wan_port" ] && {
		ERROR="$ERROR Remapping port ranges not permitted<br />"	
	}

	# Check that same number of ports used
	public_port_count=`port_count $FORM_wan_port`
	local_port_count=`port_count $FORM_local_port`
	[ -n "$FORM_local_port" ] && [ "$public_port_count" -ne "$local_port_count" ] && {
		ERROR="$ERROR Number of public and local ports do not match<br />"	
	}

	if [ -z $FORM_name ]; then
		rname=""
	else
		rname="name "'"'$FORM_name'"'
	fi

	empty "$ERROR" && {
		oxconfig "ip nat forward protocol "$FORM_protocol" port "$FORM_wan_port" destination-host "$FORM_local_ipaddr" destination-port "$port" "$rname

		# Make permanent
		[ -z "$ERROR" ] && oxwrite
	}

	}
}

#uci_load "nat"

! empty "$FORM_display_edit_rule" && {
	seq=$FORM_display_edit_rule
	FORM_name=${name:-$(uci get nat.$seq.name)}
	FORM_wan_port=${wan_port:-$(uci get nat.$seq.wan_port)}
	FORM_local_ipaddr=${local_ipaddr:-$(uci get nat.$seq.local_ip)}
	FORM_local_port=${local_port:-$(uci get nat.$seq.local_port)}
	FORM_protocol=${protocol:-$(uci get nat.$seq.protocol)}
	FORM_ruleid=${ruleid:-}
}

! empty "$FORM_save_edit_rule" && {
	# Strip whitespace from public and private port lists
	FORM_local_port=`echo $FORM_local_port | tr -d ' '`
	FORM_wan_port=`echo $FORM_wan_port | tr -d ' '`

validate <<EOF
string|FORM_name|@TR<<Service Name>>||$FORM_name
ports|FORM_wan_port|@TR<<Public Ports>>|required|$FORM_wan_port
ip|FORM_local_ipaddr|@TR<<Local IP Address>>|required|$FORM_local_ipaddr
ports|FORM_local_port|@TR<<Local Ports>>||$FORM_local_port
string|FORM_protocol|@TR<<Protocol>>|required|$FORM_protocol
int|FORM_ruleid|@TR<<Rule Identifier>>|required|$FORM_ruleid
EOF
	equal "$?" 0 && {
	if [ -z $FORM_local_port ]; then
		port=$FORM_wan_port
	else
		port=$FORM_local_port
	fi

	# Check that the number of ports is same and no ranges if redirecting
	hyphen_count=`echo $FORM_local_port | sed 's/-/ /g' | wc -w`
	[ -n "$FORM_local_port" ] && [ "$hyphen_count" -gt 1 ] && [ "$FORM_local_port" != "$FORM_wan_port" ] && {
		ERROR="$ERROR Remapping port ranges not permitted<br />"	
	}

	# Check that same number of ports used
	public_port_count=`port_count $FORM_wan_port`
	local_port_count=`port_count $FORM_local_port`
	[ -n "$FORM_local_port" ] && [ "$public_port_count" -ne "$local_port_count" ] && {
		ERROR="$ERROR Number of public and local ports do not match<br />"	
	}
	if [ -z $FORM_name ]; then
		rname=""
	else
		rname="name "'"'$FORM_name'"'
	fi

	empty "$ERROR" && {
		oxconfig "ip nat forward seq "$FORM_ruleid" protocol "$FORM_protocol" port "$FORM_wan_port" destination-host "$FORM_local_ipaddr" destination-port "$port" "$rname

		# Make permanent
		[ -z "$ERROR" ] && oxwrite
	}
        }
}

#! empty "$FORM_display_known_rule" && {
#	ruleid=`uci get nat.general.rules_count`
#	ruleid=`expr $ruleid + 1`
#	FORM_name=${name:-$(uci get nat.rule$ruleid.name)}
#	FORM_wan_port=${wan_port:-$(uci get nat.rule$ruleid.wan_port)}
#	FORM_local_ipaddr=${local_ipaddr:-$(uci get nat.rule$ruleid.local_ip)}
#	FORM_local_port=${local_port:-$(uci get nat.rule$ruleid.local_port)}
#	FORM_protocol=${protocol:-$(uci get nat.rule$ruleid.protocol)}
#}

! empty "$FORM_delete" && {
	
	oxconfig "no ip nat forward seq "$FORM_delete

	# Make permanent
	[ -z "$ERROR" ] && oxwrite
}

# Now generate the actual HTML. First reload UCI values as these may have been
# changed by commands above
uci_load "nat"

header "Network" "Port Forwarding" "@TR<<Port Forwarding Configuration>>"

table_heading="string|<div class=\"settings\">
	string|<h3><strong>@TR<<Port Forwarding Rules>></strong></h3>
	string|<table style=\"width: 60%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<Port Forwarding>>\">
	string|<tr>
	string|<th>@TR<<Service Name>></th>
	string|<th>@TR<<Public Ports>></th>
	string|<th>@TR<<Local IP Address>></th>
	string|<th>@TR<<Local Ports>></th>
	string|<th>@TR<<Protocol>></th>
	string|<th>@TR<<Action>></th>
	string|</tr>"

add_rule_heading="string|<div class=\"rule\">
	string|<table style=\"width: 90%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<Port Forwarding>>\">
	string|<tr>
	string|<th>@TR<<Service Name>></th>
	string|<th>@TR<<Public Ports>></th>
	string|<th>@TR<<Local IP Address>></th>
	string|<th>@TR<<Local Ports>></th>
	string|<th>@TR<<Protocol>></th>
	string|</tr>"

edit_rule_heading="string|<div class=\"rule\">
	string|<table style=\"width: 90%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<Port Forwarding>>\">
	string|<tr>
	string|<th></th>
	string|<th>@TR<<Service Name>></th>
	string|<th>@TR<<Public Ports>></th>
	string|<th>@TR<<Local IP Address>></th>
	string|<th>@TR<<Local Ports>></th>
	string|<th>@TR<<Protocol>></th>
	string|</tr>"

# Display table of existing rules
display_form <<EOF
$table_heading
EOF

for i in $nat; do
	config_get name $i name
	config_get wan_port $i wan_port
	config_get local_ipaddr $i local_ip
	config_get local_port $i local_port
	config_get protocol $i protocol

	if [ $local_port != $wan_port ]; then
  	  lp="<td>$local_port</td>"
	else
  	  lp="<td></td>"
	fi

display_form <<EOF
string|<tr>
string|<td>$name</td>
string|<td>$wan_port</td>
string|<td>$local_ipaddr</td>
string|$lp
string|<td>$protocol</td>

string|<td><a href="$SCRIPT_NAME?display_edit_rule=$i">@TR<<edit>></a>
string|/
string|<a href="$SCRIPT_NAME?delete=$i ">@TR<<delete>></a>
string|</td></tr>
EOF

done
echo "</table></div>"

## Populate the well known application selection
#well_known_form="field|
#	select|new_known_rule|@TR<< Foobar >>
#	option|0|Well Known Applications"
#	IFS=$(echo -e "\t")
#
#	while read -r name type wan_port udp_port_list
#	do
#		name=${name##\'}; name=${name%%\'}
#		wan_port=${wan_port##\'}; wan_port=${wan_port%%\'}
#		udp_port_list=${udp_port_list##\'}; udp_port_list=${udp_port_list%%\'}
#
#		well_known_form=$well_known_form"
#		option|$wan_port|$name"
#	done < "/etc/port_forward.csv"
#
#display_form <<EOF
#onchange|modechange
#start_form
#field||spacer1
#string|<br />
#formtag_begin|new_known_rule|$SCRIPT_NAME
#$well_known_form
#formtag_end
#end_form
#EOF


display_form <<EOF
onchange|modechange
start_form
field||spacer1
string|<br />
formtag_begin|new_nat_rule|$SCRIPT_NAME
submit|new_nat_rule|@TR<< Add New Rule >>
formtag_end
string|<br />
helpitem|Virtual Servers
helptext|Helptext Virtual Servers#Port forwarding makes it possible to forward traffic through the NAT to a specified LAN host. This is useful when setting up servers, e.g. HTTP, FTP etc. Some games also require port forwarding to enable or enhance operation.
helptext|Helptext Instructions#Specify the external port range, local IP address and protocol. You may optionally specify a service name and local port range. If you don't specify a local port range, the external port range will be used on the internal host. You may remap ports or lists of ports, but remapping port ranges is not permitted.
end_form
EOF

! empty "$FORM_new_nat_rule" && {

display_form <<EOF
onchange|modechange
start_form|
formtag_begin|new_rule|$SCRIPT_NAME
$add_rule_heading
string|<td>
text|name|$FORM_name
string|</td><td>
text|wan_port|$FORM_wan_port
string|</td><td>
text|local_ipaddr|$FORM_local_ipaddr
string|</td><td>
text|local_port|$FORM_local_port
string|</td><td>
select|protocol|$FORM_protocol
	option|both|@TR<<Both>>
	option|tcp|@TR<<TCP>>
	option|udp|@TR<<UDP>>
string|</td></div>
field||spacer1
string|<br />
submit|new_rule|@TR<<Save>>
submit||@TR<<Cancel>>
formtag_end
end_form
EOF
}

! empty "$FORM_display_edit_rule" && {

display_form <<EOF
onchange|modechange
start_form|
formtag_begin|save_edit_rule|$SCRIPT_NAME
$edit_rule_heading
string|<tr>
string|<td>
string|<input id="ruleid" type="hidden" name="ruleid" value="$FORM_display_edit_rule" />
string|</td><td>
text|name|$FORM_name
string|</td><td>
text|wan_port|$FORM_wan_port
string|</td><td>
text|local_ipaddr|$FORM_local_ipaddr
string|</td><td>
text|local_port|$FORM_local_port
string|</td><td>
select|protocol|$FORM_protocol
	option|both|@TR<<Both>>
	option|tcp|@TR<<TCP>>
	option|udp|@TR<<UDP>>
string|</td></tr>
field||spacer1
string|<br />
submit|save_edit_rule|@TR<<Save>>
submit||@TR<<Cancel>>
formtag_end
end_form
EOF
}

#! empty "$FORM_display_known_rule" && {
#
#display_form <<EOF
#onchange|modechange
#start_form|@TR<<Edit Known Rule>>
#formtag_begin|save_edit_rule|$SCRIPT_NAME
#field|@TR<<Rule ID>>||hidden
#text|ruleid|$FORM_display_known_rule|||readonly
#field|@TR<<Service Name>>|field_name
#text|name|$FORM_name
#field|@TR<<Public Port>>|field_wan_port
#text|wan_port|$FORM_wan_port
#field|@TR<<Local IP Address>>|field_local_ipaddr
#text|local_ipaddr|$FORM_local_ipaddr
#field|@TR<<Local Port>>|field_local_port
#text|local_port|$FORM_local_port
#field|@TR<<Protocol>>|field_protocol
#select|protocol|$FORM_protocol
#	option|both|@TR<<BOTH>>
#	option|tcp|@TR<<TCP>>
#	option|udp|@TR<<UDP>>
#field||spacer1
#string|<br />
#submit|save_edit_rule|@TR<<Save>>
#submit||@TR<<Cancel>>
#formtag_end
#end_form
#EOF
#}

footer ?>
<!--
##WEBIF:name:Network:590:Port Forward
-->
