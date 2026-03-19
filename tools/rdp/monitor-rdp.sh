#!/bin/bash

SESSION_FILE="/tmp/last-rdp-session"

gdbus monitor -e -d org.gnome.Mutter.RemoteDesktop | while read -r line; do
  # Trigger ONLY on PropertiesChanged with NumLockState (first event on connection)
  if [[ "$line" =~ /org/gnome/Mutter/RemoteDesktop/Session/u([0-9]+):.*PropertiesChanged.*NumLockState ]]; then
    SESSION_ID="${BASH_REMATCH[1]}"

    # Check if this is a new session
    if [ -f "$SESSION_FILE" ]; then
      LAST_SESSION=$(cat "$SESSION_FILE")
      [ "$SESSION_ID" = "$LAST_SESSION" ] && continue
    fi

    echo "$SESSION_ID" >"$SESSION_FILE"
    echo "$(date): New RDP session u${SESSION_ID} (NumLockState)" >>/tmp/rdp-monitor.log
    sleep 2
    /home/christopher/.local/bin/fix-rdp.py
  fi
done
