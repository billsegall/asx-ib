#!/bin/bash
# Wait for Xvfb display
until xdpyinfo -display :1 >/dev/null 2>&1; do sleep 1; done

if [ -f /root/.vnc/passwd ]; then
    exec x11vnc -display :1 -forever -shared -rfbport 5900 -rfbauth /root/.vnc/passwd
else
    exec x11vnc -display :1 -forever -shared -rfbport 5900 -nopw
fi
