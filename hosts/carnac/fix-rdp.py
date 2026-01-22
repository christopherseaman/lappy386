#!/usr/bin/env python3
"""
Disable the virtual headless monitor and make RDP display primary.
Run when RDP connection is detected.
"""
import dbus

def fix_rdp_displays():
    bus = dbus.SessionBus()
    display_config = bus.get_object(
        'org.gnome.Mutter.DisplayConfig',
        '/org/gnome/Mutter/DisplayConfig'
    )

    current_state = display_config.GetCurrentState(
        dbus_interface='org.gnome.Mutter.DisplayConfig'
    )

    serial = current_state[0]
    monitors = current_state[1]

    # Find the RDP (Meta-*) display
    rdp_monitor = None
    for monitor in monitors:
        connector = monitor[0][0]
        if connector.startswith('Meta-'):
            rdp_monitor = monitor
            print(f"Found RDP display: {connector}")
            break

    if not rdp_monitor:
        print("No RDP display found")
        return

    connector = rdp_monitor[0][0]
    modes = rdp_monitor[1]

    # Use the first available mode
    if not modes:
        print("No modes available")
        return

    selected_mode = modes[0][0]
    print(f"Using mode: {selected_mode}")

    # Configure ONLY the RDP display as primary (disables Virtual-1)
    new_logical_monitors = [(
        0,      # x
        0,      # y
        1.0,    # scale
        0,      # transform
        True,   # primary
        [(connector, selected_mode, {})],
    )]

    try:
        display_config.ApplyMonitorsConfig(
            serial,
            1,  # temporary - no prompt, reverts on logout
            new_logical_monitors,
            {},
            dbus_interface='org.gnome.Mutter.DisplayConfig'
        )
        print(f"Success: {connector} is now the only display")
    except Exception as e:
        print(f"Failed: {e}")

if __name__ == "__main__":
    fix_rdp_displays()
