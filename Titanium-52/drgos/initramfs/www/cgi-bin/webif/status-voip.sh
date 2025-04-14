#!/usr/bin/webif-page
<?
. "/usr/lib/webif/webif.sh"

header "Status" "VoIP" "@TR<<VoIP Status>>"
 
# Check if there is a VoIP module found - use number of users of the
# proslic driver to figure this out
# FIXME - this doesn't work...
#present=`lsmod | grep ^proslic | awk -F" " '{ print $3 }'`
present=1

[ -n "$present" ] && [ "$present" -ne 0 ] && {

table_status_heading="string|<div class=\"status\">
	string|<h3><strong>@TR<<VoIP Status>></strong></h3>
	string|<table style=\"width: 50%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<VoIP Status>>\">
	string|<tr>
	string|<th>@TR<<Line>></th>
	string|<th>@TR<<1>></th>
	string|<th>@TR<<2>></th>
	string|</tr>"

table_statistics_heading="string|<div class=\"statistics\">
	string|<h3><strong>@TR<<Call Statistics>></strong></h3>
	string|<table style=\"width: 50%; margin-left: 2.5em; text-align: left; font-size: 0.8em;\" border=\"0\" cellpadding=\"3\" cellspacing=\"2\" summary=\"@TR<<Call Statistics>>\">
	string|<tr>
	string|<th>@TR<<Line>></th>
	string|<th>@TR<<1>></th>
	string|<th>@TR<<2>></th>
	string|</tr>"

table_end="string|</table></div>"


display_form << EOF
$table_status_heading
EOF

tmpfile=`mktemp /tmp/.webif.XXXXXX`
oxsh -x "show voip status" | grep -v "line" > $tmpfile
reg_status=`cat $tmpfile | awk -F" " '{print $2 }' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
te_status=`cat $tmpfile | awk -F" " '{print $3 }' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
rm $tmpfile

display_form <<EOF
string|<tr>
string|<td>@TR<<Registration Status>></td>
string|<td>$reg_status</td>
string|</tr><tr>
string|<td>@TR<<Handset Status>></td>
string|<td>$te_status</td>
string|</tr>
EOF

display_form <<EOF
$table_end
field||spacer1
string|<br />
EOF

display_form << EOF
$table_statistics_heading
EOF

tmpfile=`mktemp /tmp/.webif.XXXXXX`
oxsh -x "show voip statistics" | grep -v "Line" > $tmpfile

icr=`cat $tmpfile | grep "Incoming Calls Received" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
ica=`cat $tmpfile | grep "Incoming Calls Answered" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
icc=`cat $tmpfile | grep "Incoming Calls Connected" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
#icf=`cat $tmpfile | grep "Incoming Calls Failed" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`

oca=`cat $tmpfile | grep "Outgoing Calls Attempted" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
ocn=`cat $tmpfile | grep "Outgoing Calls Answered" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
occ=`cat $tmpfile | grep "Outgoing Calls Connected" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
#ocf=`cat $tmpfile | grep "Outgoing Calls Failed" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`

tdc=`cat $tmpfile | grep "Dropped Calls" | awk -F":" '{ print $2 }' | sed 's/ *//g' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`
# Convert from seconds to hh:mm:ss
tct=`cat $tmpfile | grep "Total Call Time" | awk -F":" '{ print strftime("%H:%M:%S", $2, 1) }' | sed ':a;N;$!ba;s/\n/<\/td><td>/g'`


rm $tmpfile

display_form <<EOF
string|<tr>
string|<td>@TR<<Incoming Calls Received>></td>
string|<td>$icr</td>
string|</tr><tr>
string|<td>@TR<<Incoming Calls Answered>></td>
string|<td>$ica</td>
string|</tr><tr>
string|<td>@TR<<Incoming Calls Connected>></td>
string|<td>$icc</td>
string|</tr>
field||spacer1
string<br />
string|<tr>
string|<td>@TR<<Outgoing Calls Attempted>></td>
string|<td>$oca</td>
string|</tr><tr>
string|<td>@TR<<Outgoing Calls Answered>></td>
string|<td>$ocn</td>
string|</tr><tr>
string|<td>@TR<<Outgoing Calls Connected>></td>
string|<td>$occ</td>
string|</tr>
field||spacer1
string<br />
string|<tr>
string|<td>@TR<<Dropped Calls>></td>
string|<td>$tdc</td>
string|</tr><tr>
string|<td>@TR<<Total Call Time (hh:mm:ss)>></td>
string|<td>$tct</td>
string|</tr>
EOF

display_form <<EOF
$table_end
EOF

}

[ -z "$present" ] || [ "$present" -eq 0 ] && {
display_form << EOF
start_form|@TR<<VoIP>>
string|@TR<<VoIP module not found>>
end_form|
EOF
}

footer ?>
<!--
##WEBIF:name:Status:501:VoIP
-->
