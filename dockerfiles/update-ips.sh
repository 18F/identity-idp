#!/bin/sh
#
# This script updates the ips.conf file so that we have
# up-to-date cloudfront IP information.
# 
set -e

IPS_CONF="/etc/nginx/cloudfront-ips.conf"
echo "Updating $IPS_CONF"

rm -f "$IPS_CONF"
echo '# cloudfront IP ranges' > $IPS_CONF
echo '# ' >> $IPS_CONF

curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq -r '.prefixes[] | select(.service=="CLOUDFRONT_ORIGIN_FACING") | .ip_prefix' | while read i ; do
  echo "set_real_ip_from $i;" >> $IPS_CONF
done

curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq -r '.ipv6_prefixes[] | select(.service=="CLOUDFRONT") | .ipv6_prefix' | while read i ; do
  echo "set_real_ip_from $i;" >> $IPS_CONF
done
