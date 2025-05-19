#!/bin/sh

LISTA=/tmp/devices-macs.log
OBECNE=$(ip neigh show br-lan | awk '{print $5}')

touch "$LISTA"

for MAC in $OBECNE; do
  grep -q "$MAC" "$LISTA" || {
    HOST=$(grep "$MAC" /tmp/dhcp.leases | awk '{print $4}')
    if iw dev wlan0 station dump | grep -iq "$MAC"; then
      TYP="Wi-Fi"
    else
      TYP="LAN"
    fi
    logger -t devices-logger "New device: $MAC $HOST ($TYP)"
    echo "$MAC" >> "$LISTA"
  }
done

