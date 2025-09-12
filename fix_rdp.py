#!/usr/bin/env python3
import dbus
import time

def fix_rdp_displays():
    bus = dbus.SessionBus()
    display_config = bus.get_object(
        'org.gnome.Mutter.DisplayConfig',
        '/org/gnome/Mutter/DisplayConfig'
    )
    
    # Get current state
    current_state = display_config.GetCurrentState(
        dbus_interface='org.gnome.Mutter.DisplayConfig'
    )
    
    serial = current_state[0]
    monitors = current_state[1]
    logical_monitors = current_state[2]
    
    # Find Meta display
    meta_display = None
    for monitor in monitors:
        if monitor[0][0].startswith('Meta-'):
            meta_display = monitor
            print(f"Found RDP display: {monitor[0][0]}")
            break
    
    if meta_display:
        connector = meta_display[0][0]
        modes = meta_display[1]
        
        # Find desired mode
        selected_mode = None
        for mode in modes:
            if '1920x1080' in mode[0]:
                selected_mode = mode[0]
                break
        if not selected_mode and modes:
            selected_mode = modes[0][0]
        
        # Set your desired scale here
        # 1.0 = 100%, 1.25 = 125%, 1.5 = 150%, 2.0 = 200%
        SCALE = 2.0  # Change this to your preferred zoom level
        
        new_logical_monitors = [(
            0,      # x
            0,      # y
            SCALE,  # scale (display zoom) - set this!
            0,      # transform
            True,   # primary
            [(connector, selected_mode, {})],
        )]
        
        try:
            display_config.ApplyMonitorsConfig(
                serial,
                2,  # persistent
                new_logical_monitors,
                {},
                dbus_interface='org.gnome.Mutter.DisplayConfig'
            )
            print(f"Configuration applied - mode {selected_mode}, scale {SCALE}")
        except Exception as e:
            print(f"Failed: {e}")

if __name__ == "__main__":
    # time.sleep(3)
    fix_rdp_displays()
