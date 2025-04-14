#!/bin/sh
# Copyright (C) 2011 by PacketFront AB

ns_debug=
RESOLV_CONF="/tmp/resolv.conf.auto"
RESOLV_CONF_STATIC_TMP="/tmp/resolv.conf.static.txt"
RESOLV_CONF_STATIC_SRCIF_TMP="/tmp/resolv.conf.static.srcif.txt"
RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP="/tmp/resolv.conf.static.srcif.domain.tmp"
RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP2="/tmp/resolv.conf.static.srcif.domain.tmp2"
RESOLV_CONF_DYN_PREFACE="/tmp/resolv.conf.auto.dyn"
RESOLV_CONF_REBUILD_TMP="/tmp/resolv.conf.rebuild.tmp"
RESOLV_CONF_REBUILD_TMP2="/tmp/resolv.conf.rebuild.tmp2"
RESOLV_CONF_REBUILD_HIS="/tmp/resolv.conf.rebuild.his"
RESOLV_CONF_REBUILD_PRE="/tmp/resolv.conf.rebuild.pre"
RESOLV_CONF_HOST_ROUTES_RETRY="/tmp/resolv.host.routes.retry"
RESOLV_CONF_HOST_ROUTES_RETRY_HIS="/tmp/resolv.host.routes.retry.his"
RESOLV_CONF_HOST_ROUTES_HIS="/tmp/resolv.host.routes.his"
RESOLV_CONF_HOST_ROUTES_PRE="/tmp/resolv.host.routes.pre"
RESOLV_CONF_PPPD_TMP="$RESOLV_CONF_DYN_PREFACE.ppp.$unit"
RESOLV_CONF_SERVER_ARG="/tmp/resolv.conf.server.arg"
RESOLV_CONF_SERVER_ARG_HIS="/tmp/resolv.conf.server.arg.his"
RESOLV_CONF_SERVER_ARG_TMP="/tmp/resolv.conf.server.arg.tmp"
RESOLV_CONF_SHOW="/tmp/resolv.conf.show"
RESOLV_CONF_SHOW_TMP="/tmp/resolv.conf.show.tmp"
SERVER_ARG=
searches=
# set to 1 to give dnsmasq the interface
use_if_lock=
# set to 1 to disable host routes (when use_if_lock is true)
no_host_routes=

dbg_log() {
  [ -n "$ns_debug" ] && echo "$@ $(date)" >> /tmp/nsdebug.txt
}

. /etc/functions.sh

# get gw for input srcif
get_gw_by_if ()  {
   local tmpif=$1
   local gw=
   route -n | grep "$tmpif" | grep "UG" | grep "0.0.0.0" > /tmp/resolv.route.tab.gw
   # example in:eth0.100 could have eth0.100, eth100_1, eth0.100_2, etc, match to correct interface
   while read line ; do
      sourceif=${line##* }  # get last word
      [ -z "$sourceif" ] || [ "$sourceif" != "$tmpif" ] && continue;
      # destination
      dest=${line%% *}   # get first word
      line=${line#$dest } # remove first word
      line="${line#"${line%%[![:space:]]*}"}"  # rm spaces
      # gw 
      gw=${line%% *}     # get first word
      gw=${gw//[[:space:]]} # rm all spaces
      break;
   done < /tmp/resolv.route.tab.gw
   rm -f /tmp/resolv.route.tab.gw 
   echo "$gw"
}

# purpose: puts add route info into a file
nameserver_add_new_host_route() {
    local dip="$1"
    local linxif="$2"
    local userif="$3"
    local wanip=
    local wanmk
    local dnet=
    local prot=
    local net=
    local gw=
    config_get prot $userif proto
    case "$prot" in
      static) config_get wanip $userif ipaddr
              config_get wanmk $userif netmask
              ;;
      dhcp)   wanip=`ifconfig $linxif | grep "inet addr" | cut -d: -f 2 | sed s/Bcast//g`
              wanmk=`ifconfig $linxif | grep "inet addr" | cut -d: -f 4`
              ;;
      pppoe)  wanip=`ifconfig $linxif | grep "inet addr" | cut -d: -f 2` 
              wanmk=`ifconfig $linxif | grep "inet addr" | cut -d: -f 4`
              ;;
    esac
    [ -n "$wanip" ] && [ -n "$wanmk" ] && {
       net=`/bin/ipcalc.sh "$wanip" "$wanmk" | grep NETWORK`
       dnet=`/bin/ipcalc.sh "$dip" "$wanmk" | grep NETWORK`
       net=${net#NETWORK=}
       dnet=${dnet#NETWORK=}
       if [[ -n "$net" && "$net" == "$dnet" ]]; then
         gw="$wanip"
       else
         gw=`get_gw_by_if "$linxif"`
         [ -z "$gw" ] && gw="$wanip"
       fi
    }

    dbg_log " ($4) u:$userif e:$linxif d:$dip g:$gw w:$wanip m:$wanmk dnet=$dnet net=$net"
    [ ! -n "$gw" ] && return
    [ ! -n "$dip" ] && return 
    [ ! -n "$linxif" ] && return
    # warning, this is a exact linux route command syntax
    cmdarg=$(echo "$dip" gw "$gw" dev "$linxif")
    dbg_log " C:$cmdarg OK"
    exists=
    [ -f $RESOLV_CONF_HOST_ROUTES_PRE ] && exists=`cat $RESOLV_CONF_HOST_ROUTES_PRE | grep $cmdarg` 
    [ ! -n "$exists" ] && echo "$cmdarg" >> $RESOLV_CONF_HOST_ROUTES_PRE
}

# purpose: uses history and current nameserver host route info files to add or del host routes
# remove old host routes, install new host routes, leave existing in place
nameserver_update_host_routes () {
  # are host routes disabled, then exit
  [ -n "$no_host_routes" ] && return

  # remove host routes no longer existing
  [ -f $RESOLV_CONF_HOST_ROUTES_HIS ] && {
    while read line ; do
      exists=
      [ -f $RESOLV_CONF_HOST_ROUTES_PRE ] && exists=`cat "$RESOLV_CONF_HOST_ROUTES_PRE" | grep "$line" 2>/dev/null`
      [ ! -n "$exists" ] && {
        ret=`route del -host ${line} metric 1`
        ret=`route del -host ${line} metric 0`
        dbg_log " route del $line ret:$ret"
      }
    done < $RESOLV_CONF_HOST_ROUTES_HIS 
  }

  # always install new route routes in case previous failures
  [ -f $RESOLV_CONF_HOST_ROUTES_PRE ] && {
    while read line ; do
      ret=`route del -host ${line} metric 1`
      ret=`route add -host ${line} metric 0`
      dbg_log " route add $line ret:$ret"
    done < $RESOLV_CONF_HOST_ROUTES_PRE 
  }

}
 
# TODO: future need to support more than 1 pppoe
# fetch the external user if via the internal name 
get_pppif() {
   local externif=`/sbin/uci -q show network | grep "proto=pppoe"`
   externif=${externif#network.}
   externif=${externif%.proto=pppoe}
   echo "$externif"
}
 
# fetch the external user if via the internal name
get_externif() {
   local tmpif=$1
   local externif=
   snapshot=`/sbin/uci -q show network | grep "$tmpif"`
   for snapshot in $snapshot ; do
      intif=${snapshot#network.*.ifname=} # grab internal if name
      [ "$intif" != "$tmpif" ] && continue;
      snapshot=${snapshot#network.}
      snapshot=${snapshot%.ifname=$tmpif}
      [ -n "$snapshot" ] && {
         externif="$snapshot"
         break;
      }     
   done
   echo "$externif"
}
 
# qualify and add name server learned from a specific interface 
nameserver_add_if ()  {
      local tmpif="$1"
      local externif="$2"
      local who="$3"
      local order_fn=
      local ppp_unit=
      local prot=
      let len=${#tmpif}-1
      config_get prot $externif proto
      [ "$prot" == "pppoe" ] && ppp_unit=${tmpif:$len}
      [ -f "$RESOLV_CONF_DYN_PREFACE.dhcpc.${tmpif}" ] && order_fn="$RESOLV_CONF_DYN_PREFACE.dhcpc.${tmpif}"
      [ -f "$RESOLV_CONF_DYN_PREFACE.ppp.${ppp_unit}" ] && order_fn="$RESOLV_CONF_DYN_PREFACE.ppp.${ppp_unit}"
      [ "$order_fn" == "$RESOLV_CONF_DYN_PREFACE.ppp.${ppp_unit}" ] && tmpif="ppp${ppp_unit}" 
      [ -n "$order_fn" ] && {
         domain=
         config_get domain $externif domain
         while read line ; do
            dbg_log " ADDIF: E:$externif I:$tmpif DO:$domain L:$line F:$order_fn"
            exist=`echo ${line} | grep "search" 2>/dev/null`
            [ -n "$exist" ] && {
               [ -z "$domain" ] && {
                  exist=${line#* }  # remove first word search
                  exist1=`echo ${searches} | grep "$exist" 2>/dev/null`
                  [ ! -n "$exist1" ] && {
                     [ ! -n "$searches" ] && searches="search"
                     searches="$searches $exist"
                  }
               }
               continue;
            }
	    exist=`echo ${line} | grep "nameserver" 2>/dev/null`
	    [ -n "$exist" ] && {
	       exist=`cat $RESOLV_CONF_REBUILD_TMP | grep "$line"`
	       [ ! -n "$exist" ] && {
                  echo "$line" >> $RESOLV_CONF_REBUILD_TMP
                  dest=${line##* }  # get ip of name server
                  [ "255.255.255.255" == "$dest" ] && continue;
                  [ "0.0.0.0" == "$dest" ] && continue;
	          echo "$dest $tmpif" >> $RESOLV_CONF_REBUILD_PRE
                  nameserver_add_new_host_route "$dest" "$tmpif" "$externif" "$who"
               }
	    }
	 done < $order_fn
      }
}

# qualify and add name server learned from interfaces not yet applied to list 
nameserver_add_if_any ()  {
   local FILES="$RESOLV_CONF_DYN_PREFACE.*"
   for f in $FILES ; do
      [ -f $f ] && {
         # find the external and internal interface names
         tmpif=`echo "$f" | grep "$RESOLV_CONF_DYN_PREFACE.dhcpc."`
         [ -n  "$tmpif" ] && tmpif=${tmpif#$RESOLV_CONF_DYN_PREFACE.dhcpc.} 
         # dhcp needs this external interface determination work
         [ -n "$tmpif" ] && {
            externif=`get_externif "$tmpif"`
         }
         [ -z  "$tmpif" ] && {
            tmpif=`echo "$f" | grep "$RESOLV_CONF_DYN_PREFACE.ppp."`
            # pick off ppp unit number
            [ -n  "$tmpif" ] && tmpif=${tmpif#$RESOLV_CONF_DYN_PREFACE.ppp.} 
            # now create ppp internal device name from unit number
            [ -n  "$tmpif" ] && tmpif="ppp$tmpif" 
            # NOTE: right now we only can have 1 pppoe for this to work
            # in future, we have the ppp unit number to match against in uci
            externif=`get_pppif`
         }
         domain=
         config_get domain $externif domain
         # process each line in this file
         while read line ; do
            dbg_log " ADDIFANY: E:$externif I:$tmpif DO:$domain L:$line F:$f"
            exist=`echo ${line} | grep "search" 2>/dev/null`
            # process 'search' directive
            [ -n "$exist" ] && {
               [ -z "$domain" ] && {
                  exist=${line#* }  # remove first word search
                  exist1=`echo ${searches} | grep "$exist" 2>/dev/null`
                  [ ! -n "$exist1" ] && {
                     [ ! -n "$searches" ] && searches="search"
                     searches="$searches $exist"
                  }
               }
               continue;
            }
            # process 'nameserver' directive
	    exist=`echo ${line} | grep "nameserver" 2>/dev/null`
	    [ -n "$exist" ] && {
	       exist=`cat $RESOLV_CONF_REBUILD_TMP | grep "$line"`
	       [ ! -n "$exist" ] && {
                  # put nameserver to resolver list
                  echo "$line" >> $RESOLV_CONF_REBUILD_TMP
                  dest=${line##* }  # get just ip of nameserver
                  [ "255.255.255.255" == "$dest" ] && continue;
                  [ "0.0.0.0" == "$dest" ] && continue;
	          echo "$dest $tmpif" >> $RESOLV_CONF_REBUILD_PRE
                  # add this route to list
                  nameserver_add_new_host_route "$dest" "$tmpif" "$externif" "5"
               }
	    }
	 done < $f 
      }
   done
}

# qualify and add nameserver and domain related learned from a specific interface 
nameserver_add_if_args ()  {
      local tmpif="$1"
      local externif="$2"
      local who="$3"
      local napt="$4"
      local order_fn=
      local ppp_unit=
      local prot=
      let len=${#tmpif}-1
      config_get prot $externif proto
      [ "$prot" == "pppoe" ] && ppp_unit=${tmpif:$len}
      [ -f "$RESOLV_CONF_DYN_PREFACE.dhcpc.${tmpif}" ] && order_fn="$RESOLV_CONF_DYN_PREFACE.dhcpc.${tmpif}"
      [ -f "$RESOLV_CONF_DYN_PREFACE.ppp.${ppp_unit}" ] && order_fn="$RESOLV_CONF_DYN_PREFACE.ppp.${ppp_unit}"
      [ "$order_fn" == "$RESOLV_CONF_DYN_PREFACE.ppp.${ppp_unit}" ] && tmpif="ppp${ppp_unit}" 
      dbg_log " ADDIFARGS: E:$externif I:$tmpif W:$who P:$ppp_unit F:$order_fn"
      [ -n "$order_fn" ] && {
         naptif=
         config_get naptif lan natexternaliface 
         domain=
         config_get domain $externif domain
         [ -z "$domain" ] && [ -n "$naptif" ] && [ "$naptif" == "$externif" ] && {
            dbg_log " ADDIFARG: E:$externif I:$tmpif N:$naptif Skip-NAPT-NoDO F:$order_fn"
            return;
         }
         [ -z "$domain" ] && {
            domain=`cat $order_fn | grep domain`
            [ -n "$domain" ] && domain=${domain#* } # strip first word
         }
         [ -n "$domain" ] && {
            while read line ; do
	       exist=`echo ${line} | grep "nameserver" 2>/dev/null`
	       [ -n "$exist" ] && {
                  dest=${line##* }  # get ip of name server
                  # if exist already, either static or dynamic, then don't add another
	          exist=`cat $RESOLV_CONF_SERVER_ARG_HIS | grep "$dest"`
	          [ ! -n "$exist" ] && {
                    tmpif2=
                    line2=`cat $RESOLV_CONF_REBUILD_HIS | grep "$dest"`
                    [ -n "line2" ] && tmpif2=${line2##* } # get last word internal if
                    dbg_log " ADDIF_ARG: D:$dest E:$externif I:$tmpif,$tmpif2 DO:$domain F:$order_fn"
                    [ -n "$tmpif2" ] && [ "$tmpif2" != "$tmpif" ] && continue;
                    [ -n "$domain" ] && [ -n "$dest" ] && [ -n "$tmpif" ] && {
                       num=0
                       for i in $domain ; do
                         if [ -n "$use_if_lock" ]; then
	                   echo "--server=/$i/$dest@$tmpif" >> $RESOLV_CONF_SERVER_ARG_HIS
                         else
	                   echo "--server=/$i/$dest" >> $RESOLV_CONF_SERVER_ARG_HIS
                         fi 
                         let num=${num}+1
                         [ "$num" -ge 4 ] && break;
                       done
                    }
                  }
	       }
	    done < $order_fn
         }
      }
}

# qualify and add nameserver and domain related learned from interfaces not yet in list 
nameserver_add_if_any_args ()  {
   local FILES="$RESOLV_CONF_DYN_PREFACE.*"
   local naptif=
   config_get naptif lan natexternaliface 
   for f in $FILES ; do
      [ -f $f ] && {
         # find the external and internal interface names
         externif=
         tmpif=`echo "$f" | grep "$RESOLV_CONF_DYN_PREFACE.dhcpc."`
         [ -n  "$tmpif" ] && tmpif=${tmpif#$RESOLV_CONF_DYN_PREFACE.dhcpc.} 
         # dhcp needs this external interface determination work
         [ -n "$tmpif" ] && {
            externif=`get_externif "$tmpif"`
         }
         [ -z  "$tmpif" ] && {
            tmpif=`echo "$f" | grep "$RESOLV_CONF_DYN_PREFACE.ppp."`
            # pick off ppp unit number
            [ -n  "$tmpif" ] && tmpif=${tmpif#$RESOLV_CONF_DYN_PREFACE.ppp.} 
            # now create ppp internal device name from unit number
            [ -n  "$tmpif" ] && tmpif="ppp$tmpif" 
            # NOTE: right now we only can have 1 pppoe for this to work
            # in future, we have the ppp unit number to match against in uci
            externif=`get_pppif`
         }
         # get static configured interface domain if any
         domain=
         config_get domain $externif domain
         [ -z "$domain" ] && [ -n "$naptif" ] && [ "$naptif" == "$externif" ] && {
            dbg_log " ADDIFANYARG: E:$externif I:$tmpif N:$naptif Skip-NAPT-NoDO F:$f"
            continue;
         }
         [ -z "$domain" ] && {
            domain=`cat $f | grep domain`
            [ -n "$domain" ] && domain=${domain#* } # strip first word
         }
         [ -z "$domain" ] && {
            dbg_log " ADDIFANYARG: E:$externif I:$tmpif N:$naptif Skip-NoDO F:$f"
            continue;
         }
         # process this interfaces args
         while read line ; do
	    exist=`echo ${line} | grep "nameserver" 2>/dev/null`
	    [ -n "$exist" ] && {
               dest=${line##* }  # get just ip of nameserver              
               exist=`cat $RESOLV_CONF_SERVER_ARG_HIS | grep "$dest"`
	       [ ! -n "$exist" ] && {
                  tmpif2=
                  line2=`cat $RESOLV_CONF_REBUILD_HIS | grep "$dest"`
                  [ -n "line2" ] && tmpif2=${line2##* } # get last word internal if
                  # if no static configured domain and not on napt if, then get dynamic domain
                  dbg_log " ADDIFANYARG: D:$dest E:$externif I:$tmpif,$tmpif2 N:$naptif DO:$domain F:$f"
                  [ -n "$tmpif2" ] && [ "$tmpif2" != "$tmpif" ] && continue;
                  # add this dest to list of domain exist
                  [ -n "$domain" ] && [ -n "$dest" ] && [ -n "$tmpif" ] && {
                     num=0
                     for i in $domain ; do
                       if [ -n "$use_if_lock" ]; then
	                 echo "--server=/$i/$dest@$tmpif" >> $RESOLV_CONF_SERVER_ARG_HIS
                       else
	                 echo "--server=/$i/$dest" >> $RESOLV_CONF_SERVER_ARG_HIS
                       fi 
                       let num=${num}+1
                       [ "$num" -ge 4 ] && break;
                     done
                  }
               }
            }
         done < $f
      }
   done
}

# add static configured nameservers to DRGOS resolver list (no src or domain)
nameserver_add_static ()  {
   [ -f $RESOLV_CONF_STATIC_TMP ] && {
         while read line ; do
	    exist=`echo ${line} | grep "nameserver" 2>/dev/null`
	    [ -n "$exist" ] && {
               dest=${line##* }  # get just ip of nameserver
               exist=`cat $RESOLV_CONF_REBUILD_TMP | grep "$dest" 2>/dev/null`
               dbg_log " ADDIFSTAT: D:$dest EX:$exist"
               [ -z "$exist" ] && {
	          echo "$line" >> $RESOLV_CONF_REBUILD_TMP
	          echo "$dest static" >> $RESOLV_CONF_REBUILD_PRE
               }
	    }
	 done < $RESOLV_CONF_STATIC_TMP 
   }
}

# add static configured nameservers to DRGOS resolver list (no domain)
nameserversrcif_add_static ()  {
   [ -f $RESOLV_CONF_STATIC_SRCIF_TMP ] && {
         while read line ; do
	    exist=`echo ${line} | grep "nameserver" 2>/dev/null`
	    [ -n "$exist" ] && {
               pair=${line##* }  # remove word nameserver
               dest=${pair%,*}   # strip off interface
               externif=${pair#*,}  # strip off dest ip
               externif=$(echo $externif | sed -e 's/\//_/g') # OVPC if needs xlate
               tmpif=
               config_get tmpif $externif ifname
               [ -z "$tmpif" ] && continue;
               prot=
               config_get prot $externif proto
               #up=`/sbin/uci -q -P /var/state get network.$externif.up 2> /dev/null`
               if [ "$prot" == "pppoe" ]; then
               up=`ifconfig ppp0 | grep "inet addr:"`
               else
               up=`ifconfig $tmpif | grep "inet addr:"`
               fi
               exist=`cat $RESOLV_CONF_REBUILD_TMP | grep "$dest" 2>/dev/null`
               dbg_log " ADDSRCIF: P:$pair D:$dest E:$externif I:$tmpif PR:$prot U:$up EX:$exist"
               [ "$prot" != "none" ] && [ -n "$up" ] && [ -z "$exist" ] && {
                  domain=
                  config_get domain $externif domain           
                  if [ -n "$domain" ]; then
                     echo "nameserver $dest,$externif,$domain" >> $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP
                  else
                     nameserver_add_new_host_route "$dest" "$tmpif" "$externif" "6"
	             echo "nameserver $dest" >> $RESOLV_CONF_REBUILD_TMP
	             echo "$dest $tmpif" >> $RESOLV_CONF_REBUILD_PRE
                  fi
               }
	    }
	 done < $RESOLV_CONF_STATIC_SRCIF_TMP
   }
}

# add static configured nameservers to DRGOS resolver list
nameserversrcifdomain_add_static ()  {
   [ -f $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP ] && {
         while read line ; do
            # format: nameserver a.b.c.d,vlan1,domain.com
	    exist=`echo ${line} | grep "nameserver" 2>/dev/null`
	    [ -n "$exist" ] && {
               pair=${line##* }  # begin remove word nameserver
               dest=${pair%,*}   # end strip off domain
               dest=${dest%,*}   # end strip off interface
               externif=${pair#*,}     # begin strip off dest ip
               domain=$externif
               externif=${externif%,*} # end strip off domain
               externif=$(echo $externif | sed -e 's/\//_/g') # OVPC if needs xlate
               domain=${domain#*,}     # begin strip off interface
               tmpif=
               config_get tmpif $externif ifname
               [ -z "$tmpif" ] && continue;
               prot=
               config_get prot $externif proto
               #up=`/sbin/uci -P /var/state get network.$externif.up 2> /dev/null`
               if [ "$prot" == "pppoe" ]; then
               up=`ifconfig ppp0 | grep "inet addr:"`
               else
               up=`ifconfig $tmpif | grep "inet addr:"`
               fi
               exist=`cat $RESOLV_CONF_REBUILD_TMP | grep "$dest" 2>/dev/null`
               dbg_log " ADDSRCIFDOMAIN: P:$pair D:$dest E:$externif I:$tmpif D:$domain PR:$prot U:$up EX:$exist"
               [ "$prot" != "none" ] && [ -n "$up" ] && [ -z "$exist" ] && {
                 nameserver_add_new_host_route "$dest" "$tmpif" "$externif" "7"
                 echo "nameserver $dest" >> $RESOLV_CONF_REBUILD_TMP
                 echo "$dest $tmpif" >> $RESOLV_CONF_REBUILD_PRE
               }
	    }
	 done < $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP
   }
}

# add static configured nameservers to DRGOS args resolver file
nameserversrcifdomain_add_static_args ()  {
   [ -f $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP2 ] && {
         while read line ; do
            # format: nameserver a.b.c.d,vlan1,domain.com
	    exist=`echo ${line} | grep "nameserver" 2>/dev/null`
	    [ -n "$exist" ] && {
               pair=${line##* }  # begin remove word nameserver
               dest=${pair%,*}   # end strip off domain
               dest=${dest%,*}   # end strip off interface
               externif=${pair#*,}     # begin strip off dest ip
               domain=$externif
               externif=${externif%,*} # end strip off domain
               externif=$(echo $externif | sed -e 's/\//_/g') # OVPC if needs xlate
               domain=${domain#*,}     # begin strip off interface
               tmpif=
               config_get tmpif $externif ifname
               [ -z "$tmpif" ] && continue;
	       exist=`cat $RESOLV_CONF_SERVER_ARG_HIS | grep "$dest" 2>/dev/null`
               prot=
               config_get prot $externif proto
               # up=`/sbin/uci -q -P /var/state get network.$externif.up 2> /dev/null`
               if [ "$prot" == "pppoe" ]; then
               up=`ifconfig ppp0 | grep "inet addr:"`
               else
               up=`ifconfig $tmpif | grep "inet addr:"`
               fi
               dbg_log " ADDSTATICARGS: D:$dest E:$externif I:$tmpif D:$domain e:$exist PR:$prot U:$up"
               [ ! -n "$exist" ] && [ "$prot" != "none" ] && [ -n "$domain" ] && [ -n "$dest" ] && [ -n "$tmpif" ] && [ -n "$up" ] && {
                 if [ -n "$use_if_lock" ]; then
	            echo "--server=/$domain/$dest@$tmpif" >> $RESOLV_CONF_SERVER_ARG_HIS
                 else
	            echo "--server=/$domain/$dest" >> $RESOLV_CONF_SERVER_ARG_HIS
                 fi 
               }
	    }
	 done < $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP2
   }
}

# add static configured namespace to DRGOS resolver list
namespace_add_static ()  {
   [ -f $RESOLV_CONF_STATIC_TMP ] && {
         while read line ; do
	    exist=`echo ${line} | grep "search" 2>/dev/null`
	    [ -n "$exist" ] && {
               exist=${line#* }  # remove first word search
	       exist1=`echo ${searches} | grep "$exist" 2>/dev/null`
	       [ ! -n "$exist1" ] && {
	          [ ! -n "$searches" ] && searches="search"
	          searches="$searches $exist"
	       }
               continue;
	    }
	 done < $RESOLV_CONF_STATIC_TMP 
   }
}

# lookup incoming arg in route tab, return internal srcif
route_lookup_dest_if ()  {
  local sourceif=
  local mydest=$1
  route -n > /tmp/resolv.route.tab
  while read line ; do
     exist=`echo ${line} | grep "Kernel" 2>/dev/null`
     [ -n "$exist" ] && continue;
     exist=`echo ${line} | grep "Destination" 2>/dev/null`
     [ -n "$exist" ] && continue;
     # destination
     dest=${line%% *}   # get first word
     line=${line#$dest } # remove first word
     line="${line#"${line%%[![:space:]]*}"}"  # rm spaces
     # gw 
     gw=${line%% *}     # get first word
     line=${line#$gw }   # remove first word
     line="${line#"${line%%[![:space:]]*}"}"  # rm spaces
     # get mask
     mask=${line%% *}   # get first word
     line=${line#$dest } # remove first word
     line="${line#"${line%%[![:space:]]*}"}"  # rm spaces
     [ -z "$mask" ] || [ -z "$dest" ] && continue;
     if [ "$dest" != "0.0.0.0" ];  then
       [ "$mask" == "0.0.0.0" ] && continue;
       dnet=`/bin/ipcalc.sh "$mydest" "$mask" | grep NETWORK`
       tnet=`/bin/ipcalc.sh "$dest" "$mask" | grep NETWORK`
       dnet=${dnet#NETWORK=}
       tnet=${tnet#NETWORK=}
       [ "$dnet" == "$tnet" ] && {
          sourceif=${line##* }  # get last word
          break;
       }
     else
       sourceif=${line##* }  # get last word
       break;
     fi
  done < /tmp/resolv.route.tab 
  echo "$sourceif"
}

# rebuilds the show text file 
nameservers_rebuild_show_do() {
  num_nameservers=0
  search_path=
  rm -f $RESOLV_CONF_SHOW_TMP >/dev/null 2>/dev/null
  # use master resolv file as ordering
  [ -f $RESOLV_CONF ] && {
     while read line ; do
       exist=`echo ${line} | grep "search" 2>/dev/null`
       [ -n "$exist" ] && [ -z "$search_path" ] && {
          search_path=${line#search }
          continue;
       }
       exist=`echo ${line} | grep "nameserver" 2>/dev/null`
       [ -z "$exist" ] && continue;
       # 1) get IP of Name-Server
       dest=${line##* }  # get ip of name server
       tmpif=
       domain="None"
       externif="Unknown"
       # 2) Look up Interface
       if [ -n "$no_host_routes" ]; then
         # lookup internal interface in the ARG History file
         [ -f $RESOLV_CONF_SERVER_ARG_HIS ] && {
           [ -n "$use_if_lock" ] && {
              results=`cat $RESOLV_CONF_SERVER_ARG_HIS | grep "$dest"`
              [ -n "$results" ] && tmpif=${results#*@ }  # get just the interface at ending past @ char
           }
         }
       else
         # get interface via host route file or route table
         [ -f $RESOLV_CONF_HOST_ROUTES_HIS ] && {
           results=`cat $RESOLV_CONF_HOST_ROUTES_HIS | grep "$dest"`
           [ ! -n "$results" ] && `route -n | grep "$dest"`
           [ -n "$results" ] && tmpif=${results##* }  # get last word
         }
       fi
       # look up using the mirror copy of run config, that has internal if
       [ ! -n "$tmpif" ] && {
         cu_resolv=`cat $RESOLV_CONF_REBUILD_HIS | grep "$dest"`
         [ -n "cu_resolv" ] && tmpif=${cu_resolv##* } # get last word internal if
         [ "$tmpif" == "static" ] && tmpif=
       }
       [ -n "$tmpif" ] && [ "$tmpif" != "static" ] && {
         externif=`get_externif "$tmpif"`
       }
       [ -n "$tmpif" ] && [ "$tmpif" == "ppp0" ] && {
         externif=`get_pppif`
       }

       # internal if still not known? (static ns with no src-if)
       [ -z "$tmpif" ] && {
         tmpif=`route_lookup_dest_if "$dest"`
         [ -n "$tmpif" ] && externif=`get_externif "$tmpif"`
       }

       # 3) get domains from the arg per line file
       domains=
       [ -f $RESOLV_CONF_SERVER_ARG_HIS ] && {
          while read line ; do
          cur_dest=${line#*/*/} # begin strip off --server=/domain/ to get this nameserver-ip
          [ -n "$use_if_lock" ] && cur_dest=${cur_dest%@*}
          [ "$dest" != "$cur_dest" ] && continue;
          domain=${line#*/} # begin strip off --server=/
          [ -n "$use_if_lock" ] && domain=${domain%@*} # strip off ending if
          domain=${domain%/*}   # end strip off name-server ip
          if [ -n "$domains" ]; then
            domains="$domains, $domain"
          else
            domains="$domain"
          fi 
          done < $RESOLV_CONF_SERVER_ARG_HIS 
       }
       [ "$num_nameservers" == 0 ] && echo "Interface            Name Server      Domain" > $RESOLV_CONF_SHOW_TMP
       let num_nameservers=${num_nameservers}+1
       [ -z "$externif" ] && externif="Unknown"
       externif=$(echo $externif | sed -e 's/_/\//g') # OVPC if needs xlate
       printf "%-20s %-16s %s\n" "$externif" "$dest" "$domains" >> $RESOLV_CONF_SHOW_TMP
     done < $RESOLV_CONF
  }

  # add search path
  [ -n "$search_path" ] && echo "Search: $search_path" >> $RESOLV_CONF_SHOW_TMP

  # update final show output file
  if [ -f $RESOLV_CONF_SHOW_TMP ]; then
     if [ -f $RESOLV_CONF_SHOW ]; then
       if ! cmp -s $RESOLV_CONF_SHOW_TMP $RESOLV_CONF_SHOW; then
         cp -f $RESOLV_CONF_SHOW_TMP $RESOLV_CONF_SHOW > /dev/null 2>/dev/null
       fi
     else
        cp -f $RESOLV_CONF_SHOW_TMP $RESOLV_CONF_SHOW > /dev/null 2>/dev/null
     fi
  else
     rm -f $RESOLV_CONF_SHOW > /dev/null 2>/dev/null
  fi 
  rm -f $RESOLV_CONF_SHOW_TMP >/dev/null 2>/dev/null
}

# rebuild the ARG for dnsmasq for --server options
resolver_server_arg_rebuild_do(){
   local who="$1"
   local restart_dnsmasq=
   rm -f $RESOLV_CONF_SERVER_ARG_HIS >/dev/null 2>/dev/null  
   rm -f $RESOLV_CONF_SERVER_ARG_TMP >/dev/null 2>/dev/null
   rm -f $RESOLV_CONF_REBUILD_PRE >/dev/null 2>/dev/null  
   SERVER_ARG=

   dbg_log "ARG Rebuild: W=$who"
   # 1. rebuild from static info
   rm -f $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP2 >/dev/null 2>/dev/null
   [ -f "$RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP" ] && {
      cp -f $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP2
   }
   nameserversrcifdomain_add_static_args "$who"

   # rebuild the dynamic information
   # 2. insert NAPT interface dynamic server(s) info
   tmpif=
   externif=
   config_get externif lan natexternaliface 
   [ -n "$externif" ] && config_get tmpif $externif ifname
   [ -n "$externif" ] && [ -n "$tmpif" ] && nameserver_add_if_args "$tmpif" "$externif" "$who"

   # 3a. insert VOIP Signal interface dynamic server(s) info
   tmpif=
   externif=`/sbin/uci -q get sip.global.signal_interface 2> /dev/null`
   [ -n "$externif" ] && config_get tmpif $externif ifname
   [ -n "$externif" ] && [ -n "$tmpif" ] && nameserver_add_if_args "$tmpif" "$externif" "$who"

   # 3b. insert VOIP Media interface dynamic server(s) info
   tmpif=
   externif=`/sbin/uci -q get sip.global.media_interface 2> /dev/null`
   [ -n "$externif" ] && config_get tmpif $externif ifname
   [ -n "$externif" ] && [ -n "$tmpif" ] && nameserver_add_if_args "$tmpif" "$externif" "$who"

   # 4. insert Management interface dynamic server(s) info
   tmpif=
   externif=`/sbin/uci -q get route.mgmt_src_if 2> /dev/null`
   [ -n "$externif" ] && config_get tmpif $externif ifname
   [ -n "$externif" ] && [ -n "$tmpif" ] && nameserver_add_if_args "$tmpif" "$externif" "$who"

   # 5. insert all other interface dynamic server(s) info
   nameserver_add_if_any_args

   # update tmp arg file from his temp file
   if [ -f "$RESOLV_CONF_SERVER_ARG_HIS" ]; then
     while read line ; do
       if [ -n "$SERVER_ARG" ]; then
         SERVER_ARG="$SERVER_ARG $line"
       else
         SERVER_ARG="$line"
       fi
     done < $RESOLV_CONF_SERVER_ARG_HIS
     echo "$SERVER_ARG" > $RESOLV_CONF_SERVER_ARG_TMP
   fi

   # update runtime arg file from tmp
   [ -z "$SERVER_ARG" ] && { 
      [ -f $RESOLV_CONF_SERVER_ARG ] && restart_dnsmasq=1
      rm -f $RESOLV_CONF_SERVER_ARG >/dev/null 2>/dev/null
   }
   [ -n "$SERVER_ARG" ] && {
     if [ -f $RESOLV_CONF_SERVER_ARG ]; then
       if ! cmp -s $RESOLV_CONF_SERVER_ARG_TMP $RESOLV_CONF_SERVER_ARG; then
         echo "$SERVER_ARG" > $RESOLV_CONF_SERVER_ARG
         restart_dnsmasq=1
       fi
     else
       echo "$SERVER_ARG" > $RESOLV_CONF_SERVER_ARG
       restart_dnsmasq=1
     fi
   }
   rm -f $RESOLV_CONF_SERVER_ARG_TMP >/dev/null 2>/dev/null   

   nameservers_rebuild_show_do

   # check if dnsmasq gets restarted
   [ -n "$restart_dnsmasq" ] && {
      dbg_log "ARG Rebuild: W=$who restart dnsmasq!"
      echo "dhcp.dnsmasq.toggle=1" > /tmp/mafifo
      echo "dhcp.dnsmasq.toggle=0" > /tmp/mafifo
   }
   dbg_log "ARG Rebuild: Exit W=$who"
}

# purpose: dnsmasq polled file /tmp/resolv.conf is rebuilt
nameservers_rebuild_do() {
   local who="$1"
   dbg_log "REBUILD DO Enter W:$who"

   rm -f $RESOLV_CONF_HOST_ROUTES_RETRY
   rm -f $RESOLV_CONF_HOST_ROUTES_RETRY_HIS
   config_load network

   # remove tmp files, init script vars
   searches=
   rm -f $RESOLV_CONF_REBUILD_TMP2
   rm -f $RESOLV_CONF_REBUILD_TMP
   rm -f $RESOLV_CONF_HOST_ROUTES_PRE
   rm -f $RESOLV_CONF_STATIC_SRCIF_TMP
   rm -f $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP

   # 1. insert static info, search && name-server(s)
   namespace_add_static
   DNS_SERVERS_SRCIF=`/sbin/uci -q get dhcp.dns.nameserversrcif`
   for DNS_SERVER_SRCIF in $DNS_SERVERS_SRCIF ; do
      echo "nameserver $DNS_SERVER_SRCIF" >> $RESOLV_CONF_STATIC_SRCIF_TMP
   done
   # this call will also build $RESOLV_CONF_STATIC_SRCIF_DOMAIN_TMP using interface domain
   nameserversrcif_add_static "$who"
   nameserversrcifdomain_add_static "$who"
   nameserver_add_static "$who"

   # 2. insert NAPT interface dynamic server(s) info
   tmpif=
   externif=
   config_get externif lan natexternaliface 
   [ -n "$externif" ] && config_get tmpif $externif ifname
   [ -n "$externif" ] && [ -n "$tmpif" ] && nameserver_add_if "$tmpif" "$externif" "1"

   # 3a. insert VOIP Signal interface dynamic server(s) info
   tmpif=
   externif=`/sbin/uci -q get sip.global.signal_interface 2> /dev/null`
   config_get tmpif $externif ifname
   [ -n "$tmpif" ] && nameserver_add_if "$tmpif" "$externif" "2"

   # 3b. insert VOIP Media interface dynamic server(s) info
   tmpif=
   externif=`/sbin/uci -q get sip.global.media_interface 2> /dev/null`
   config_get tmpif $externif ifname
   [ -n "$tmpif" ] && nameserver_add_if "$tmpif" "$externif" "3"

   # 4. insert Management interface dynamic server(s) info
   tmpif=
   externif=`/sbin/uci -q get route.mgmt_src_if 2> /dev/null`
   config_get tmpif $externif ifname
   [ -n "$tmpif" ] && nameserver_add_if "$tmpif" "$externif" "4"

   # insert dynamic server(s) info
   nameserver_add_if_any

   # copy tmp files into main resolv.conf.auto file
   [ -n "$searches" ] && echo "$searches" >> $RESOLV_CONF_REBUILD_TMP2
   echo -n > "$RESOLV_CONF"
   echo -n > "$RESOLV_CONF_REBUILD_HIS"
   [ -f $RESOLV_CONF_REBUILD_TMP ] && {
      # add all "search" directive information
      [ -f $RESOLV_CONF_REBUILD_TMP2 ] && cat $RESOLV_CONF_REBUILD_TMP2 >> $RESOLV_CONF
      cat $RESOLV_CONF_REBUILD_TMP >> $RESOLV_CONF
      [ -f $RESOLV_CONF_REBUILD_PRE ] && cat $RESOLV_CONF_REBUILD_PRE > $RESOLV_CONF_REBUILD_HIS
   }
   rm -f $RESOLV_CONF_REBUILD_PRE > /dev/null
   rm -f $RESOLV_CONF_REBUILD_TMP2 > /dev/null
   rm -f $RESOLV_CONF_REBUILD_TMP > /dev/null

   # add and remove host routes to name servers based on history and ner list
   nameserver_update_host_routes

   # update history
   [ -f $RESOLV_CONF_HOST_ROUTES_HIS ] && rm -f $RESOLV_CONF_HOST_ROUTES_HIS
   [ -f $RESOLV_CONF_HOST_ROUTES_PRE ] && {
      cp -f $RESOLV_CONF_HOST_ROUTES_PRE $RESOLV_CONF_HOST_ROUTES_HIS
      rm -f $RESOLV_CONF_HOST_ROUTES_PRE
   }

   resolver_server_arg_rebuild_do $who

   nameservers_rebuild_show_do

   # bug 23863 re-apply FQDN based nat port fwd rules after dns info changes
   # TODO: could make this better to detect any changes, but most invokers of this script already have detected a change
   echo "nat.toggle=1" > /tmp/mafifo
   echo "nat.toggle=0" > /tmp/mafifo

   dbg_log "REBUILD DO Exit W:$who"

}

