# oxsh.sh
#
# Copyright (c) 2012 Genexis BV
# Copyright (c) 2011 PacketFront International AB
#

# oxconfig()	Executes a single configuration command using oxsh -u. Updates the ERROR variable
#		if there is a problem. Does not write the changes to flash
oxconfig() {
	local cmd=$@

	# echo $cmd >> /tmp/foo
	oxsh -u -x "configure terminal; $cmd" 2>&- > /dev/null
	! equal "$?" 0 && {
	    ERROR="$ERROR Error executing command! ($cmd) <br />"
	}
}

# oxwrite()	Writes all changes to flash using oxsh -u. Updates the ERROR variable
#		if there is a problem.
oxwrite() {
	  # Make changes permanent
	  oxsh -u -x "write memory" 2>&- > /dev/null
	  ! equal "$?" 0 && {
	    ERROR="$ERROR Error saving configuration!<br />"
	  }
}

