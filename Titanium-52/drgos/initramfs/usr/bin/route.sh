#!/bin/sh

debug_route_sh=0
route_sh_log_file=/tmp/route_sh.log

[ -f /tmp/debug_route_sh ] && {
  debug_route_sh=1
  echo "route_sh[$0 $@] started at $(date)" >> $route_sh_log_file
}

dbg_log() {
  [ $debug_route_sh = 1 ] && echo "$@" >> $route_sh_log_file
}

. /etc/functions.sh

filename="/etc/iproute2/rt_tables"
baseindex="300"
magicnumber="#>>DRG>>"
route_create_default_file()
{
    #create default file
    echo "#" > $filename
    echo "#reserved values" >> $filename
    echo "#" >> $filename
    echo "" >> $filename
    echo "255 local" >> $filename
    echo "254 main" >> $filename
    echo "253 default" >> $filename
    echo "0 unspec " >> $filename
    echo "" >> $filename
    echo "$magicnumber" >> $filename


}
route_flush_tables()
{

    ismagicnumber=""
    table=$baseindex
    cat $filename | while read number name; do
	let table=$table+1
	[ "$ismagicnumber" == "1" ] && ip route flush table $table	
	 #find magic number
	if [ "$ismagicnumber" == "" ]; then
	    [ "$number" == "$magicnumber" ] && ismagicnumber=1
	fi
    done

    #create tables for main, local and...
    route_create_default_file
}    

route_flush_rules()
{
  ip rule | while read i1 i2 i3 i4 i5; do
	  if [ "$i5" != "main" ] && [ "$i5" != "local" ] && [ "$i5" != "default" ]; then 
	    ip rule del $i2 $i3 $i4 $i5
	  fi
  done
}

# parse rt_tables and add all internal routes into
# extarnal source tables
route_add_inttables()
{
    #######
    #TODO how to identify if interface is internal or external
    #######
    #find br-lan route
    netstat -nr | while read dst gw nmask flags mss win irtt iface; do
	if [ "$iface" == "br-lan" ]; then
	# check that dst starts with a number
	    [ "${dst#[0-9]}" != "$dst" ] || continue
	    ip1=`ifconfig $iface`
	    ip2="${ip1#*inet addr:}"
	    ip="${ip2%% *}"
	    ismagicnumber=""
	    table=$baseindex
	    cat $filename | while read number name; do
		let table=$table+1
		#find magic number
		if [ "$ismagicnumber" == "" ]; then
		    [ "$number" == "$magicnumber" ] && ismagicnumber=1
		    continue
		fi
		ip route add table $table $dst/$nmask dev $iface
	    done
	fi
    done
}

find_entry()
{
    #check if table is already created
    cat $filename | while read i1 i2 i3; do
	#find magic number
	if [ "$1" == "$i2" ]; then
	    echo "0"
	    break;
	fi
    done
}

# parse the main routing table and create a new routing table for 
# each external interface
route_add_exttables()
{
    #use line number + an offset to generate a unique index in rt table 
    index=`wc -l "$filename" | awk '{print $1}'`
    let index=$index+$baseindex+1    

    netstat -nr | while read dst gw nmask flags mss win irtt iface; do
	# check that dst starts with a number
	[ "${dst#[0-9]}" != "$dst" ] || continue
	ip1=`ifconfig $iface`
	ip2="${ip1#*inet addr:}"
	ip="${ip2%% *}"

	#######
	#TODO how to identify if interface is internal or external
	#######
	if [ $iface != br-lan ]; then
	    if [ "$(find_entry $iface)" != "0" ]; then
		echo "$index $iface" >> $filename
		let index=$index+1
	    fi
	    #table name is equal to iface
	    table=$iface
	    if [ "$dst" == "0.0.0.0" ]; then
		ip route add table $table default via $gw dev $iface
	    elif [ "$gw" != "0.0.0.0" ]; then
		ip route add table $table $dst/$nmask via $gw dev $iface
	    else
		ip route add table $table $dst/$nmask dev $iface
	    fi

	    hit=`ip rule | grep "from $ip lookup $table"`
	    [ -z "$hit" ] && {
		ip rule add from $ip table $table
	    }

	    #create a source based nat table for each match
	    config_load network    
	    #pieing: multiple lan interfaces is not supported in
	    #1.6.1 why there is no point to loop in this script.
	    #natexternal will only be applied on lan. A loop
	    #here will slow down the configuration of routes.
	    #Better solution is required in the future to support 
	    #multiple downstream interfaces, e.g. route daemon.
	    #for dev in $CONFIG_SECTIONS;do
	        dev=lan
		config_get extiface $dev natexternaliface
		#only support default interfaces
		if [ `echo $?` == "0" ] && [ -n "$extiface" ]; then
		    config_get proto $extiface proto
		    config_get extiface $extiface ifname
		    [ "$proto" = "pppoe" ] && {
          # force changing physical interface name to ppp0 when PPPoE is running
          # but the interface is not up yet
          # TODO: this needs to be redesigned if we support running PPPoE on
          # multiple interfaces
			echo $extiface | grep "ppp[0-9]" || {
			    extiface="ppp0"
			}
		    }
		    
		    #check if any match of external nat iface and 
		    #the output iface for the route
		    if [ $extiface == $iface ]; then
			config_get intiface $dev ifname
			hit=`ip rule | grep "from all iif $intiface lookup $table"`
			[ -z "$hit" ] && {
			    ip rule add iif $intiface table $table
			}
		    fi
		fi
	    #done
	fi	
	
    done    
}


# check that the management source interface routes has lowest metric
# (so it will be the chosen route when src ip isn't set)
route_check_mgmt_src() {
    # check that managment source interface has correct metric
    mgmt_if=`uci -q get route.mgmt_src_if`
    [ -n "$mgmt_if" ] || return 
    mgmt_dev=`cli_intf2dev $mgmt_if`
    [ -n "$mgmt_dev" ] || return
    netstat -ren | while read dest gw mask fl metric ref use iface; do
	#Kernel IP routing table
	#Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
	#10.126.30.0     0.0.0.0         255.255.255.0   U     0      0        0 eth0.100
	#echo "dest=$dest gw=$gw mask=$mask fl=$fl metric=$metric ref=$ref use=$use iface=$iface"

	# skip headers
	[ "${dest}" != "${dest#[0-9]}" ] || continue

	# check if we need to change the metric
	if [ "$iface" = "$mgmt_dev" ]; then
	    [ "$metric" = "0" ] && continue
	else
	    [ "$metric" != "0" ] && continue
	fi

	if [ "$iface" = "$mgmt_dev" ]; then 
    tmetric=0
  else
	  tmetric=1
  fi
	gwstr="gw $gw"
	[ "$gw" = "0.0.0.0" ] && gwstr=""
	# add new route with correct metric
  dbg_log "route add -net $dest netmask $mask $gwstr dev $iface metric $tmetric"
	route add -net $dest netmask $mask $gwstr dev $iface metric $tmetric
	# remove old route
  dbg_log "route del -net $dest netmask $mask $gwstr dev $iface metric $metric"
	route del -net $dest netmask $mask $gwstr dev $iface metric $metric
    done
}

#start fixing the source based routing table
[ "$debug_route_sh" = "1" ] && {
    local route_tables=$(route -n)
    dbg_log "before route_fixup(), the route table is below:"
    dbg_log "$route_tables"
}


route_check_mgmt_src

#delete all tables and clear the rt_tables file
route_flush_tables
#delete all rules
route_flush_rules
#add external routes
route_add_exttables
#add internal routes
route_add_inttables
#re-evaluate dnsmasq dynamic settings
. /bin/dns_eval.sh
dns_evaluate "route-fix"

[ "$debug_route_sh" = "1" ] && {
    local route_tables=$(route -n)
    dbg_log "after route_fixup(), the route table is below:"
    dbg_log "$route_tables"
}
