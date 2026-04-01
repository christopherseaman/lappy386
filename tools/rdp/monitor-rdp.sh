#!/bin/bash

# Monitor for new RDP sessions by polling D-Bus session objects.
# Previous approach (watching for NumLockState PropertiesChanged signal) broke
# in GNOME 48 where NumLockState is deprecated and no longer emits signals.

SESSION_FILE="/tmp/last-rdp-session"
LOG="/tmp/rdp-monitor.log"
POLL_INTERVAL=3
DBUS_PATH="/org/gnome/Mutter/RemoteDesktop/Session"
DBUS_NAME="org.gnome.Mutter.RemoteDesktop"

get_sessions() {
  gdbus call -e -d "$DBUS_NAME" -o "$DBUS_PATH" \
    -m org.freedesktop.DBus.Introspectable.Introspect 2>/dev/null \
    | grep -oP 'node name="\Ku[0-9]+' || true
}

LAST_SESSION=""
if [ -f "$SESSION_FILE" ]; then
  LAST_SESSION=$(cat "$SESSION_FILE")
fi

while true; do
  CURRENT_SESSIONS=$(get_sessions)
  for SESSION_ID in $CURRENT_SESSIONS; do
    if [ "$SESSION_ID" != "$LAST_SESSION" ]; then
      LAST_SESSION="$SESSION_ID"
      echo "$SESSION_ID" >"$SESSION_FILE"
      echo "$(date): New RDP session ${SESSION_ID}" >>"$LOG"
      sleep 2
      /home/christopher/.local/bin/fix-rdp.py
    fi
  done
  sleep "$POLL_INTERVAL"
done
