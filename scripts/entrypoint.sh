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

# Configure VNC password
if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p /root/.vnc
    x11vnc -storepasswd "$VNC_PASSWORD" /root/.vnc/passwd
    echo "VNC password configured"
else
    echo "WARNING: VNC_PASSWORD not set — VNC will run without password"
fi

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/ibc.conf
