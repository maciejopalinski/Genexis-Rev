#!/bin/sh
#

. /etc/functions.sh
include /lib/network

DHCP_LEASES_PATH="/tmp/leases"
SECS_ONE_DAY=86400
SECS_ONE_HOUR=3600
SECS_ONE_MINUTE=60

show_format_time () {
    local var=""
    local ret=""
    local seconds=$1

    if [ "$seconds" -gt "$SECS_ONE_DAY" ]; then
        var=$(($seconds/$SECS_ONE_DAY))
        seconds=$(($seconds-$SECS_ONE_DAY*$var))
        ret="$ret""$var"d
    fi

    if [ "$seconds" -gt "$SECS_ONE_HOUR" ]; then
        var=$(($seconds/$SECS_ONE_HOUR))
        seconds=$(($seconds-$SECS_ONE_HOUR*$var))
        ret="$ret""$var"h
    fi

    if [ "$seconds" -gt "$SECS_ONE_MINUTE" ]; then
        var=$(($seconds/$SECS_ONE_MINUTE))
        seconds=$(($seconds-$SECS_ONE_MINUTE*$var))
        ret="$ret""$var"m
    fi

    ret="$ret""$seconds"s

    echo $ret
}

show_realtime_info () {
    local curtime=$(cat /proc/uptime)
    curtime=${curtime%%.*}

    local times=$(cat $DHCP_LEASES_PATH/$ifname.2)
    local starttime=${times%%,*}
    local leasetime=${times#*,}
    local renewtime=$(($leasetime/2))
    local rebindtime=$(($leasetime*7/8))
    local showstr

    leasetime=$(($leasetime+$starttime))
    if [ "$leasetime" -le "$curtime" ]; then
        echo "  Already expired !"
    else
        cat $DHCP_LEASES_PATH/$ifname.1 2>/dev/null

        rebindtime=$(($rebindtime+$starttime))
        if [ "$rebindtime" -le "$curtime" ]; then
            echo "        Rebinding !"
        else
            renewtime=$(($renewtime+$starttime))
            if [ "$renewtime" -le "$curtime" ]; then
                echo "         Renewing !"
            else
                renewtime=$(($renewtime-$curtime))
                showstr=`show_format_time $renewtime`
                echo "         Renew in : $showstr"
            fi

            rebindtime=$(($rebindtime-$curtime))
            showstr=`show_format_time $rebindtime`
            echo "        Rebind in : $showstr"
        fi

        leasetime=$(($leasetime-$curtime))
        showstr=`show_format_time $leasetime`
        echo "        Expire in : $showstr"

        cat $DHCP_LEASES_PATH/$ifname.3 2>/dev/null
    fi
}

show_client_lease_for_if () {
    local ifname
    local ifnameA
    local ifnameB
    local ifnameC
    local stat

    ifnameA=${1%/*}
    if [ "$ifnameA" == "$1" ]; then
        ifname=$ifnameA
    else
        ifnameB=${1#*/}
        ifnameC="$ifnameA-$ifnameB"
        ifname=${ifnameC/-/_}
    fi

    stat=$(/sbin/uci -q get network.$ifname.disabled)
    [ "$stat" == "1" ] && return 1

    stat=$(/sbin/uci -q get network.$ifname.proto)
    [ "$stat" == "dhcp" ] && {
        [ -f $DHCP_LEASES_PATH/$ifname.1 ] && {
            echo "        Interface : ${1//_//}"
            show_realtime_info
            echo
        }
    }
}

if [ -n "$1" ]; then
    local leaseif=$1
    show_client_lease_for_if $leaseif
else
    local ifc
    scan_interfaces
    for ifc in $interfaces; do
        show_client_lease_for_if $ifc
    done
fi

