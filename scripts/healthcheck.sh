#!/bin/bash
PORT=$([[ "${IB_TRADING_MODE}" == "paper" ]] && echo 4002 || echo 4001)
socat -T1 /dev/null TCP:localhost:${PORT} 2>/dev/null && exit 0 || exit 1
