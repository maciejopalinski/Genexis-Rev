#!/usr/bin/webif-page
<?
. "/usr/lib/webif/webif.sh"
. "/usr/lib/webif/oxsh.sh"

###################################################################
# WAN configuration page
#
# Description:
#	Configures basic WAN interface settings.
#
# Author(s) [in order of work date]:
#       Original webif authors of wan.sh
#	Jeremy Collake <jeremy.collake@gmail.com>
#	Travis Kemen <kemen04@gmail.com>
#
# Major revisions:
#
# UCI variables referenced:
#   todo
# Configuration files referenced:
#   none
#

# Parse Settings, this function is called when doing a uci_load
config_cb() {
config_get TYPE "$CONFIG_SECTION" TYPE
case "$TYPE" in
        interface)
		config_get ds "$CONFIG_SECTION" downstream
	        [ "$ds" = "1" ] || append network_devices "$CONFIG_SECTION"
        ;;
esac
}

uci_load network
# Not actually used, but if not here, get duplicate last entry for network_devices
uci_load webif	


# If have VLAN interfaces, then don't want the user using WAN interface. So
# remove all occurrences of "wan" from device name list if there are any vlan
# interfaces defined
loc=`awk -v a="$network_devices" -v b="vlan" 'BEGIN{print index(a,b)}'`   
if [ 0 -ne $loc ]; then                                                   
  network_devices=${network_devices//wan}	# List of possible interfaces
fi 

# Interface to be used for Internet service is the one where external-interface
# has been defined, so use this...
  config_get wan lan natexternaliface


# Check external interface defined by operator - else no point in getting garbage...
if ! empty "$wan"; then

# Fetching WAN other settings
if empty "$FORM_submit_wan"; then
#        config_get bridged wan type
        config_get FORM_wan_proto $wan proto
        case "$FORM_wan_proto" in
                # supported types
                static|dhcp|pppoe) ;;
                *) FORM_wan_proto="none";;
        esac

        # pptp, dhcp and static common
        FORM_wan_disabled=${wan_disabled:-$(uci get network.$wan.disabled)}
        FORM_wan_ipaddr=${wan_ipaddr:-$(uci get network.$wan.ipaddr)}
        FORM_wan_netmask=${wan_netmask:-$(uci get network.$wan.netmask)}
        FORM_wan_gateway=${wan_gateway:-$(uci get route.@route[0].gateway)}	# FIXME - Terrible kludge - assumes there is only one route!
        FORM_wan_ifname=${wan_device:-$(uci get network.$wan.ifname)}
        FORM_wan_dns=${wan_dns:-$(uci get dhcp.dns.nameserver)}			# FIXME - this is a list, if there is more than one how do we know what to pick?

        # PPP common
        FORM_ppp_username=${ppp_username:-$(uci get network.$wan.username)}
        FORM_ppp_passwd=${ppp_passwd:-$(uci get network.$wan.password)}
        FORM_pppoe_acservice=${pppoe_acservice:-$(uci get network.$wan.acservice)}
        FORM_pppoe_acname=${pppoe_acname:-$(uci get network.$wan.acname)}
#        FORM_ppp_idletime=${ppp_idletime:-$(uci get network.ppp.idletime)}
#        FORM_ppp_redialperiod=${ppp_redialperiod:-$(uci get network.ppp.redialperiod)}
        FORM_ppp_mtu=${ppp_mtu:-$(uci get network.ppp.mtu)}

        config_get redial ppp demand
        case "$redial" in
                1|enabled|on) FORM_ppp_redial="demand";;
                *) FORM_ppp_redial="persist";;
        esac

        config_get FORM_pptp_server_ip pptp server_ip

        # umts apn
        config_get FORM_wwan_service wwan service
        FORM_wwan_pincode="-@@-"
        config_get FORM_wwan_country wwan country
        config_get FORM_wwan_apn wwan apn
        config_get FORM_wwan_username wwan username
        config_get FORM_wwan_passwd wwan passwd

else
        empty "$FORM_wan_proto" && {
                ERROR="@TR<<No WAN Proto|No WAN protocol has been selected>>"
                return 255
        }

        case "$FORM_wan_proto" in
                static)
                        V_IP="required"
                        V_NM="required"
                        V_GW="required"
                        V_DNS="required"
                        ;;
		pppoe)
			V_PPPOE_USER="required min=1 max=63"
			V_PPPOE_PASS="required min=1 max=63"
			V_PPPOE_SERVICE="min=1 max=63"
			V_PPPOE_ACNAME="min=1 max=63"
			;;
                pptp)
                        V_PPTP="required"
                        ;;
        esac

validate <<EOF
ip|FORM_wan_ipaddr|@TR<<WAN Interface IP Address>>|$V_IP|$FORM_wan_ipaddr
netmask|FORM_wan_netmask|@TR<<WAN Interface Netmask>>|$V_NM|$FORM_wan_netmask
ip|FORM_wan_gateway|@TR<<WAN Interface Gateway>>|$V_GW|$FORM_wan_gateway
ip|FORM_pptp_server_ip|@TR<<PPTP Server IP>>|$V_PPTP|$FORM_pptp_server_ip
ip|FORM_wan_dns|@TR<<Domain Name Server Address>>|$V_DNS|$FORM_wan_dns
string|FORM_ppp_username|@TR<<PPPoE Username>>|$V_PPPOE_USER|$FORM_ppp_username
string|FORM_ppp_passwd|@TR<<PPPoE Password>>|$V_PPPOE_PASS|$FORM_ppp_passwd
string|FORM_pppoe_acservice|@TR<<PPPoE Service Name>>|$V_PPPOE_SERVICE|$FORM_pppoe_acservice
string|FORM_pppoe_acname|@TR<<PPPoE AC Name>>|$V_PPPOE_ACNAME|$FORM_pppoe_acname
EOF

# Saving WAN settings
        equal "$?" 0 && {
		FORM_wan_ifname=${FORM_wan_ifname/_//}

                case "$FORM_wan_proto" in
		dhcp)
			oxconfig "interface $FORM_wan_ifname; ip address dhcp"

			# Remove any PPPoE or static entries
			oxconfig "interface $FORM_wan_ifname; no pppoe username"
			oxconfig "interface $FORM_wan_ifname; no pppoe service"
			oxconfig "interface $FORM_wan_ifname; no pppoe acname"
			[ -n "$FORM_wan_dns" ] && oxconfig "no ip name-server $FORM_wan_dns"
			[ -n "$FORM_wan_gateway" ] oxconfig "no ip route 0.0.0.0/0 $FORM_wan_gateway"
			;;
		pppoe)
			oxconfig "interface $FORM_wan_ifname; ip address pppoe"
			;;
		static)
			oxconfig "interface $FORM_wan_ifname; ip address $FORM_wan_ipaddr $FORM_wan_netmask"
			oxconfig "ip name-server $FORM_wan_dns"
			oxconfig "ip route 0.0.0.0/0 $FORM_wan_gateway"
			;;
		esac

                # Common PPP settings
                case "$FORM_wan_proto" in
		pppoe)
			! empty "$FORM_ppp_username" && ! empty "$FORM_ppp_passwd" && {
				oxconfig "interface $FORM_wan_ifname; pppoe username $FORM_ppp_username password $FORM_ppp_passwd"
			}

			! empty "$FORM_pppoe_acservice" && {
				oxconfig "interface $FORM_wan_ifname; pppoe service $FORM_pppoe_acservice"
			}
			! empty "$FORM_pppoe_acname" && {
				oxconfig "interface $FORM_wan_ifname; pppoe acname $FORM_pppoe_acname"
			}
                       	;;
                esac

		# We're done, save the changes
		[ -z "$ERROR" ] && oxwrite
        }
fi

	for wif in $network_devices; do
		case "$wif" in
		wan | vlan*)
			JS_IF_DB=$JS_IF_DB"
				ifDB.$wif = new Object;
				ifDB.$wif.proto = \"`uci get network.$wif.proto`\";
			"
			;;
		*)
			;;
		esac
	done

# detect pptp package and compile option
[ -x "/sbin/ifup.pptp" ] && {
        PPTP_OPTION="option|pptp|PPTP"
        PPTP_SERVER_OPTION="field|PPTP Server IP|pptp_server|hidden
text|pptp_server_ip|$FORM_pptp_server_ip"
}
[ -x "/lib/network/pppoe.sh" ] && {
	PPPOE_OPTION="option|pppoe|@TR<<PPPoE>>"

	for wif in $network_devices; do
		case "$wif" in
		wan | vlan*)
			uwif=`echo $wif | tr [:lower:] [:upper:]`
			WAN_IF_LIST=$WAN_IF_LIST`echo -e "\noption|${wif}|${uwif/_//}"`
			;;
		loopback | lan | *)
			;;
		esac
	done

	for wif in $network_devices; do
		case "$wif" in
		wan | vlan*)
			JS_PPP_DB=$JS_PPP_DB"
				pppDB.$wif = new Object;
				pppDB.$wif.username = \"`uci get network.$wif.username`\";
                        	pppDB.$wif.password = \"` uci get network.$wif.password`\";
                        	pppDB.$wif.acservice = \"`uci get network.$wif.acservice`\";
                        	pppDB.$wif.acname = \"`uci get network.$wif.acname`\";
			"
			;;
		*)
			;;
		esac
	done
}
fi

[ -x "/lib/network/pppoa.sh" ] && {
	PPPOA_OPTION="option|pppoa|@TR<<PPPoA>>"
}

[ -x /sbin/ifup.wwan ] && {
        WWAN_OPTION="option|wwan|UMTS/GPRS"
        WWAN_COUNTRY_LIST=$(
                awk '   BEGIN{FS=":"}
                        $1 ~ /[ \t]*#/ {next}
                        {print "option|" $1 "|@TR<<" $2 ">>"}' < /usr/lib/webif/apn.csv
        )
        JS_APN_DB=$(
                awk '   BEGIN{FS=":"}
                        $1 ~ /[ \t]*#/ {next}
                        {print "        apnDB." $1 " = new Object;"
                         print "        apnDB." $1 ".name = \"" $3 "\";"
                         print "        apnDB." $1 ".user = \"" $4 "\";"
                         print "        apnDB." $1 ".pass = \"" $5 "\";\n"}' < /usr/lib/webif/apn.csv
        )
}

header "Network" "WAN" "@TR<<WAN Configuration>>" 'onload="modechange()"'

if ! empty "$wan"; then
cat <<EOF
<script type="text/javascript" src="/webif.js "></script>
<script type="text/javascript">
<!--
function setAPN(element) {
        var apnDB = new Object();

$JS_APN_DB

        document.getElementById("wwan_apn").value = apnDB[element.value].name;
        document.getElementById("wwan_username").value = apnDB[element.value].user;
        document.getElementById("wwan_passwd").value = apnDB[element.value].pass;
}

function setInterface(element) {
        var ifDB = new Object();
$JS_IF_DB

        document.getElementById("wan_proto").value = ifDB[element.value].proto;

        var pppDB = new Object();
$JS_PPP_DB

        document.getElementById("ppp_username").value = pppDB[element.value].username;
        document.getElementById("ppp_passwd").value = pppDB[element.value].password;
        document.getElementById("pppoe_acservice").value = pppDB[element.value].acservice;
        document.getElementById("pppoe_acname").value = pppDB[element.value].acname;

	modechange();
}


function modechange()
{
	var v;
	v = (isset('wan_proto', 'static') || isset('wan_proto', 'pptp') || isset('wan_proto', 'dhcp') || isset('wan_proto', 'pppoe') || isset('wan_proto', 'pppoa'));
	set_visible('ifname', v);
	
	v = (isset('wan_proto', 'pppoe') || isset('wan_proto', 'pptp') || isset('wan_proto', 'pppoa'));
	set_visible('ppp_settings', v);
	set_visible('username', v);
	set_visible('passwd', v);

	v = (isset('wan_proto', 'static') || isset('wan_proto', 'pptp'));
	set_visible('wan_ip_settings', v);
	set_visible('field_wan_ipaddr', v);
	set_visible('field_wan_netmask', v);

	v = (isset('wan_proto', 'static') || isset('wan_proto', 'pppoe'));
	set_visible('field_spacer', v);

	v = isset('wan_proto', 'static');
	set_visible('field_wan_gateway', v);
	set_visible('field_wan_dns', v);

	v = isset('wan_proto', 'pptp');
	set_visible('pptp_server', v);
	
	v = isset('wan_proto', 'pppoa');
	set_visible('vci', v);
	set_visible('vpi', v);
	
	v = isset('wan_proto', 'wwan');
	set_visible('wwan_service_field', v);
	set_visible('wwan_sim_settings', v);
	set_visible('apn_settings', v);

	v = isset('wan_proto', 'pppoe');
	set_visible('acservice', v);
	set_visible('acname', v);

	hide('save');
	show('save');
}

-->
</script>
EOF

display_form <<EOF
start_form|@TR<<WAN Configuration>>
formtag_begin|submit_wan|$SCRIPT_NAME
field|@TR<<Interface>>
onchange|setInterface
select|wan_ifname|$FORM_wan_ifname
$WAN_IF_LIST
onchange|
helpitem|Interface
helptext|Helptext Interface#Select the upstream interface. You should only need to do this if your service provider has provided you with the relevant information. If in doubt, do not change the existing settings.
field|@TR<<Connection Type>>
onchange|modechange
select|wan_proto|$FORM_wan_proto
option|dhcp|@TR<<DHCP>>
option|static|@TR<<Static IP>>
$PPPOE_OPTION
$PPPOA_OPTION
$WWAN_OPTION
$PPTP_OPTION
onchange|

field||field_spacer|hidden
string|<br />

field|@TR<<IP Address>>|field_wan_ipaddr|hidden
text|wan_ipaddr|$FORM_wan_ipaddr
field|@TR<<Netmask>>|field_wan_netmask|hidden
text|wan_netmask|$FORM_wan_netmask
field|@TR<<Gateway>>|field_wan_gateway|hidden
text|wan_gateway|$FORM_wan_gateway
field|@TR<<Domain Name Server>>|field_wan_dns|hidden
text|wan_dns|$FORM_wan_dns
$PPTP_SERVER_OPTION
$PPPOA_VCI_OPTION
helpitem|IP Settings
helptext|Helptext IP Settings#IP Settings are optional for DHCP. They are used as defaults in case the DHCP server is unavailable.

field|@TR<<Username>>|username|hidden
text|ppp_username|$FORM_ppp_username
field|@TR<<Password>>|passwd|hidden
password|ppp_passwd|$FORM_ppp_passwd
field|@TR<<Service Name>>|acservice|hidden
text|pppoe_acservice|$FORM_pppoe_acservice
helpitem|Service Name
helptext|Helptext PPPoE Service Name#The name of the PPPoE service offered by the service provider. If this information is not provided by your service provider leave this blank.
field|@TR<<AC Name>>|acname|hidden
text|pppoe_acname|$FORM_pppoe_acname
helpitem|AC Name
helptext|Helptext PPPoE AC Name#The name of the PPPoE access concentrator. If this is information is not provided by your service provider leave this blank.
field|@TR<<MTU>>|mtu|hidden
text|ppp_mtu|$FORM_ppp_mtu
field|VCI|vci|hidden
text|wan_vci|$FORM_wan_vci
field|VPI|vpi|hidden
text|wan_vpi|$FORM_wan_vpi

field||spacer1
string|<br />
submit|submit_wan|@TR<<Save WAN Settings>>
submit||@TR<<Cancel>>
formtag_end
end_form
EOF

else
display_form << EOF
start_form|@TR<<WAN Configuration>>
string|@TR<<No Internet interface defined. Please contact your Internet provider.>>
end_form|
EOF

fi

footer ?>

<!--
##WEBIF:name:Network:150:WAN
-->
