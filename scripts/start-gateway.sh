#!/bin/bash
set -e

# Wait for Xvfb display
until xdpyinfo -display :1 >/dev/null 2>&1; do sleep 2; done

TWS_MAJOR_VRSN=$(cat /etc/ibgateway_version)
echo "Starting IBC with gateway version: ${TWS_MAJOR_VRSN}"

export DISPLAY=:1
export TWS_MAJOR_VRSN
export IBC_INI=/config/ibc/config.ini
export TRADING_MODE=${IB_TRADING_MODE:-live}
export TWOFA_TIMEOUT_ACTION=restart
export IBC_PATH=/opt/ibc
export TWS_PATH=/root/Jts
export TWS_SETTINGS_PATH=/root/Jts
export LOG_PATH=/var/log/ibc
export APP=GATEWAY

mkdir -p "${LOG_PATH}"

exec "${IBC_PATH}/scripts/displaybannerandlaunch.sh"
