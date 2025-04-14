scan_ppp() {
	config_get ifname "$1" ifname
	pppdev="${pppdev:-0}"
	config_get unit "$1" unit
	[ -z "$unit" ] && {
		unit="$pppdev"
		if [ "${ifname%%[0-9]*}" = ppp ]; then
			unit="${ifname##ppp}"
			[ "$pppdev" -le "$unit" ] && pppdev="$(($unit + 1))"
		else
			pppdev="$(($pppdev + 1))"
		fi
		config_set "$1" ifname "ppp$unit"
		config_set "$1" unit "$unit"
	}
}

start_pppd() {
	local cfg="$1"; shift

	# make sure only one pppd process is started
	lock "/var/lock/ppp-${cfg}"
	local pid="$(head -n1 /var/run/ppp-${cfg}.pid 2>/dev/null)"

	# Pid files are removed when link is down, check for processes
	# in link down state as well (this is the normal case for DRG700)
	if [ -z "$pid" ]; then
	    pids=`pidof pppd`
	    for p in $pids; do
		linknamestuff=`echo \`cat /proc/$p/cmdline\` | sed 's/.*linkname//'`
		linkname=`echo ${linknamestuff%%ipparam*}`
		[ "$linkname" = "$cfg" ] && pid=$p && break
	    done
	fi

	[ -d "/proc/$pid" ] && grep pppd "/proc/$pid/cmdline" 2>/dev/null >/dev/null && {
		lock -u "/var/lock/ppp-${cfg}"
		return 0
	}

	# Workaround: sometimes hotplug2 doesn't deliver the hotplug event for creating
	# /dev/ppp fast enough to be used here
	[ -e /dev/ppp ] || mknod /dev/ppp c 108 0

	config_get device "$cfg" device
	config_get unit "$cfg" unit
	config_get username "$cfg" username
	config_get password "$cfg" password
	config_get keepalive "$cfg" keepalive

	config_get connect "$cfg" connect
	config_get disconnect "$cfg" disconnect
	config_get pppd_options "$cfg" pppd_options
	config_get_bool defaultroute "$cfg" defaultroute 1

        # bug #21086 - use noreplacedefaultroute
	[ "$defaultroute" -eq 1 ] && defaultroute="defaultroute noreplacedefaultroute" || defaultroute=""

	interval="${keepalive##*[, ]}"
	[ "$interval" != "$keepalive" ] || interval=5

	config_get_bool peerdns "$cfg" peerdns 1 
	[ "$peerdns" -eq 1 ] && peerdns="usepeerdns" || peerdns="" 
	
	config_get demand "$cfg" demand
	[ -n "$demand" ] && echo "nameserver 1.1.1.1" > /tmp/resolv.conf.auto

	config_get_bool ipv6 "$cfg" ipv6 0
	[ "$ipv6" -eq 1 ] && ipv6="+ipv6" || ipv6=""

	/usr/sbin/pppd "$@" \
		${keepalive:+lcp-echo-interval $interval lcp-echo-failure ${keepalive%%[, ]*}} \
		${demand:+precompiled-active-filter /etc/ppp/filter demand idle }${demand:-persist} \
		$peerdns \
		$defaultroute \
		${username:+user "$username" password "$password"} \
		unit "$unit" \
		linkname "$cfg" \
		ipparam "$cfg" \
		${connect:+connect "$connect"} \
		${disconnect:+disconnect "$disconnect"} \
		${ipv6} \
		${pppd_options}

	lock -u "/var/lock/ppp-${cfg}"
}

stop_pppd() {
    local cfg="$1"; shift
    local linknamestuff linkname p pids

    # make sure only one pppd process is started
    lock "/var/lock/ppp-${cfg}"
    local pid="$(head -n1 /var/run/ppp-${cfg}.pid 2>/dev/null)"

    # Pid files are removed when link is down, check for processes
    # in link down state as well (this is the normal case for DRG700)
    if [ -z "$pid" ]; then
	pids=`pidof pppd`
	for p in $pids; do
	    linknamestuff=`echo \`cat /proc/$p/cmdline\` | sed 's/.*linkname//'`
	    linkname=`echo ${linknamestuff%%ipparam*}`
	    [ "$linkname" = "$cfg" ] && pid=$p && break
	done
    fi

    if [ -d "/proc/$pid" ] && grep pppd "/proc/$pid/cmdline" 2>/dev/null >/dev/null; then
	kill $pid
	ret=0
    else
	ret=1
    fi
    lock -u "/var/lock/ppp-${cfg}"
    return $ret
}


setup_interface_ppp() {
	local iface="$1"
	local config="$2"

	config_get device "$config" device

	config_get mtu "$config" mtu
	mtu=${mtu:-1492}
	start_pppd "$config" \
		mtu $mtu mru $mtu \
		"$device"
}

stop_interface_ppp()
{
    local cfg="$1"; shift
    stop_pppd "$cfg"
}
