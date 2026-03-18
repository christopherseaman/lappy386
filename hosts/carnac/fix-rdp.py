#!/usr/bin/env python3
"""
Disable the virtual headless monitor and make RDP display primary.
Run when RDP connection is detected.
"""
import dbus
import fcntl
import os
import sys
import time

IFACE = 'org.gnome.Mutter.DisplayConfig'
LOCKFILE = '/tmp/fix-rdp.lock'

def get_state():
    bus = dbus.SessionBus()
    obj = bus.get_object(IFACE, '/org/gnome/Mutter/DisplayConfig')
    state = obj.GetCurrentState(dbus_interface=IFACE)
    return obj, state[0], state[1], state[2]

def fix_rdp_displays():
    obj, serial, monitors, logical_monitors = get_state()

    rdp = None
    others = []
    for m in monitors:
        conn = m[0][0]
        if conn.startswith('Meta-'):
            rdp = m
        else:
            others.append(m)

    if not rdp:
        print("No RDP display found")
        return

    connector = rdp[0][0]
    modes = rdp[1]
    if not modes:
        print("No modes available")
        return

    # Check if RDP is already the only logical monitor
    if len(logical_monitors) == 1:
        lm_connectors = [mon[0] for mon in logical_monitors[0][5]]
        if lm_connectors == [connector]:
            print(f"{connector} is already the only display")
            return

    selected_mode = modes[0][0]
    print(f"Found RDP display: {connector}")
    print(f"Using mode: {selected_mode}")
    if others:
        print(f"Disabling: {', '.join(m[0][0] for m in others)}")

    # Remove monitors.xml before reconfiguring to prevent stale mode crashes
    monitors_xml = os.path.expanduser('~/.config/monitors.xml')
    if os.path.exists(monitors_xml):
        os.remove(monitors_xml)
        print(f"Removed stale {monitors_xml}")

    new_logical_monitors = [(
        0,      # x
        0,      # y
        2.0,    # scale
        0,      # transform
        True,   # primary
        [(connector, selected_mode, {})],
    )]

    try:
        obj.ApplyMonitorsConfig(
            serial,
            1,  # method 1 = temporary, no prompt, reverts on logout
            new_logical_monitors,
            {},
            dbus_interface=IFACE,
        )
        print(f"Success: {connector} is now the only display")
    except Exception as e:
        print(f"ApplyMonitorsConfig failed: {e}")

if __name__ == "__main__":
    lock = open(LOCKFILE, 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("Another instance is running, exiting")
        sys.exit(0)
    try:
        fix_rdp_displays()
    finally:
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()
