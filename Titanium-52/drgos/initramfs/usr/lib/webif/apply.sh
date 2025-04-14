#!/bin/ash
#
#
# Handler for config application of all types.
#
#   Types supported:
#	uci-*		UCI config files
#	file-*		Undefined format for whatever
#	edited-files-*  raw edited files
#
#
. /usr/lib/webif/functions.sh
. /lib/config/uci.sh

config_cb() {
	config_get TYPE "$CONFIG_SECTION" TYPE
	case "$TYPE" in
		timezone)
			timezone_cfg="$CONFIG_SECTION"
		;;
	esac
}

HANDLERS_file='
	hosts) rm -f /etc/hosts; mv $config /etc/hosts; killall -HUP dnsmasq ;;
	ethers) rm -f /etc/ethers; mv $config /etc/ethers; killall -HUP dnsmasq ;;
'

# for some reason a for loop with "." doesn't work
eval "$(cat /usr/lib/webif/apply-*.sh 2>&-)"

mkdir -p "/tmp/.webif"
_pushed_dir=$(pwd)
cd "/tmp/.webif"

# edited-files/*		user edited files - stored with directory tree in-tact
for edited_file in $(find "/tmp/.webif/edited-files/" -type f 2>&-); do
	target_file=$(echo "$edited_file" | sed s/'\/tmp\/.webif\/edited-files'//g)
	echo "@TR<<Processing>> $target_file"
	fix_symlink_hack "$target_file"
	if tr -d '\r' <"$edited_file" >"$target_file"; then
		rm "$edited_file" 2>&-
	else
		echo "@TR<<Critical Error>> : @TR<<Could not replace>> $target_file. @TR<<Media full>>?"
	fi
done
# leave if some files not applied
rm -r "/tmp/.webif/edited-files" 2>&-

# file-*		other config files
for config in $(ls file-* 2>&-); do
	name=${config#file-}
	echo "@TR<<Processing>> @TR<<config file>>: $name"
	eval 'case "$name" in
		'"$HANDLERS_file"'
	esac'
done


# config-conntrack	  Conntrack Config file
for config in $(ls config-conntrack 2>&-); do
	echo '@TR<<Applying>> @TR<<conntrack settings>> ...'
	fix_symlink_hack "/etc/sysctl.conf"
	# set any and all net.ipv4.netfilter settings.
	for conntrack in $(grep ip_ /tmp/.webif/config-conntrack); do
		variable_name=$(echo "$conntrack" | cut -d '=' -f1)
		variable_value=$(echo "$conntrack" | cut -d '"' -f2)
		echo "&nbsp;@TR<<Setting>> $variable_name to $variable_value"
		remove_lines_from_file "/etc/sysctl.conf" "net.ipv4.netfilter.$variable_name"
		echo "net.ipv4.netfilter.$variable_name=$variable_value" >> /etc/sysctl.conf
	done
	sysctl -p 2>&- 1>&- # reload sysctl.conf
	rm -f /tmp/.webif/config-conntrack
	echo '@TR<<Done>>'
done

# init_theme - initialize a new theme
init_theme() {
	echo '@TR<<Initializing theme ...>>'	
	uci_load "webif"
	newtheme="$CONFIG_theme_id"	
	# if theme isn't present, then install it		
	! exists "/www/themes/$newtheme/webif.css" && {
		install_package "webif-theme-$newtheme"	
	}
	if ! exists "/www/themes/$newtheme/webif.css"; then
		# if theme still not installed, there was an error
		echo "@TR<<Error>>: @TR<<installing theme package>>."
	else
		# create symlink to new active theme if its not already set right
		current_theme=$(ls /www/themes/active -l | cut -d '>' -f 2 | sed s/'\/www\/themes\/'//g)
		! equal "$current_theme" "$newtheme" && {
			rm /www/themes/active
			ln -s /www/themes/$newtheme /www/themes/active
		}
	fi		
	echo '@TR<<Done>>'
}

# switch_language (old_lang)  - switches language if changed
switch_language() {
	oldlang="$1"
	uci_load "webif"
	newlang="$CONFIG_general_lang"
	! equal "$newlang" "$oldlang" && {
		echo '@TR<<Applying>> @TR<<Installing language pack>> ...'
		# if not English then we install language pack
		! equal "$newlang" "en" && {
			# build URL for package
			#  since the original webif may be installed to, have to make sure we get latest ver
			webif_version=$(ipkg status webif | awk '/Version:/ { print $2 }')
			xwrt_repo_url=$(cat /etc/ipkg.conf | grep X-Wrt | cut -d' ' -f3)
			# always install language pack, since it may have been updated without package version change
			ipkg install "${xwrt_repo_url}/webif-lang-${newlang}_${webif_version}_all.ipk" -force-reinstall -force-overwrite | uniq
			# switch to it if installed, even old one, otherwise return to previous
			if equal "$(ipkg status "webif-lang-${newlang}" |grep "Status:" |grep " installed" )" ""; then
				echo '@TR<<Error installing language pack>>!'
			fi
		}
		echo '@TR<<Done>>'
	}
}

uci_load_originals() {
	local cfsection
	config_load "$1"
	for cfsection in $CONFIG_SECTIONS; do
		config_rename "$cfsection" "orig_$cfsection"
	done
	CONFIG_orig_SECTION="$CONFIG_SECTIONS"
}

uci_unset_originals() {
	local cfsection
	local oldvar
	for cfsection in $CONFIG_orig_SECTION; do
		for oldvar in $(set | grep "^CONFIG_${cfsection}_" | sed -e 's/\(.*\)=.*$/\1/'); do
			unset "$oldvar"
		done
	done
	unset CONFIG_orig_SECTION
}

#
# now apply any UCI config changes
#
mod_list="";
cd /tmp/.webif-uci;
for package in *; do
	echo "@TR<<Committing>> ${package} ..."

	cat $package >> /tmp/.uci/$package;
	rm $package;
	mod_list="$mod_list $package";
done

#
# cleanup
#
cd "$_pushed_dir"

