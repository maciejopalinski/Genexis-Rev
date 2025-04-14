#!/bin/sh
# Copyright (c) 2009 Packetfront Systems AB

set_boot_param() {
  local UCI="/sbin/uci"
  local boot_uci_config="/etc/config/boot"

  # Create a symbol link if it doesn't exist
  if [ ! -f $boot_uci_config ]; then
    ln -sf /config/.boot $boot_uci_config 
  fi

  # Using absolute path for setting option values in boot uci config 
  # file, to avoid committing changes into startup config.
  $UCI set $boot_uci_config.$1
}

