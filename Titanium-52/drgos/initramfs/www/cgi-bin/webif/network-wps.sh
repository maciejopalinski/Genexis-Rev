#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh
###################################################################
# WPS configuration page
#
# Description:
#	Enable WPS service
#
#	This is a simple implementation at present - it just allows user to
#	select whether WLAN client shall be enabled through PBC or PIN
#	method. If PIN, then allow the user to enter 8-digit client PIN.

WPS_TIMEOUT=120
if ! empty "$FORM_wps_config_button"; then
        empty "$FORM_wps_method_value" && {
                ERROR="@TR<<No WPS Method|No WPS method has been selected>>"
                return 255
        }

	case "$FORM_wps_method_value" in
	pin)	PIN="required"
		;;

	esac

validate <<EOF
string|FORM_wps_method_value|@TR<<Method>>|required|$FORM_wps_method_value
wpspin|FORM_wps_pin_value|@TR<<PIN>>|$PIN|$FORM_wps_pin_value
EOF
fi


header "Network" "WPS" "@TR<<Wi-Fi Protected Setup>>" ''
#####################################################################

display_form <<EOF
start_form|@TR<<Select Configuration Method>>
formtag_begin|wps_config_button|$SCRIPT_NAME
field||spacer1
radio|wps_method_value|$FORM_wps_method_value|pbc|@TR<<Push Button Configuration>>
helpitem|PBC
helptext|Use Push Button Configuration to start WPS process
field||spacer1
radio|wps_method_value|$FORM_wps_method_value|pin|@TR<<PIN Configuration>>
text|wps_pin_value|$FORM_wps_pin_value
helpitem|PIN
helptext|Use client PIN configuration to start WPS process
field||spacer1
submit|wps_config_button|@TR<<&nbsp;Start WPS Configuration&nbsp;>>
formtag_end
end_form
EOF

if ! empty "$FORM_wps_config_button"; then
	empty "$FORM_wps_method_value" && {
		ERROR="@TR<<No WPS Method|No WPS method has been selected>>"
		return 255
	}

	case "$FORM_wps_method_value" in
	pin)	PIN="required"
		;;
	esac

validate <<EOF
string|FORM_wps_method_value|@TR<<Method>>|required|$FORM_wps_method_value
wpspin|FORM_wps_pin_value|@TR<<PIN>>|$PIN|$FORM_wps_pin_value
EOF

if [ "$?" -eq 0 ]; then
	echo "<br/><small>@TR<<WPS configuration starting, please start client... >></small>"
	tmpfile=$(mktemp /tmp/.webif-wps-XXXXXX)

	# Call the script which will actually enable WPS configuration
	local platform=`uci get usp.product.platform`
	if [ $platform = "HRG1000" ]; then
		/sbin/wps_hrg "$FORM_wps_method_value" "$FORM_wps_pin_value" 2> "$tmpfile" &
	else
		/usr/bin/wps.sh ra0 "$FORM_wps_method_value" "$FORM_wps_pin_value" 2> "$tmpfile" &
	fi

	timeout_count=$WPS_TIMEOUT
	success=0
	while [ $timeout_count -gt 0 ] && [ $success -ne 1 ]; do
		sleep 1

		# Check for successful completion
		wps_status=`grep success "$tmpfile"`
		if [ $wps_status == "success" ]; then
			success=1
		fi
		let timeout_count=$timeout_count-1
	done

	if [ $success -ne 1 ]; then
		echo "<small>@TR<<completed.>></small>"
	else
		echo "<small>@TR<<successful!>></small>"
	fi
	rm -rf $tmpfile
fi
fi

footer ?>
<!--
##WEBIF:name:Network:370:WPS
-->

