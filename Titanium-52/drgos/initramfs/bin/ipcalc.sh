#!/bin/sh
# File: /bin/ipcalc.sh
# Date: 20080720
# This is a modified version of OpenWRT's original /bin/ipcalc.sh.
# The 32-bit bitwise operators on the IP addresses do not function
# properly because certain hardware platforms use signed 32-bit
# integers while others are unsigned for shell/awk scripts.
# This modification resolves the problem by downconverting to
# a 31-bit value before upconverting to a 32-bit vale at the end.
# The behaviour of the and, or, rshift, lshift and compl operators
# should be watched for future problems on various platforms.
# This script was verified on a GW2345 and WRT54GL r11882.

# dhcp range calculations:
# ipcalc.sh <ip> <netmask> <start> <num>

awk -f /usr/lib/common.awk -f - $* <<EOF

function downconvert(ipstring) {
	n = split(ipstring,a,"\.")
	if (n > 3)
	{
		if (a[1] > 127) ipstring = (a[1] - 128) "." a[2] "." a[3] "." a[4]
	}
	return ipstring
}

function upconvert(ipstring) {
	n = split(ipstring,a,"\.")
	if (n > 3)
	{
		newfirstoctet = a[1] + 128
		if (newfirstoctet > 255) newfirstoctet = 255
		ipstring = newfirstoctet "." a[2] "." a[3] "." a[4]
	}
	return ipstring
}

BEGIN {
	if (!ARGV[1]) originalip = "0.0.0.0"
	else originalip = ARGV[1]
	modip = downconvert(originalip)
	if (!ARGV[2]) originalnetmask = "0.0.0.0"
	else originalnetmask = ARGV[2]
	if (originalnetmask != "0.0.0.0")  # corner case handled separately
	{
		ipaddr=ip2int(modip)
		netmask=ip2int(originalnetmask)
		network=and(ipaddr,netmask)
		broadcast=or(network,compl(netmask))
		
		start=or(network,and(ip2int(ARGV[3]),compl(netmask)))
		limit=network+1
		if (start<limit) start=limit
		
		end=start+ARGV[4]-1
		limit=or(network,compl(netmask))-1
		if (end>limit) end=limit
		if (modip != ARGV[1]) # was downconverted earlier
		# upconvert relevant fields before printing
		{
			print "IP=" upconvert(int2ip(ipaddr))
			print "NETMASK="originalnetmask
			print "BROADCAST="upconvert(int2ip(broadcast))
			print "NETWORK="upconvert(int2ip(network))
			print "PREFIX="32-bitcount(compl(netmask))
			if (ARGC > 3) {
				print "START="upconvert(int2ip(start))
				print "END="upconvert(int2ip(end))
			}
		}
		else
		# no special handling needed
		{
			print "IP="ARGV[1]
			print "NETMASK="originalnetmask
			print "BROADCAST="int2ip(broadcast)
			print "NETWORK="int2ip(network)
			print "PREFIX="32-bitcount(compl(netmask))
			
			# range calculations:
			# ipcalc <ip> <netmask> <start> <num>
			
			if (ARGC > 3) {
				print "START="int2ip(start)
				print "END="int2ip(end)
			}
		}
	}
	else  # 0.0.0.0 netmask
	{
		originalstart = ARGV[3]
		modstart = downconvert(originalstart)
		start = ip2int(modstart)
		end = start + ARGV[4]
		
		print "IP="originalip
		print "NETMASK="originalnetmask
		print "BROADCAST=255.255.255.255"
		print "NETWORK=0.0.0.0"
		print "PREFIX=0"
		if (modstart != originalstart)
		{
			print "START=" upconvert(int2ip(start))
			print "END=" upconvert(int2ip(end))
		}
		else
		{
			print "START=" int2ip(start)
			print "END=" int2ip(end)
		}
	}
}
EOF
