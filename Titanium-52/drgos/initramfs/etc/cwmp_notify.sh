#!/bin/sh

usage () {
    echo ""
    echo "  Usage: $0 [OPTIONS]"
    echo "  Options:"
    echo "         set <CFG_UCI_DATA> "
    echo "         load <CFG_UCI_DATA> "
    echo "         add <CFG_UCI_DATA> "
    echo "         del <CFG_UCI_DATA> "
    exit 1
}

CFG_TYPE="set"
CFG_UCI_DATA=""
CWMP_NOTIFY_CFG_FILE="/etc/cwmp_notify.conf"
TR104_NOTIFY_SCRIPT="/etc/tr104_notify"

if [ -n "$1" ]; then
  CFG_TYPE=$1
  shift
fi

if [ -n "$1" ]; then
  CFG_UCI_DATA=$1
  shift
fi

# check args
if [ "X$CFG_TYPE" = "X" -o "X$CFG_UCI_DATA" = "X" ]; then
  usage
fi

# check configuration file
if [ ! -f $CWMP_NOTIFY_CFG_FILE ]; then
  echo "$CWMP_NOTIFY_CFG_FILE not found!"
  exit 1
fi

# fetch the uci parameter name & uci parameter value
uci_param_name="${CFG_UCI_DATA%%\=*}"
uci_param_value="${CFG_UCI_DATA#*=}"

if [ "X$uci_param_name" = "X" ]; then
  echo "parse $CFG_UCI_DATA failed"
  exit 1
fi

sip_param="${uci_param_name%%\.*}"
# external mapping-logic for sip module
if [ "X$sip_param" = "Xsip" ]; then
  if [ -f "$TR104_NOTIFY_SCRIPT" ]; then
    $TR104_NOTIFY_SCRIPT $CFG_TYPE $CFG_UCI_DATA
  fi
  exit 0
fi

# "load" is only for tr104 to load SIP configuration
if [ "$CFG_TYPE" = "load" ]; then
  exit 0
fi

# fetch the matched lines from configuration file
cat $CWMP_NOTIFY_CFG_FILE | while read var_type var_uci_param_name cwmp_notify_type cwmp_param_name awk_script; do
  [ "$var_type" = "$CFG_TYPE" ] || continue
  [ "$var_uci_param_name" = "$uci_param_name" ] || continue

  if [ "X$cwmp_notify_type" = "X" -o "X$cwmp_param_name" = "X" ]; then
    echo "no matching cwmp notify type or name"
    exit 1
  fi

  if [ "X$uci_param_value" = "X" ]; then
    # send notification to cwmp module
    /sbin/cwmp_notify $cwmp_notify_type $cwmp_param_name
  else
    # fetch the awk script
    cwmp_param_value=""
    if [ "X$awk_script" != "X" ]; then
      # generate the tmp awk script file
      tmp_awk_script_file=/tmp/cwmp_notify_$$.awk
      tmp_awk_script_files=/tmp/cwmp_notify_*.awk
      echo "$awk_script" > $tmp_awk_script_file
      # convert value with the awk script file
      cwmp_param_value=`/bin/echo "$uci_param_value" | /usr/bin/awk -f $tmp_awk_script_file`
      rm -rf $tmp_awk_script_files
    else
      cwmp_param_value=$uci_param_value
    fi
    # send notification to cwmp module
    /sbin/cwmp_notify $cwmp_notify_type $cwmp_param_name $cwmp_param_value
  fi
done
