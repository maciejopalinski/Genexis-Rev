#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh

timeout=120

header "System" "Reboot" "@TR<<System Reboot>>"

redirection() {
	echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">"
	echo "<html>"
	echo "<head>"
	echo "<title>System Rebooting...</title>"
	echo '<meta http-equiv="refresh" content="'$1';url='$2'"></head>'
	echo "<body>"
#	echo "I am being good and redirecting to http://"$2"/"
	echo "</body>"
	echo "</html>"
}

! empty "$FORM_reboot" && {

display_form <<EOF
start_form
field||spacer1
string|<br />
string|<h2>
string|@TR<<Rebooting... >>@TR<<This will take up to >>$timeout@TR<< seconds. >>@TR<<Your browser should refresh automatically when completed.>>
string|</h2>
end_form
EOF

	# Now reboot...
	oxsh -u -x "reload in 1" 2>&- > /dev/null

	# Automatically redirect to the front page
	redirection $timeout "/cgi-bin/webif/info-system.sh"

}

! empty "$FORM_factory" && {

display_form <<EOF
start_form
field||spacer1
string|<br />
string|<h2>
string|@TR<<Rebooting... >>@TR<<All configuration will be deleted. >>@TR<<This will take up to >>$timeout@TR<< seconds. >>@TR<<Your browser should refresh automatically when completed.>>
string|</h2>
end_form
EOF

	# Now clear all configuration, and reboot...
	oxsh -u -x "write erase" 2>&- > /dev/null
	oxsh -u -x "reload in 1" 2>&- > /dev/null

	# Automatically redirect to the front page
	redirection $timeout "/cgi-bin/webif/info-system.sh"
}

empty "$FORM_reboot" && empty "$FORM_factory" && {

display_form <<EOF
onclick|submit_reboot
start_form
field||spacer1
string|<br />
formtag_begin|reboot|$SCRIPT_NAME
submit|reboot|@TR<<Reboot>>
formtag_end
string|<br />
helpitem|Reboot
helptext|Helptext Reboot#Rebooting will cause your router to restart. Any unsaved configuration changes will be lost.
end_form
EOF

display_form <<EOF
onclick|submit_factory
start_form
field||spacer1
string|<br />
formtag_begin|factory|$SCRIPT_NAME
submit|factory|@TR<<Factory Reboot>>
formtag_end
string|<br />
helpitem|Factory Reboot
helptext|Helptext factory Reboot#Factory Reboot will erase all your saved configuration settings and the router will restart. You may need to reconfigure IP settings and renew DHCP leases after doing this.
end_form
EOF
}

footer ?>

<!--
##WEBIF:name:System:910:Reboot
-->
