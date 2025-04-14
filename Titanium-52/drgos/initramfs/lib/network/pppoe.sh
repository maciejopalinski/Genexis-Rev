scan_pppoe() {
	scan_ppp "$@"
}

setup_interface_pppoe() {
	local iface="$1"
	local config="$2"
	
	for module in slhc ppp_generic pppox pppoe; do
		/sbin/insmod $module 2>&- >&-
	done

	# make sure the network state references the correct ifname
	scan_ppp "$config"
	config_get ifname "$config" ifname
	set_interface_ifname "$config" "$ifname"

	# Check for AC name and service parameters to give to rp-pppoe.so
	config_get acname "$config" acname
	config_get acservice "$config" acservice

	config_get mtu "$cfg" mtu
	mtu=${mtu:-1492}
	start_pppd "$config" \
		plugin rp-pppoe.so \
	        ${acname:+rp_pppoe_ac "$acname"} \
	        ${acservice:+rp_pppoe_service "$acservice"} \
		mtu $mtu mru $mtu \
		"nic-$iface"
}


stop_interface_pppoe()
{
    local cfg=$1; shift
    stop_pppd "$cfg"
}
