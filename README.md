

# Bluetooth tethering for Jayofelony's Pwnagotchi
Im not responsible for any damage, I'm just sharing what worked for ME. Only do this if you know what you're doing.

Basically if you're like me and can't seem to get the connection of Jayofelony's Pwnagotchi Image to last more than a few seconds then this is for you. All this script does is connect to your phone on boot. I found out that `sudo bt-network -c "mac:address:of:phone"  nap &` held the connection just how I wanted unlike with `bluetoothctl`. YES I have gone through countless fixes but none really worked. I tried it on my Nothing (4a) and I might try it on my iPhone 4 running ios 6.

* Uses `setsid` to detach the connection process so it doesn't drop when the boot terminal switches.
* Uses a scanning loop to wait out the Network Manager's boot-time interface resets.
* Automatically gives an IP address so the pwnagotchi is visible on Ning or anything to find it's ip address (I suggest [Ning (Open Source AND Rootless](https://github.com/csicar/Ning)

## Prerequisites
- **Bluetooth Tethering ON in your phone**. Not sure if the blueotooth tethering option in the `config.toml` being `true` helped but I did that. Don't forget to set the config toml to either android or ios.
- Must have SSH'd and paired into the pwnagotchi and have **paired, trusted your mac address just once**. For that (in pwnagotchi), `sudo bluetoothctl`, `scan on`, `pair <mac>`, `trust <mac>`.
- A linux machine (optional) if you can't ssh into it so you can just plug the sd in and modify and make changes via rootfs and bootfs

Also just so you know, `.local` does not work you're gonna have to stick to the IP that you find on Ning or any other app.

---

## Create the Connection Script

Create a script at `/usr/local/bin/bt-scan-connect.sh`, **don't forget to replace the mac address with your phone's**.

```bash
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

```

### Make it Executable
If you're on ssh or editing it on a linux machine but this is important.
```bash
sudo chmod +x /usr/local/bin/bt-scan-connect.sh
sudo chown root:root /usr/local/bin/bt-scan-connect.sh
```

---

## Create the Systemd Service

Create the systemd unit file at `/etc/systemd/system/bt-scan-connect.service`

```ini
[Unit]
Description=Scan and connect to phone Bluetooth PAN
After=bluetooth.target
Wants=bluetooth.target

[Service]
Type=simple
ExecStart=/usr/local/bin/bt-scan-connect.sh
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
```

### Enable the Service (if on ssh)

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now bt-scan-connect.service
```

That's about it. On your next boot it should automatically connect AND hold the bluetooth connection.
