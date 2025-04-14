#!/usr/bin/webif-page
<?
. /usr/lib/webif/webif.sh
. /www/cgi-bin/webif/firewall-subcategories.sh

header "Firewall" "Active-Connections" "@TR<<Active Connections>>"
echo "<table><tbody><tr><td><div class=smalltext><pre>"
cat /proc/net/ip_conntrack | sort
echo "</pre></div></td></tr></tbody></table>"
?>

<table style="width: 90%; text-align: left;" border="0" cellpadding="2" cellspacing="2" align="center">
<tbody>

        <tr>
                <th><b>@TR<<Router Connections|Connections to the Router>></b></th>
        </tr>
        <tr>
                <td><pre><? netstat -n 2>&- | awk '$0 ~ /^Active UNIX/ {ignore = 1}; ignore != 1 { print $0 }' ?></pre></td>
        </tr>
</tbody>
</table>

<?
footer ?>
