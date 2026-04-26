#!/bin/bash
# Polls jts.ini and ensures the Docker gateway IP stays in TrustedIPs.
# Gateway rewrites jts.ini on each login, so we re-patch after each write.
JTS=/root/Jts/jts.ini
GW_IP=$(ip route show default | awk '{print $3}')
[ -z "$GW_IP" ] && GW_IP=172.18.0.1

echo "TrustedIPs patcher: will add ${GW_IP} to ${JTS}"

while true; do
    if [ -f "$JTS" ] && grep -q "^TrustedIPs=" "$JTS"; then
        if ! grep -q "${GW_IP}" "$JTS"; then
            sed -i "s/^TrustedIPs=\(.*\)/TrustedIPs=\1,${GW_IP}/" "$JTS"
            echo "Patched TrustedIPs: added ${GW_IP}"
        fi
    fi
    sleep 5
done
