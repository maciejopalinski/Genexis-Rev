#!/usr/bin/webif-page
<?
. "/usr/lib/webif/webif.sh"
. "/usr/lib/webif/oxsh.sh"

###################################################################
# UPnP configuration page
#
# Description:
#	Configures the UPnP service
#
#	This is a bare minimum implementation at present - it simply
#	allows enable or disable the service

uci_load "upnpd"

if empty "$FORM_submit_upnp"; then
	# initialize all defaults
	config_get FORM_upnp_enable config enabled
fi

if ! empty "$FORM_submit_upnp"; then

validate <<EOF
boolean|FORM_upnp_enable|@TR<<UPnP enable>>|required|$FORM_upnp_enable
EOF

	equal "$?" 0 && {
		
		case "$FORM_upnp_enable" in
		1)
			oxconfig "ip upnp"
			;;
		*)
			oxconfig "no ip upnp"
			;;
		esac

		# Make changes permanent
		[ -z "$ERROR" ] && oxwrite
	}
fi

#####################################################################
#FORM_upnpd_up_bitspeed=${FORM_upnpd_up_bitspeed:-512}
#FORM_upnpd_down_bitspeed=${FORM_upnpd_down_bitspeed:-1024}

header "Network" "UPnP" "@TR<<UPnP Configuration>>"

cat <<EOF
<script type="text/javascript" src="/webif.js"></script>
<script type="text/javascript">

function modechange()
{		
	if(isset('upnp_enable','1'))
	{
		document.getElementById('upnpd_up_bitspeed').disabled = false;
		document.getElementById('upnpd_down_bitspeed').disabled = false;
		document.getElementById('upnpd_log_output').disabled = false;
	}
	else
	{
		document.getElementById('upnpd_up_bitspeed').disabled = true;
		document.getElementById('upnpd_down_bitspeed').disabled = true;
		document.getElementById('upnpd_log_output').disabled = true;
	}
}
</script>
EOF

display_form <<EOF
onchange|modechange
start_form|@TR<<UPnP>>
formtag_begin|submit_upnp|$SCRIPT_NAME
checkbox|upnp_enable|$FORM_upnp_enable|1|@TR<<Enable Universal Plug and Play (UPnP)>>
field||spacer1
string|<br />
submit|submit_upnp|@TR<< Save >>
submit||@TR<<Cancel>>
formtag_end
helpitem|Security
helptext|Helptext UPnP#WARNING: The use of UPnP makes your system vulnerable to certain forms of attack, and is therefore a security risk.  However, UPnP is necessary for some applications and the risk is relatively small.  Nevertheless, because of this security issue, UPnP is disabled by default.  It is recommended that you enable UPnP only if you are sure you need it.
end_form
EOF

footer ?>
<!--
##WEBIF:name:Network:550:UPnP
-->
