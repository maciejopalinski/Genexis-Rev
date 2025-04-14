#!/bin/sh
# Copyright (C) 2006 OpenWrt.org

# DEBUG="echo"

debug_config_sh=0
config_sh_log_file=/tmp/config_sh.log

[ -f /tmp/debug_config_sh ] && {
  debug_config_sh=1
  echo "config_sh[$0 $@] started at $(date)" >> $config_sh_log_file
}

dbg_log() {
  [ $debug_config_sh = 1 ] && echo "$@" >> $config_sh_log_file
}

. /etc/functions.sh
config_load usp
config_load system

find_config() {
	local iftype device iface ifaces ifn
	for ifn in $interfaces; do
		config_get iftype "$ifn" type
		config_get iface "$ifn" ifname
		case "$iftype" in
			bridge) config_get ifaces "$ifn" ifnames;;
		esac
		config_get device "$ifn" device
		for ifc in $device $iface $ifaces; do
			[ ."$ifc" = ."$1" ] && {
				echo "$ifn"
				return 0
			}
		done
	done

	return 1;
}

RESOLV_CONF_DYN_PREFACE="/tmp/resolv.conf.auto.dyn"

#------------------------------------------------------------------------
# purpose: remove related dhcpc installed dns config
dhcpc_remove_nameservers() {
  local interface="$1"
  # remove any tmp dhcpc file for nameservers
  [ -f "$RESOLV_CONF_DYN_PREFACE.dhcpc.${interface}" ] && {
    rm -f "$RESOLV_CONF_DYN_PREFACE.dhcpc.${interface}"
    #re-evaluate dnsmasq dynamic settings
    . /bin/dns_eval.sh
    dns_evaluate "dhcp-rmv:$1"
  }
}
#------------------------------------------------------------------------
# purpose: remove related pppd installed dns config 
pppd_remove_nameservers() {
  local interface="$1"
  local unit="$2"
  # remove tmp dhcpc file if related
  [ -f "$RESOLV_CONF_DYN_PREFACE.ppp.${unit}" ] && {
    rm -f "$RESOLV_CONF_DYN_PREFACE.ppp.${unit}"
    #re-evaluate dnsmasq dynamic settings
    . /bin/dns_eval.sh
    dns_evaluate "ppp-rmv:$1 u:$2"
  }
}

#------------------------------------------------------------------------
# purpose: remove dhcpc installed gws when config changed to another ip method than dhcpc
# issue: ? route del can fail when interface is down, and when interface comes back up, then routes are still existing?
dhcpc_remove_option3_gw() {
  # remove old dhcpc option 3 gw routes using file cached gw, dev and met
  local interface="$1"
  DHCPC_ROUTE_DEFAULT_FILE="/tmp/dhcpc-route-default-$interface"
  DHCPC_ROUTE_HISTORY_FILE="/tmp/dhcpc-route-history-$interface"

  if [ -f $DHCPC_ROUTE_DEFAULT_FILE ]
  then
     # $line format: "gw $nh_gw dev $interface metric $met"
     while read line
     do
       dbg_log "route del -net 0.0.0.0 $line"
       ret=`route del -net 0.0.0.0 $line`
     done <$DHCPC_ROUTE_DEFAULT_FILE
     rm -f $DHCPC_ROUTE_DEFAULT_FILE
  fi

  if [ -f $DHCPC_ROUTE_HISTORY_FILE ]
  then
     # $line format: "-net $net_id gw $nh_gw dev $interface metric $met"
     while read line
     do
       dbg_log "route del $line"
       ret=`route del $line`
     done <$DHCPC_ROUTE_HISTORY_FILE
     rm -f $DHCPC_ROUTE_HISTORY_FILE
  fi

  #done in hotplug event. right?
  #. /lib/network/route.sh
  #route_fixup
}

VENDOR_INFO_HISTORY="/tmp/gaps-vendor-info-his"
dhcpc_remove_option43() {
  local interface="$1"
  local mgmt_dev=
  local mgmt_if=`uci get route.mgmt_src_if 2> /dev/null`
  [ -z "$mgmt_if" ] && mgmt_if=`uci get network.default.wan_if 2> /dev/null`
  [ -n "$mgmt_if" ] && mgmt_dev=`cli_intf2dev $mgmt_if`
  [ -n "$mgmt_dev" ] && [ "$interface" = "$mgmt_dev" ] && {
     rm -f $VENDOR_INFO_HISTORY
     echo "gaps.client.id=" > /tmp/mafifo
     echo "gaps.client.mode=" > /tmp/mafifo
     echo "gaps.client.vlan=" > /tmp/mafifo
     echo "gaps.server.host=" > /tmp/mafifo
     logger -p local4.notice "gaps: dev=$1 if=$mgmt_if rmv dhcp-opts"
  }
}

scan_interfaces() {
	local cfgfile="$1"
	local mode iftype iface ifname device
	interfaces=
	config_cb() {
		case "$1" in
			interface)
				config_set "$2" auto 1
			;;
		esac
		config_get iftype "$CONFIG_SECTION" TYPE
		case "$iftype" in
			interface)
				config_get proto "$CONFIG_SECTION" proto
				append interfaces "$CONFIG_SECTION"
				config_get iftype "$CONFIG_SECTION" type
				config_get ifname "$CONFIG_SECTION" ifname
				config_get device "$CONFIG_SECTION" device
				config_set "$CONFIG_SECTION" device "${device:-$ifname}"
				case "$iftype" in
					bridge)
						config_set "$CONFIG_SECTION" ifnames "${device:-$ifname}"
						config_set "$CONFIG_SECTION" ifname br-"$CONFIG_SECTION"
					;;
				esac
				( type "scan_$proto" ) >/dev/null 2>/dev/null && eval "scan_$proto '$CONFIG_SECTION'"
			;;
		esac
	}
	config_load "${cfgfile:-network}"
}

add_vlan() {
	local vif="${1%\.*}"
	
	[ "$1" = "$vif" ] || ifconfig "$1" >/dev/null 2>/dev/null || {
		ifconfig "$vif" up 2>/dev/null >/dev/null || add_vlan "$vif"
		$DEBUG vconfig add "$vif" "${1##*\.}"

		PRIORITY="0 1 2 3 4 5 6 7"
		for i in $PRIORITY; do
			$DEBUG vconfig set_egress_map "${vif}.${1##*\.}" $i $i
		done

		return 0
	}
	return 1
}

add_vlan_index() {
	local vif="${1%\_*}"
	
	[ "$1" = "$vif" ] || ifconfig "$1" >/dev/null 2>/dev/null || {
		ifconfig "$vif" up 2>/dev/null >/dev/null || add_vlan "$vif"
		ip link add link "$vif" name "$1" type macvlan
		return 0
	}
	return 1
}

# sort the device list, drop duplicates
sort_list() {
	local arg="$*"
	(
		for item in $arg; do
			echo "$item"
		done
	) | sort -u
}

# Create the interface, if necessary.
# Return status 0 indicates that the setup_interface() call should continue
# Return status 1 means that everything is set up already.

prepare_interface() {
	local iface="$1"
	local config="$2"
	local macaddr

	# if we're called for the bridge interface itself, don't bother trying
	# to create any interfaces here. The scripts have already done that, otherwise
	# the bridge interface wouldn't exist.
	[ "br-$config" = "$iface" -o -e "$iface" ] && return 0;
	
	ifconfig "$iface" 2>/dev/null >/dev/null && {
		# make sure the interface is removed from any existing bridge and deconfigured 
		ifconfig "$iface" 0.0.0.0
		unbridge "$iface"
	}

	# Setup VLAN interfaces
	add_vlan_index "$iface" && return 1
	add_vlan "$iface" && return 1
	ifconfig "$iface" 2>/dev/null >/dev/null || return 0

	# Setup bridging
	config_get iftype "$config" type
	config_get stp "$config" stp
	config_get macaddr "$config" macaddr
	case "$iftype" in
		bridge)
			[ -x /usr/sbin/brctl ] && {
				ifconfig "br-$config" 2>/dev/null >/dev/null && {
					local newdevs=

					config_get devices "$config" device
					for dev in $(sort_list "$devices" "$iface"); do
						append newdevs "$dev"
					done
					uci_set_state network "$config" device "$newdevs"
					$DEBUG brctl addif "br-$config" "$iface"
					# Bridge existed already. No further processing necesary
				} || {
					$DEBUG brctl addbr "br-$config"
					$DEBUG brctl setfd "br-$config" 0
					$DEBUG ifconfig "br-$config" up
					$DEBUG brctl addif "br-$config" "$iface"
					$DEBUG brctl stp "br-$config" ${stp:-off}
					# Creating the bridge here will have triggered a hotplug event, which will
					# result in another setup_interface() call, so we simply stop processing
					# the current event at this point.
				}
				ifconfig "$iface" ${macaddr:+hw ether "$macaddr"} up 2>/dev/null >/dev/null
				return 1
			}
		;;
	esac
	return 0
}

set_interface_ifname() {
	local config="$1"
	local ifname="$2"

	config_get device "$1" device
	uci_set_state network "$config" ifname "$ifname"
	uci_set_state network "$config" device "$device"
}

setup_interface_none() {
	env -i ACTION="ifup" INTERFACE="$2" DEVICE="$1" PROTO=none /sbin/hotplug-call "iface" &
}

setup_interface_static() {
	local iface="$1"
	local config="$2"

  if [ -z "$APPLY_CHANGES" ]; then
    # in the system startup phase
    config_get ipaddr "$config" ipaddr
    config_get netmask "$config" netmask
    config_get ip6addr "$config" ip6addr

    [ -z "$ipaddr" -o -z "$netmask" ] && [ -z "$ip6addr" ] && return 1

    config_get gateway "$config" gateway
    config_get ip6gw "$config" ip6gw
    config_get dns "$config" dns
    config_get bcast "$config" broadcast
  else
    # This happens in network reconfiguration so "config_get" must not be used
    # to get the new configuration of an interface because these parameters
    # may be stale. config_get gets the value of a parameter from environment
    # variable "CONFIG_$config_xyz" which is exported by config_load.
    # config_load exports environment variables from "uci -P /var/state
    # conf_file". This may occur before the contents of uci stored /var/state/
    # is updated, for instance, when changing the operation mode of wan from PPPoE
    # to static, some stale information like gateway(provided by PPPoE) is
    # still there because PPP relevant scripts may have not removed those
    # information when config_load is running. So the consequence is the
    # previous stale gateway is still set to the system. 
    # In this case, "uci get" must be used to get the new configuration
    # parameters set by management framework. Note "-P /var/state" or "-p
    # /var/state" must not be passed to uci.
    ipaddr=$(uci -q  get network.$config.ipaddr)
    netmask=$(uci -q get network.$config.netmask)
    ip6addr=$(uci -q get network.$config.ip6addr)

    [ -z "$ipaddr" -o -z "$netmask" ] && [ -z "$ip6addr" ] && return 1

    gateway=$(uci -q get network.$config.gateway)
    ip6gw=$(uci -q   get network.$config.ip6gw)
    dns=$(uci -q     get network.$config.dns)
    bcast=$(uci -q   get network.$config.broadcast)
  fi

	if [ -z "$bcast" ]; then
    [ -n "$ipaddr" ] && $DEBUG ifconfig "$iface" "$ipaddr" netmask "$netmask"
  else
    [ -n "$ipaddr" ] && $DEBUG ifconfig "$iface" "$ipaddr" netmask "$netmask" "${bcast:+broadcast $bcast}"
  fi

	[ -n "$ip6addr" ] && $DEBUG ifconfig "$iface" add "$ip6addr"
	[ -n "$gateway" ] && $DEBUG route add default gw "$gateway" dev "$iface" metric 1

	[ -n "$ip6gw" ] && $DEBUG route -A inet6 add default gw "$ip6gw" dev "$iface"

	[ -n "$dns" ] && {
		for ns in $dns; do
			grep "$ns" /tmp/resolv.conf.auto 2>/dev/null >/dev/null || {
				echo "nameserver $ns" >> /tmp/resolv.conf.auto
			}
		done
	}
	
	#remove this is done in the hotplug event, make sure it's working
	#. /lib/network/route.sh
	#route_fixup

	env -i ACTION="ifup" INTERFACE="$config" DEVICE="$iface" PROTO=static /sbin/hotplug-call "iface" &
}

setup_interface_alias() {
	local config="$1"
	local parent="$2"
	local iface="$3"

	config_get cfg "$config" interface
	[ "$parent" == "$cfg" ] || return 0

	# alias counter
	config_get ctr "$parent" alias_count
	ctr="$(($ctr + 1))"
	config_set "$parent" alias_count "$ctr"

	# alias list
	config_get list "$parent" aliases
	append list "$config"
	config_set "$parent" aliases "$list"

	set_interface_ifname "$config" "$iface:$ctr"
	config_get proto "$config" proto
	case "${proto:-static}" in
		static)
			setup_interface_static "$iface:$ctr" "$config"
		;;
		*) 
			echo "Unsupported type '$proto' for alias config '$config'"
			return 1
		;;
	esac
}

# All options inherited from WAN side DHCP server. These options will be added
# to option 55(requested option list) in DHCP requests from WAN.
# $1 interface name
config_requested_opts() {
	local source_interface=$(/sbin/uci -q get network.dhcpc.source_interface)
	local opt_numbers
	local opt_name

  # Add requested options for wan interface from which dhcp server inherits
  	scan_interfaces
	config_get ifname $source_interface ifname

	[ "$ifname" == "$1" ] && {
		opt_numbers=$(/sbin/uci -q get network.dhcpc.dhcp_option)

		for number in $opt_numbers; do
			opt_number=${number%,*}

			# Convert option number to option name
			case $opt_number in
				"name-server")      opt_name="namesrv";;
				"dns-server")       opt_name="dns";;
				"swap-server")      opt_name="swapsrv";;
				"root-path")        opt_name="rootpath";;
				"ntp-server")       opt_name="ntpsrv";;
				"tftp-server-name") opt_name="tftp";;
				"bootfile-name")    opt_name="bootfile";;
				"1")    opt_name="subnet";;
				"2")    opt_name="timezone";;
				"3")    opt_name="router";;
				"4")    opt_name="timesrv";;
				"5")    opt_name="namesrv";;
				"6")    opt_name="dns";;
				"7")    opt_name="logsrv";;
				"8")    opt_name="cookiesrv";;
				"9")    opt_name="lprsrv";;
				"12")   opt_name="hostname";;
				"13")   opt_name="bootsize";;
				"15")   opt_name="domain";;
				"16")   opt_name="swapsrv";;
				"17")   opt_name="rootpath";;
				"23")   opt_name="ipttl";;
				"26")   opt_name="mtu";;
				"28")   opt_name="broadcast";;
				"40")   opt_name="nisdomain";;
				"41")   opt_name="nissrv";;
				"42")   opt_name="ntpsrv";;
				"43")   opt_name="vendorinfo";;
				"44")   opt_name="wins";;
				"50")   opt_name="requestip";;
				"51")   opt_name="lease";;
				"53")   opt_name="dhcptype";;
				"54")   opt_name="serverid";;
				"56")   opt_name="message";;
				"60")   opt_name="vendorclass";;
				"61")   opt_name="clientid";;
				"66")   opt_name="tftp";;
				"67")   opt_name="bootfile";;
				"77")   opt_name="userclass";;
				"119")  opt_name="search";;
				"121")  opt_name="classlessroute";;
				"252")  opt_name="wpad";;
				*)      opt_name="option""$number";;
			esac

			# Add a supported option only
			[ -n "$opt_name" ] && append requested_opts "-O $opt_name"
		done
	}
}

setup_interface() {
	local iface="$1"
	local config="$2"
	local proto
	local macaddr
	local firmware_name
	local model_name
	local dslforum
	local service_name
	local sw_version
	local kill_udhcpc=1
	local kill_pppd=1

	firmware_name=$(cat /etc/drgos_version)
	if [ "$firmware_name" != "" ]; then
		sw_version="$firmware_name"
	fi

	config_get model_name "product" prodname
	if [ "$model_name" != "" ]; then
		new_model_name=`echo $model_name | tr A-Z a-z` > /dev/null;
		sw_version="$sw_version","$new_model_name"
	fi

	dslforum=dslforum.org
	if [ "$dslforum" != "" ]; then
		sw_version="$sw_version","$dslforum"
	fi

	[ -n "$config" ] || {
		config=$(find_config "$iface")
		[ "$?" != 0 ] && {
		   dbg_log "find_config failure, exited"
		   return 1
		}
	}

	config_get service_name "$config" service
	[ -n "$service_name" ] && sw_version="$sw_version,$service_name"
	echo $sw_version > /tmp/vendor_$config

	proto="${3:-$(config_get "$config" proto)}"

	prepare_interface "$iface" "$config" || {
		dbg_log "prepare_interface failure, exited"
		return 0
	}

	[ "$iface" = "br-$config" ] && {
		# need to bring up the bridge and wait a second for 
		# it to switch to the 'forwarding' state, otherwise
		# it will lose its routes...
		ifconfig "$iface" up
		sleep 1
	}
	
	# Interface settings
	config_get mtu "$config" mtu
	config_get macaddr "$config" macaddr
	grep "$iface:" /proc/net/dev > /dev/null && {
	    ifconfig "$iface" down
	    $DEBUG ifconfig "$iface" ${macaddr:+hw ether "$macaddr"} ${mtu:+mtu $mtu} up
	}
	
	set_interface_ifname "$config" "$iface"

	local pidfile="/var/run/$iface.pid"

	case "$proto" in
		static)
			setup_interface_static "$iface" "$config"
		;;
		dhcp)
			# Keep udhcpc running since we are in DHCP mode
			kill_udhcpc=0
			# prevent udhcpc from starting more than once
			lock "/var/lock/dhcp-$iface"
			pid="$(cat "$pidfile" 2>/dev/null)"
			if [ -d "/proc/$pid" ] && grep udhcpc "/proc/${pid}/cmdline" >/dev/null 2>/dev/null; then
				lock -u "/var/lock/dhcp-$iface"
			else
				requested_opts=""
				config_get hostname "system" hostname
				config_get proto1 "$config" proto
				config_get clientid "$config" clientid

				# don't stay running in background if dhcp is not the main proto on the interface (e.g. when using pptp)
				[ ."$proto1" != ."$proto" ] && dhcpopts="-n -q"
				config_requested_opts "$iface"
				$DEBUG eval udhcpc -t 0 -i "$iface" $requested_opts ${hostname:+-H $hostname} ${clientid:+-c $clientid} "-V \"$sw_version\"" -b -p "$pidfile" ${dhcpopts:- -R &}
				lock -u "/var/lock/dhcp-$iface"
			fi
		;;
		none)
			setup_interface_none "$iface" "$config"
		;;
		pppoe)
			# Keep pppd running, we are in fact relying on it
			kill_pppd=0
			setup_interface_pppoe "$iface" "$config"
		;;
		*)
			if ( eval "type setup_interface_$proto" ) >/dev/null 2>/dev/null; then
				eval "setup_interface_$proto '$iface' '$config' '$proto'" 
			else
				dbg_log "Interface type $proto not supported."
				return 1
			fi
		;;
	esac
	config_set "$config" aliases ""
	config_set "$config" alias_count 0
	config_foreach setup_interface_alias alias "$config" "$iface"
	config_get aliases "$config" aliases
	[ -z "$aliases" ] || uci_set_state network "$config" aliases "$aliases"


	# Cleanup daemons still running after changing IP address mode
	# Start to check udhcpc
	if [ "$kill_udhcpc" = "1" ]; then
	  dhcpc_remove_option3_gw "$iface"
	  dhcpc_remove_nameservers "$iface"
          dhcpc_remove_option43 "$iface"
	  stop_interface_dhcp "$iface"
	fi
	# Check pppd
	if [ "$kill_pppd" = "1" ]; then
    pppd_remove_nameservers "$iface" "$config"
	  stop_interface_pppoe "$config"
	fi
        #re-evaluate dnsmasq dynamic settings
        . /bin/dns_eval.sh
        dns_evaluate "if-setup:$iface"

}

unbridge() {
	local dev="$1"
	local brdev
	
	[ -x /usr/sbin/brctl ] || return 0
	brctl show | grep "$dev" >/dev/null && {
		# interface is still part of a bridge, correct that

		for brdev in $(brctl show | awk '$2 ~ /^[0-9].*\./ { print $1 }'); do
			brctl delif "$brdev" "$dev" 2>/dev/null >/dev/null
		done
	}
}


# Function to ensure the udhcpc is not running for the given interface
stop_interface_dhcp() {
    local iface="$1"
    local pidfile="/var/run/$iface.pid"
    local pid
    local ret

    [ -z "$iface" -o ! -f "$pidfile" ] && {
      dbg_log "stop_interface_dhcp(): interface name is empty or pid file doesn't " \
                                      "exist, iface=[$iface]"
      return 2
    }

    # take lock for this interface
    lock "/var/lock/dhcp-$iface"
    pid=$(cat "$pidfile" 2>/dev/null)
    dbg_log "stop_interface_dhcp(): pidfile=[$pidfile],pid=[$pid]"
    if grep udhcpc "/proc/${pid}/cmdline" >/dev/null 2>/dev/null; then
      dbg_log "stop_interface_dhcp(): killing $pid"
      kill $pid
      ret=0
    else
      dbg_log "stop_interface_dhcp(): $pid doesn't exist or it is not udhcpc"
      ret=1
    fi
    lock -u "/var/lock/dhcp-$iface"

    return $ret
}


