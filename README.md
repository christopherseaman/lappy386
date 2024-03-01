# lappy386
setting up a new laptop

# Raspberry Pi 5

 - [`input-remapper`](https://github.com/sezanzeb/input-remapper): bluetooth remote config
 - DRM: widevine ARM64 only provided by Raspberry Pi OS at `/opt/WidevineCdm` 
 - `xrdp`: apt version okay, change `thinclient_drives` to `.thinclient_drives` in `/etc/xrdp/sesman.ini`
```
[Chansrv]
FuseMountName=.thinclient_drives
```


# MacMini6,2

## Auto reboot on power failure

https://www.mythic-beasts.com/support/servers/colo/macmini

/etc/rc.local
`setpci -s 0:1f.0 0xa4.b=0`

## Mute startup chime
https://wiki.archlinux.org/title/Mac#Mute_startup_chime
