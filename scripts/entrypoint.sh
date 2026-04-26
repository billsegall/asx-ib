#!/bin/bash
set -e

# Render IBC config from template (substitutes env vars)
envsubst < /config/ibc/config.ini.tmpl > /config/ibc/config.ini
chmod 600 /config/ibc/config.ini

# Re-create IBC-expected versioned symlink after the /root/Jts volume mounts.
# IBC looks for the gateway at ${TWS_PATH}/ibgateway/${TWS_MAJOR_VRSN}/
MAJOR_VER=$(cat /etc/ibgateway_version)
mkdir -p /root/Jts/ibgateway
ln -sfn /usr/local/ibgateway "/root/Jts/ibgateway/${MAJOR_VER}"
echo "Gateway symlink: /root/Jts/ibgateway/${MAJOR_VER} -> /usr/local/ibgateway"

# Seed jts.ini with TrustedIPs including the Docker gateway IP before IBC starts.
# IBC writes TrustedIPs=127.0.0.1 as a default; pre-populating prevents the
# race where Gateway loads jts.ini before jts-patcher can add the gateway IP.
GW_IP=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1)
GW_IP=${GW_IP:-172.18.0.1}
mkdir -p /root/Jts
if [ ! -f /root/Jts/jts.ini ]; then
    cat > /root/Jts/jts.ini <<EOF
[IBGateway]
ApiOnly=true
TrustedIPs=127.0.0.1,${GW_IP}
EOF
    echo "Created jts.ini with TrustedIPs=127.0.0.1,${GW_IP}"
elif ! grep -q "${GW_IP}" /root/Jts/jts.ini; then
    sed -i "s/^TrustedIPs=\(.*\)/TrustedIPs=\1,${GW_IP}/" /root/Jts/jts.ini 2>/dev/null || true
    echo "Patched jts.ini TrustedIPs with ${GW_IP}"
fi

# Configure VNC password
if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p /root/.vnc
    x11vnc -storepasswd "$VNC_PASSWORD" /root/.vnc/passwd
    echo "VNC password configured"
else
    echo "WARNING: VNC_PASSWORD not set — VNC will run without password"
fi

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/ibc.conf
