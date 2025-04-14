#!/usr/bin/webif-page
<?
. "/usr/lib/webif/webif.sh"

header "Status" "CATV" "@TR<<CATV Status>>"
 
present=`cat /proc/catv/module_present`
live=`cat /proc/gpio/signal/catv_live`

[ -n "$present" ] && [ "$present" -ne 0 ] && {

catv_status=`oxsh -x "show catv" | grep Admin | cut -d' ' -f 2`
catv_filter=`oxsh -x "show catv" | grep Filter | cut -d' ' -f 2`
catv_opt_pwr=`oxsh -x "show catv" | grep optical | cut -d' ' -f 6`
catv_signal=`oxsh -x "show catv" | grep optical | cut -d',' -f 1`

catv_signal=${catv_signal%%*\\t}		# Drop leading whitespace

#Test
#catv_opt_pwr="-20.999"
#catv_opt_pwr="-10.100"
#catv_opt_pwr="-10.001"
#catv_opt_pwr="-10.000"
#catv_opt_pwr="-9.900"
#catv_opt_pwr="-0.100"
#catv_opt_pwr="0.000"
#catv_opt_pwr="0.001"
#catv_opt_pwr="1.000"

catv_opt_pwr_int=`echo $catv_opt_pwr | cut -d'.' -f 1`
catv_opt_pwr_frac=`echo $catv_opt_pwr | cut -d'.' -f 2`
catv_opt_pwr_real=$catv_opt_pwr

let catv_opt_pwr_int=$catv_opt_pwr_int*1000

if  [ "$catv_opt_pwr_int" -ge 0 ]; then
  let catv_opt_pwr=$catv_opt_pwr_int+$catv_opt_pwr_frac
else
  let catv_opt_pwr=$catv_opt_pwr_int-$catv_opt_pwr_frac
fi


if [ "$live" -eq 0 ]; then
  colour="red"
  bar_text=" "
  progress_text="No CATV signal detected. Contact your CATV provider."
  CATV_GRAPH_PERCENT=15
elif [ "$catv_opt_pwr" -lt -10000 ]; then
  colour="red"
  bar_text=" "
  progress_text="CATV power ($catv_opt_pwr_real dBm) too low. Contact your CATV provider."
  CATV_GRAPH_PERCENT=25
elif [ "$catv_opt_pwr" -gt 0 ]; then
  colour="red"
  bar_text=" "
  CATV_GRAPH_PERCENT=90
  progress_text="CATV power ($catv_opt_pwr_real dBm) too high - risk of damage! Contact your CATV provider."
else 
  colour="green"
  bar_text="$catv_opt_pwr_real dBm"
  let calc=$catv_opt_pwr+10000
  let calc=$calc*6
  let calc=$calc/1000
  let calc=$calc+25

  CATV_GRAPH_PERCENT=$calc
  progress_text="CATV power is good"
fi

if [ "$live" = "1" ]; then
  catv_live="Present"
else
  catv_live="Not detected"
fi

if [ "$catv_filter" = "enabled" ]; then
  premium_channels="Disabled"
else
  premium_channels="Enabled"
fi

if [ "$catv_status" = "enabled" ]; then
  catv_status="Enabled"
else
  catv_status="Disabled"
fi

#field|@TR<<Optical Power>>|catv_opt_pwr_real
#string|$catv_opt_pwr_real dBm |
#field|@TR<<Optical Signal>>|catv_signal
#string|$catv_signal
display_form << EOF
start_form|@TR<<CATV>
field|@TR<<CATV Status>>|catv_status
string|$catv_status
field|@TR<<Premium Channels>>|catv_filter
string|$premium_channels
field|@TR<<CATV Signal>>|catv_live
string|$catv_live
field||spacer1
string|<br />
field|@TR<<Optical Signal>>|catv_opt
progressbar|power|$progress_text|300|$CATV_GRAPH_PERCENT%|$bar_text||$colour
helpitem|CATV Module
helptext|Helptext CATV Module#Optical input power must be between -10dBm and 0dBm to ensure correct operation. If the power is outside this range, contact your CATV provider.
end_form|
EOF
}

[ -z "$present" ] || [ "$present" -eq 0 ] && {
display_form << EOF
start_form|@TR<<CATV>>
string|@TR<<CATV module not present on this model>>
end_form|
EOF
}

footer ?>
<!--
##WEBIF:name:Status:500:CATV
-->
