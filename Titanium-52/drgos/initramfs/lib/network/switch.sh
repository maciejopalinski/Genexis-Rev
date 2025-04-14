#!/bin/sh
# Copyright (C) 2006 OpenWrt.org


SWITCH_PORT_LIST="CPU_WAN CPU_LAN WAN LAN1 LAN2 LAN3 LAN4"

PORT_TYPE_PHY="phy"
PORT_TYPE_MAC="mac"
debug_switch=0
switch_log_file=/tmp/switch.log
FIFO_PATH=/tmp/msfifo

[ -f /tmp/debug_switch ] && {
  debug_switch=1
  local msg="switch[$0 $@] started at $(date)"

  logger -s -t switch -p daemon.debug "$msg"
  echo "$msg" >> $switch_log_file
}

dbg_log() {
  [ $debug_switch = 1 ] && { 
    local date=`date +%s`
    local msg="$@"
    msg="${date}: ${msg}"
    logger -s -t switch -p daemon.debug "${msg}"
    echo "$msg" >> $switch_log_file
  }
}


msconfig_send()
{
    dbg_log "echo $1 > $FIFO_PATH"
    echo "$1" > $FIFO_PATH
}


switch_setup() {

    local cfg="switch"
    
    #vidlist of snooped vlans 
    local l2snoop_vidlist= 

    #store lan ports vidlist! Used to decide if igmp should 
    #be enabled or not
    local glanvidlist=
    local gwanvidlist=

    isstarted=`ps | grep "msconfig-helper" | grep -v grep`
    [ -z "$isstarted" ] && msconfig-helper&
    
	
    . /etc/functions.sh
    config_load switch
    config_load network

    for dev in $CONFIG_SECTIONS;do
	vid=
	config_get vid $dev igmpsnooping
	if [ "$vid" == "1" ]; then
	    vid=`echo ${dev:4}`
	    l2snoop_vidlist="$l2snoop_vidlist $vid" 
	fi
	
    done

    dbg_log "l2 snooped vid list: $l2snoop_vidlist"

    #pingelfeldt, disable this feature in hrg1000 and until
    #supported by the Atheros switch driver
    #dot1p
    #dot1p=
    #config_get dot1p global dot1p
    #if [ -n "$dot1p" ]; then
    #	msconfig_send "$cfg.global.dot1p=$dot1p"
    #fi


    for port in $SWITCH_PORT_LIST; do
	pvid=
	vidlist=
	gissnoop="false"
	gisL3="false"
	gisL2="false"

	#enable/disable port

	# Check if switch ports are allowed up.
	if [ ! -f /tmp/boot_done ]; then
	    value="off"
	else
	    value=
	    config_get value $port state
	    [ -n "$value" ] || value="on"
	fi

	msconfig_send "$cfg.$port.state=$value"

	#read vlan vid list
	gvl=
	config_get gvl $port vid	    
	
	#pingelfeldt, disable this feature in hrg1000 and until
	#supported by the Atheros switch driver
	#domain, not used after 1.5
	#gdomain=
	#config_get gdomain $port domain
	#if [ -n "$gdomain" ]; then  
	#    msconfig_send "$cfg.$port.domain=$gdomain"
	#fi
	
	#pvid
	pvid=
	config_get pvid $port default_vlan_id
	if [ -n "$pvid" ]; then
	    msconfig_send "$cfg.$port.default_vid_id=$pvid"
	else
	    pvid=0
	    msconfig_send "$cfg.$port.default_vid_id=0"
	fi
	
	#prio
	value=
	config_get value $port default_vlan_priority
	if [ -n "$value" ]; then
	    msconfig_send "$cfg.$port.default_prio=$value"
	else
	    msconfig_send "$cfg.$port.default_prio=0"
	fi

	#pingelfeldt, disable this feature in hrg1000 and until
	#supported by the Atheros switch driver
	#shed
	#qsched=
	#config_get qsched $port qsched
	#if [ -n "$qsched" ]; then
	#    msconfig_send "$cfg.$port.qsched=$qsched"
	#fi

	#rate limiter
	config_get rlkbps $port rlkbps
	if [ -n "$rlkbps" ]; then
	    msconfig_send "$cfg.$port.rlkbps=$rlkbps"
	else
	    msconfig_send "$cfg.$port.rlkbps"
	fi

	config_get rltt $port rltt
	if [ -n "$rltt" ]; then
	    msconfig_send "$cfg.$port.rltt=$rltt"
	else
	    msconfig_send "$cfg.$port.rltt"
	fi

	config_get kbpsshaper $port kbpsshaper
	if [ -n "$kbpsshaper" ]; then
	    msconfig_send "$cfg.$port.kbpsshaper=$kbpsshaper"
	else
	    msconfig_send "$cfg.$port.kbpsshaper"
	fi

	#convert vidlist to seperate numbers
	for vid in $gvl; do
	    echo $vid | grep - > /dev/null
	    if [ `echo $?` != "0" ];then
		vidlist="$vidlist $vid"
	    else
		local min=`echo $vid | cut -f1 -d'-'`
		local max=`echo $vid | cut -f2 -d'-'`
		while [ $min -le $max ];do
		    vidlist="$vidlist $min"
		    let min=min+1
		done
	    fi
	done
	
	[ "$port" = "CPU_LAN" ] && glanvidlist=$vidlist
	[ "$port" = "WAN" ] && gwanvidlist=$vidlist
	
	msconfig_send "$cfg.$port.tagged=$gvl"
	
	gisuntagged=
        for vid in $vidlist; do

	    #set to untagged if vid is equal to default vid
	    [ "$pvid" = "$vid" ] && {
		gisuntagged=1
		msconfig_send "$cfg.$port.untagged=$vid"
	    }

	    #create ip forwarding list 
	    case "$port" in
		LAN1|LAN2|LAN3|LAN4)
		    vlanif=
		    config_get vlanif vlan"$vid" ifname
		    if [ -n "$vlanif" ]; then
			ignore=0
			for v in $natiflist; do
			    [ $v = $vlanif ] && ignore=1
			done
			[ $ignore = "0" ] && vlaniflist="$vlaniflist $vlanif"
			
			for v in $gwanvidlist; do
			    [ $v = $vid ] && gisL2="true"
			done

			for v in $glanvidlist; do
			    [ $v = $vid ] && gisL3="true"
			done
			
		    fi
		    ;;
		*)
		    true
		    ;;
	    esac
	    
	    [ "$gissnoop" = "false" ] && {
		for snoopvid in $l2snoop_vidlist; do
		    if [ "$vid" = "$snoopvid" ]; then
			gissnoop="true"
			break
		    fi
		done
	    }
	done
	
	#until routed vlan's are supported create 
	#untagged vlan 0 on the LAN side
	case "$port" in
	    CPU_LAN|LAN1|LAN2|LAN3|LAN4)
		[ -z "$gisuntagged" ] && {
		    msconfig_send "$cfg.$port.untagged=0"
		} 
		;;
	esac
	

	ie=
	if [ "$gissnoop" = "false" ]; then
	    ie="false"
	else
	    ie="true"
	fi
	
        #check if L3 proxy, TODO this hack does not support multiple instances
        #upstream=`uci -q get network.lan.igmpupstreamintf`
        #assume L3 if 0 is the only vid for a LAN port
	upstream=
	config_get upstream lan igmpupstreamintf
	if [ -n "$upstream" ];then
	    case "$port" in
		LAN1|LAN2|LAN3|LAN4)
		    [ -z "$gisL3" ] || ie="true"
		    ;;
		WAN)
		    ie="true"
		    ;;
	    esac
	fi

	if [ "$ie" = "true" ]; then
	    msconfig_send "$cfg.$port.igmpsnoop=on"
	else
	    msconfig_send "$cfg.$port.igmpsnoop=off"
	fi
	
        # Limit port maximum speed and duplex?
	config_get speedmax $port speedmax
	if [ -n "$speedmax" ]; then
            config_get duplexmax $port duplexmax
            if [ -n "$duplexmax" ]; then
		if [ "$speedmax" = "1000" -o "$speedmax" = "auto" -o "$duplexmax" = "auto" ]; then
                    speedmax="auto"
                    duplexmax="full"
		fi
		
		if [ -n "$speedmax" -a -n "$duplexmax" ]; then
		    msconfig_send "$cfg.$port.speed=$speedmax $duplexmax"
		fi
            fi
	fi
	
    done

    #pingelfeldt, disable this feature in hrg1000 and until
    #supported by the Atheros switch driver
    #commit portbased vlan, any port can be used
    #msconfig_send "$cfg.portbased_commit"
    #send signal to igmp process, that the interfaces have 
    #been updated
    pid=`pidof igmp`
    kill -SIGHUP $pid 


}
