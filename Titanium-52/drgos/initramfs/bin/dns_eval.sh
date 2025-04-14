#!/bin/sh
# Copyright (C) 2011 by PacketFront AB
dns_evaluate() {
  /bin/dns_do_eval "$1"
  # echo "exec -t 0 /bin/dns_do_eval $1" > /tmp/mafifo
}

