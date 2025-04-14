#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh
uci_load usp

check_versions() {
	local ldr1
	local ldr2
	local major1
	local minor1
	local micro1
	local type1
	local version1
	local major2
	local minor2
	local micro2
	local type2
	local version2

	# Only one parameter, so one of the loader slots is empty
	if [ -z "$2" ]; then
		echo $1
		exit 0
	fi

	# Both the same - easy to deal with
	if [ "$1" == "$2" ]; then
		echo $1
		exit 0
	fi

	ldr1=`echo $1 | cut -d'-' -f 3`
	type1=`echo $1 | cut -d'-' -f 4`
	ldr2=`echo $2 | cut -d'-' -f 3`
	type2=`echo $2 | cut -d'-' -f 4`
	
	major1=`echo $ldr1 | cut -d'.' -f 1`
	minor1=`echo $ldr1 | cut -d'.' -f 2`
	micro1=`echo $ldr1 | cut -d'.' -f 3`

	major2=`echo $ldr2 | cut -d'.' -f 1`
	minor2=`echo $ldr2 | cut -d'.' -f 2`
	micro2=`echo $ldr2 | cut -d'.' -f 3`

	if [ "$major1" -gt "$major2" ]; then echo $1; exit 0
	elif [ "$major1" -lt "$major2" ]; then echo $2; exit 0
	fi

	if [ "$minor1" -gt "$minor2" ]; then echo $1; exit 0
	elif [ "$minor1" -lt "$minor2" ]; then echo $2; exit 0
	fi

	if [ "$micro1" -gt "$micro2" ]; then echo $1; exit 0
	elif [ "$micro1" -lt "$micro2" ]; then echo $2; exit 0
	fi

	case $type1 in
		R)	type1=4;;
		RC*)	version1=${type1##RC}
			type1=3
			;;
		DEV*)	version1=${type1##DEV}
			type1=2
			;;
		*)	type1=1;;
	esac

	case $type2 in
		R)	type2=4;;
		RC*)	version2=${type2##RC}
			type2=3
			;;
		DEV*)	version2=${type2##DEV}
			type2=2
			;;
		*)	type2=1;;
	esac

	if [ "$type1" -gt "$type2" ]; then echo $1; exit 0
	elif [ "$type1" -lt "$type2" ]; then echo $2; exit 0
	fi

	# Either -RCx or -DEVx, so check versions
	if [ "$version1" -gt "$version2" ]; then echo $1; exit 0
	elif [ "$version1" -lt "$version2" ]; then echo $2; exit 0
	fi

	echo "Error determining bootloader"
}


header "Info" "System" "@TR<<System Information>>"

config_get ethaddr eth ethaddr
ethaddr=`echo $ethaddr | tr [:lower:] [:upper:]`
config_get prodname product prodname
config_get prodnum product prodnum
config_get proddate product proddate
config_get serialnum product serialnum
config_get version product version
config_get platform product platform

bootloader1=`cat /proc/mtd | grep "Bootloader1" | cut -d':' -f 1`
bootloader2=`cat /proc/mtd | grep "Bootloader2" | cut -d':' -f 1`
bootldr1=`cat /dev/$bootloader1 | grep -m 1 drgldr- | cut -d' ' -f 1 | cut -d'-' -f 1-4 | uniq`
bootldr2=`cat /dev/$bootloader2 | grep -m 1 drgldr- | cut -d' ' -f 1 | cut -d'-' -f 1-4 | uniq`

# Figure out which bootloader was used - if bootloader supports providing this
# information via the kernel bootargs then use that information, else use version
# numbers etc to figure it out...
cmdline=`cat /proc/cmdline`
for pair in $cmdline; do
  param=${pair%%\=*}
  value=${pair##*\=}
  
  if [ "$param" == "bootloader" ]; then
    bootloader_used="$value"
  fi
done

if [ -n "$bootloader_used" ]; then
  if [ "$bootloader_used" == "$bootldr1" ]; then
    bootloader=$bootldr1
  fi
  if [ "$bootloader_used" == "$bootldr2" ]; then
    bootloader=$bootldr2
  fi
else
  # No info in bootargs, so try to figure it out from the versions
  bootloader=`check_versions $bootldr1 $bootldr2`
fi

firmware=`uname -r`
firmware=`echo $firmware | awk -F\- '{print $2"-"$3"-"$4"-"$5}'`

# set unset vars
version="${version:-0.0}"

display_form <<EOF
start_form|@TR<<Device Information>>
field|@TR<<Platform>>|platform
string|$platform
field|@TR<<Product Name>>|prodname
string|$prodname
field|@TR<<Product Number>>|prodnum
string|$prodnum
field|@TR<<Production Date>>|proddate
string|$proddate
field|@TR<<Hardware Revision>>|version
string|$version
field|@TR<<Serial Number>>|serialnum
string|$serialnum
field|@TR<<MAC Address>>|ethaddr
string|$ethaddr
end_form
EOF

display_form <<EOF
start_form|@TR<<Software Information>>
field|@TR<<Bootloader Revision>>|bootloader
string|$bootloader
field|@TR<<Firmware Revision>>|firmware
string|$firmware
end_form
EOF

footer ?>
<!--
##WEBIF:name:Info:100:Status
-->
