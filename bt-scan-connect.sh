#!/bin/bash
TARGET_MAC="YOUR_PHONE_MAC_ADDRESS"
LOG="/var/log/bt-scan-connect.log"
exec >>"$LOG" 2>&1
echo "=== bt-scan-connect start $(date) ==="

START_TIME=$(date +%s)
TIMEOUT=30

while true; do
  if [ $TIMEOUT -gt 0 ]; then
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED -ge $TIMEOUT ]; then
      echo "$(date): timeout reached"
      exit 0
    fi
  fi

  bluetoothctl --timeout 5 scan on >/dev/null 2>&1
  if bluetoothctl devices | grep -qi "$TARGET_MAC"; then
    echo "$(date): device seen, starting bt-network detached"
    
    setsid bt-network -c "$TARGET_MAC" nap >/var/log/bt-network.log 2>&1 &
    
    sleep 6
    if ip link show | grep -E "bnep|bt-pan" >/dev/null 2>&1; then
      echo "$(date): connected, exiting scanner"
      
      IFACE=$(ip -br link show | grep -E "bnep|bt-pan" | awk '{print $1}')
      if [ ! -z "$IFACE" ]; then
          echo "$(date): requesting IP address on $IFACE..."
          sudo dhclient "$IFACE"
      fi

      exit 0
    else
      echo "$(date): no PAN iface yet"
    fi
  fi

  sleep 2
done
