#!/usr/bin/webif-page
<? 
. /usr/lib/webif/webif.sh
. /usr/lib/webif/oxsh.sh

config_cb() {
	config_get TYPE "$CONFIG_SECTION" TYPE
	case "$TYPE" in
		user)
			password_cfg="$CONFIG_SECTION"
		;;
	esac
}


uci_load "user"

if empty "$FORM_submit_password"; then
	# initialize all values
	config_get passwd admin password
else
	validate <<EOF
string|FORM_pw1|Password|required min=5 max=512|$FORM_pw1
EOF
	equal "$FORM_current_password" "" || {
		ERROR="$ERROR You must enter the current password<br />"
	}

	# Note deliberately reading from UCI to get current password - what
	# should really happen is encrypt password and then compare to encrypted
	# value
	passwd=`uci get user.admin.password`
	enc_current=`cryptpw -a md5  -s "$passwd" "$FORM_current_passwd"`

	equal "$enc_current" "$passwd" || {
		ERROR="$ERROR Current password is incorrect<br />"
	}
	equal "$FORM_pw1" "$FORM_pw2" || {
		ERROR="$ERROR New passwords do not match<br />"
	}

	empty "$ERROR" && {
	        enc_pw1=`cryptpw -a md5 "$FORM_pw1"`
		oxconfig "username admin password $FORM_pw1"

		# Make permanent
		[ -z "$ERROR" ] && oxwrite
	}
fi

header "System" "Password" "@TR<<Password Configuration>>"

display_form <<EOF
onchange|modechange
start_form|@TR<<Password Change>>
formtag_begin|submit_password|$SCRIPT_NAME
field|@TR<<Current Password>>:
password|current_passwd
field|@TR<<New Password>>:
password|pw1
field|@TR<<Confirm New Password>>:
password|pw2
field||spacer1
string|<br />
submit|submit_password|@TR<<Save Password>>
submit||@TR<<Cancel>>
formtag_end
helpitem|Password
helptext|Password_helptext#Change the GUI access password. One must enter the current password, and the new password twice to ensure correct password is used.
end_form
EOF

footer ?>

<!--
##WEBIF:name:System:250:Password
-->
