#! /bin/sh
# $Id: iptables_removeall.sh,v 1.4 2008/04/25 18:15:09 nanard Exp $
IPTABLES=iptables

clean_chain() {
 table=$1
 chain=$2

 rules=`$IPTABLES -t $table -L $chain --line-numbers |grep MINIUPNPD`

 while [ -n "$rules" ]
 do
   line=${rules%%MINIUPNPD*}

   $IPTABLES -t $table -D $chain $line

   rules=`$IPTABLES -t $table -L $chain --line-numbers |grep MINIUPNPD`
 done

}

#removing the MINIUPNPD chain for nat
$IPTABLES -t nat -F MINIUPNPD
#rmeoving the rule to MINIUPNPD
clean_chain nat PREROUTING
$IPTABLES -t nat -X MINIUPNPD

#removing the MINIUPNPD chain for filter
$IPTABLES -t filter -F MINIUPNPD
#removing the rule to MINIUPNPD
clean_chain filter FORWARD
$IPTABLES -t filter -X MINIUPNPD

