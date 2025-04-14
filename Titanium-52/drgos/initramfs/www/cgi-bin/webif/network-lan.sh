#!/usr/bin/webif-page
<?
. "/usr/lib/webif/webif.sh"
. "/usr/lib/webif/oxsh.sh"

###################################################################
# LAN configuration page
#
# Description:
#	Configures basic LAN interface settings.
#
# Author(s) [in order of work date]:
#       Original webif authors of wan.sh and lan.sh
#	Jeremy Collake <jeremy.collake@gmail.com>
#	Travis Kemen <kemen04@gmail.com>
#
# Copyright (c) 2012 Genexis BV
# Copyright (c) 2011 Packetfront International AB
# Copyright (c) 2006 Openwrt.org
#

#Load settings from the network config file.	
uci_load "network"


# Fetch LAN settings
if empty "$FORM_submit_lan"; then
        config_get FORM_lan_disabled lan disabled
        config_get FORM_lan_ipaddr lan ipaddr
        config_get FORM_lan_netmask lan netmask
	config_get bridged lan type

else

validate <<EOF
ip|FORM_lan_ipaddr|@TR<<LAN IP Address>>|required|$FORM_lan_ipaddr
netmask|FORM_lan_netmask|@TR<<LAN Netmask>>|required|$FORM_lan_netmask
EOF

# Save LAN settings
        equal "$?" 0 && {

	    # Implement the command, and remove the temporary file
	    oxconfig "interface lan; ip address $FORM_lan_ipaddr $FORM_lan_netmask"

	    # Make the changes permanent
	    [ -z "$ERROR" ] && oxwrite 
	}
fi

header "Network" "LAN" "@TR<<LAN Configuration>>"

cat <<EOF
<script type="text/javascript" src="/webif.js"></script>
<script type="text/javascript">
function modechange()
{
        if('$bridged' == '1')
        {
                document.getElementById('lan_disabled').disabled = true;
                document.getElementById('lan_ipaddr').disabled = true;
                document.getElementById('lan_netmask').disabled = true;
        }
}
</script>
EOF

display_form <<EOF
onchange|modechange
start_form|@TR<<LAN Configuration>>
formtag_begin|submit_lan|$SCRIPT_NAME
field|@TR<<LAN IP Address>>
text|lan_ipaddr|$FORM_lan_ipaddr
field|@TR<<Netmask>>
text|lan_netmask|$FORM_lan_netmask
field||spacer1
string|<br />
submit|submit_lan|@TR<<Save LAN Settings>>
submit||@TR<<Cancel>>
formtag_end
helpitem|IP Address
helptext|Helptext LAN IP Address#This is the address you want the router to have on your LAN.
helptext|Helptext LAN IP Address#Note that if you change the address of the LAN, you may need to renew the IP address for attached clients which use DHCP to get their addresses.
helpitem|Netmask
helptext|Helptext Netmask#This bitmask determines what addresses are included in your LAN.
end_form
EOF

footer ?>

<!--
##WEBIF:name:Network:200:LAN
-->
