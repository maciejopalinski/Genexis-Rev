#! /bin/sh
# $Id: iptables_init.sh,v 1.4 2008/04/25 18:15:08 nanard Exp $
. /etc/functions.sh
IPTABLES=iptables

#change this parameters :
config_load "upnpd"

config_get EXTIF config wan_interface
[ -z "$EXTIF" ] && {
	EXTIF=`uci get -P /var/state network.lan.natexternaliface`
}
[ -n "$EXTIF" ] && {
	EXTIF=`uci get -P /var/state network.${EXTIF//\"/}.ifname`
}
[ -z "$EXTIF" ] && {
	EXTIF=`uci get -P /var/state network.wan.ifname`
}

config_get LANIF config lan_interface
[ -n "$LANIF" ] && {
	LANIF=`uci get -P /var/state network.${LANIF//\"/}.ifname`
}
[ -z "$LANIF" ] && {
	LANIF=`uci get -P /var/state network.lan.ifname`
}

# EXTIP="`LC_ALL=C /sbin/ifconfig $EXTIF | grep 'inet addr' | awk '{print $2}' | sed -e 's/.*://'`"
# echo "External IP = $EXTIP"

#adding the MINIUPNPD chain for nat
$IPTABLES -t nat -N MINIUPNPD
#adding the rule to MINIUPNPD
#$IPTABLES -t nat -A PREROUTING -d $EXTIP -i $EXTIF -j MINIUPNPD
$IPTABLES -t nat -A PREROUTING -i $EXTIF -j MINIUPNPD

#adding the MINIUPNPD chain for filter
$IPTABLES -t filter -N MINIUPNPD
#adding the rule to MINIUPNPD
$IPTABLES -D FORWARD -j LOGDROP
$IPTABLES -t filter -A FORWARD -i $EXTIF -o $LANIF -j MINIUPNPD
$IPTABLES -A FORWARD -j LOGDROP

