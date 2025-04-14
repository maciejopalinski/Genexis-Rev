#!/bin/sh
# Copyright (c) 2011 PacketFront International AB. All rights reserved.

. /etc/functions.sh

NTPC=`which ntpclient`
NTP_ROUTE_FILE="/tmp/ntp_route"

del_ntp_route() {
   [ -f $NTP_ROUTE_FILE ] && old_ntp_route=`cat $NTP_ROUTE_FILE`
   [ -n "$old_ntp_route" ] && route del ${old_ntp_route%%[[:blank:]]*.*}
}

update_ntp_route() {

   del_ntp_route

   netstat -nr | while read dst gw nmask flags mss win irtt iface; do

    [ "$iface" = "$SRC_IF" ] && [ "$dst" = "0.0.0.0" ] && {

      new_ntp_route="$1 gw $gw dev $SRC_IF"
      route add $new_ntp_route
      echo "$new_ntp_route" >$NTP_ROUTE_FILE
      break
    }

   done
}

check_server() {
   local hostname
   local port

   [ -n "$SERVER" ] && return

   config_get hostname $1 hostname
   config_get port $1 port
   [ -z "$hostname" ] && return

   update_ntp_route $hostname

   for i in 1 2 3 4; do
     $NTPC -c 1 -i 15 -p ${port:-123} -h $hostname 2>&1 >/dev/null
     [ "$?" = "0" ] && {
       SERVER=$hostname
       PORT=${port:-123}
       break
     }
   done
}

set_drift() {
   config_get freq $1 freq
   [ -n "$freq" ] && adjtimex -f $freq >/dev/null
}

start_ntpclient() {
  local ntpserver
  local opt42_ntpservers

  config_foreach set_drift ntpdrift
  {
     while true; do

        unset SERVER
        unset PORT

        ntpserver=`uci -q get ntpclient.@ntpserver[0]`
        config_get opt42_ntpservers general dhcp_opt42

        # if static NTP servers configured
        if [ -n "$ntpserver" ] ; then
          config_foreach check_server ntpserver

        # only if no NTP servers configured, check opt42
        elif [ -n "$opt42_ntpservers" ] ; then
          for ntpsrv in $opt42_ntpservers ; do
            update_ntp_route $ntpsrv
            for i in 1 2 3 4; do
              $NTPC -c 1 -i 15 -p 123 -h $ntpsrv 2>&1 >/dev/null
              [ "$?" = "0" ] && {
                SERVER=$ntpsrv
                PORT=123
                break
              }
            done

            [ -n "$SERVER" ] && break
          done

        # neither static nor opt42, exit
        else
          del_ntp_route
          exit 0  
        fi

        sleep 2

        if [ -n "$SERVER" ] ; then
           logger starting ntpclient
           $NTPC ${COUNT:+-c $COUNT} ${INTERVAL:+-i $INTERVAL} -s -l -p $PORT -h $SERVER 2>&1 >/dev/null
        fi

        sleep 15

     done
  } &
}

load_settings() {
  local interval
  local count
  local src_if

  unset INTERVAL
  unset COUNT
  unset SRC_IF

  config_get interval general interval
  config_get count general count

  [ -n "$count" ] && COUNT=$count
  [ -n "$interval" ] && INTERVAL=$interval

  config_get src_if general src_if

  # if no ntp source-interface, then try mgmt src interface
  [ -z "$src_if" ] && src_if=`uci -q get route.mgmt_src_if`

  # if no mgmt src interface, then try wan interface
  [ -z "$src_if" ] && src_if=`uci -q get network.lan.natexternaliface`
  [ -z "$src_if" ] && src_if=`uci -q get network.default.wan_if`

  [ -n "$src_if" ] && SRC_IF=`uci -P /var/state get network.${src_if}.ifname`
}

config_load ntpclient
load_settings

start_ntpclient
