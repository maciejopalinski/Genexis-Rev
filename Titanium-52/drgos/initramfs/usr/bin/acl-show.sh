#!/bin/sh

# Copyright (c) 2011 PacketFront International AB. All rights reserved.
#
# This Software and its content are protected by the Swedish Copyright Act
# (Sw: Upphovsr<E4>ttslagen) and, if applicable, the Swedish Patents Act
# (Sw: Patentlagen). All and any copying and distribution of the software
# and its content without authorization by PacketFront International AB is
# prohibited. The prohibition includes every form of reproduction and
# distribution.
#
# Author: pierre ingelfeldt
#

. /etc/functions.sh
. /lib/firewall/iptlib

###############################################################
      ## acl_show ##
##############################################################


#this function is a helper function and gets 
#the hit counter out of iptables
#arg 1 rule number, starting with 1
acl_hits() {
    i=0
    for hit in $ipthits; do
	let i=$i+1
	if [ $i = $1 ]; then
	    break
	fi
    done
}

#This function will display all etries in a 
#access-list including hit counters

#Arg1: Acl name
acl_show() {
    gaclname="$1"

    #create a sorted list of all entries in the access-list
    seqs=
    nentries=0
    for acl in $CONFIG_SECTIONS; do
	config_get aclname $acl name
	if [ "$aclname" = "$gaclname" ];then
	    config_get seq $acl seq
	    seqs="$seqs $seq"
	    let nentries=$nentries+1
	fi
    done
    seqs=`echo $seqs | tr " " "\n" | sort -n | tr "\n" " "`

    #create a list with the corresponding hit counters (sorted in seq order)
    ipt_filter_name "$gaclname"
    aclname=$filter
    iptables -nvL "$aclname" > /tmp/iptjunk
    ipthits=
    ipthit=
    i=0
    while read arg1 arg2; do
	let i=$i+1
	if [ $i -gt 2 ]; then
	    ipthits="$ipthits $arg1"
	fi
	ipthit=$arg1
    done < /tmp/iptjunk
    rm /tmp/iptjunk
    
    #print the access-list header including number of 
    #entries and implicit denies
    echo "Access-list $gaclname ($nentries entries, $ipthit implicit denies)" >> /tmp/acl.table

    #read out all parameters form UCI for each entry and 
    #display it inluding hit counters
    index=0
    for seq in $seqs; do

	let index=$index+1

	for acl in $CONFIG_SECTIONS; do
	    config_get name $acl name
	    config_get num $acl seq
	    if [ "$name" = "$gaclname" ] && [ "$num" = "$seq" ];then
		config_get permission $acl permission
		config_get type $acl type
		config_get protocol $acl protocol
		config_get srcaddr $acl srcaddr
		config_get srcprefix $acl srcprefix
		config_get srcport $acl srcport
		config_get dstaddr $acl dstaddr
		config_get dstprefix $acl dstprefix
		config_get dstport $acl dstport
		config_get flags $acl flags
		config_get notification $acl notification
	    else
		continue
	    fi
	done

	
	
	srcstr=
	[ -n "$srcaddr" ] && {
	    if [ -n "$srcprefix" ];then
		srcstr="source $srcaddr/$srcprefix"
	    else
		srcstr="source host $srcaddr"
	    fi
	}
        [[ -z "$srcstr" && -z "$srcprefix" && -z "$srcaddr" ]] && {
        srcstr="source any"
        }

	dststr=
	[ -n "$dstaddr" ] && {
	    if [ -n "$dstprefix" ];then
		dststr="destination $dstaddr/$dstprefix"
	    else
		dststr="destination host $dstaddr"
	    fi
	}
        [[ -z "$dststr" && -z "$dstprefix" && -z "$dstaddr" ]] && {
        dststr="destination any"
        }

	srcrange=
	[ -n "$srcport" ] && {
	    [ -n "$srcstr" ] || srcstr="source any"
	    echo $srcport | grep - > /dev/null
	    if [ `echo $?` != "0" ];then
		srcrange="$srcport"
	    else
		srcrange=$(echo $srcport|sed 's/-/ /g')
		srcrange="range $srcrange"
	    fi
	}

	dstrange=
	[ -n "$dstport" ] && {
	    [ -n "$dststr" ] || dststr="destination any"
	    echo $dstport | grep - > /dev/null
	    if [ `echo $?` != "0" ];then
		dstrange="$dstport"
	    else
		dstrange=$(echo $dstport|sed 's/-/ /g')
		dstrange="range $dstrange"
	    fi
	}
	
	str=" access-list $gaclname seq $seq $permission"		
	case $type in
            "ip" )
		str="$str ip"
		[ -n "$srcstr" ] && str="$str $srcstr"
		[ -n "$dststr" ] && str="$str $dststr"
		[ -n "$protocol" ] && str="$str protocol $protocol"	
		;;
            "udp")
		str="$str udp"
		[ -n "$srcstr" ] && str="$str $srcstr"
		[ -n "$srcrange" ] && str="$str $srcrange"
		[ -n "$dststr" ] && str="$str $dststr"
		[ -n "$dstrange" ] && str="$str $dstrange"
		;;
            "icmp")
		str="$str icmp"
		[ -n "$srcstr" ] && str="$str $srcstr"
		[ -n "$srcrange" ] && str="$str $srcrange"
		[ -n "$notification" ] && str="$str $notification"
		;;
            "tcp")
		str="$str tcp"
		[ -n "$srcstr" ] && str="$str $srcstr"
		[ -n "$srcrange" ] && str="$str $srcrange"
		[ -n "$dststr" ] && str="$str $dststr"
		[ -n "$dstrange" ] && str="$str $dstrange"
		[ -n "$flags" ] && str="$str flags $flags"
		;;
            * )
		echo "show-acl.sh: type=$type not a valid type"
		continue
		;;
	esac
	acl_hits $index
	echo "$str ($hit hits)" >> /tmp/acl.table
	
    done
}


acl_show_all() {
    created_acls=
    for acl in $CONFIG_SECTIONS; do
	config_get aclname $acl name
	[ -z "$aclname" ] && continue
	ipt_filter_name "$aclname"
	faclname=$filter
    
	#check if already created
	iscreated=
	for val in $created_acls; do
	    [ "$faclname" = "$val" ] && iscreated=true
	done
        #create a sorted list of sequens numbers for that access list
	[ -z "$iscreated" ] && {
	    acl_show "$aclname"
	    created_acls="$created_acls $faclname"
	}
    done    
}

#load config from UCI
config_load acl
#remove old file
rm -f /tmp/acl.table
#check if all acl's should be displayed
if [ -z "$1" ]; then
    acl_show_all
else
    acl_show "$1"
fi