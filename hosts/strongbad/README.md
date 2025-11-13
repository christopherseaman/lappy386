
# Containers

## Set up Ubuntu container

1. Install Linux env from Settings
2. Start `crosh`: (ctrl + alt + t)
3. Open management console: `vmc start termina`
4. Change image repository: `lxc remote set-url images https://images.lxd.canonical.com/`
5. Remove "penguin" container:
    1. `lxc stop penguin`
    2. `lxc delete penguin`
6. Install Ubuntu: `lxc launch ubuntu:XX.YY penguin`
7. Initial maintenance as `root`: `lxc exec penguin -- bash`

```bash
apt update
apt upgrade
apt install binutils

# Add Crostini Sources
echo "deb https://storage.googleapis.com/cros-packages bookworm main" > /etc/apt/sources.list.d/cros.list
if [ -f /dev/.cros_milestone ]; then sudo sed -i "s?packages?packages/$(cat /dev/.cros_milestone)?" /etc/apt/sources.list.d/cros.list; fi
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 78BD65473CB3BD13
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4EB27DB2A3B88B8B
apt update
```

## Modify `cros-ui-config` for Compatibilty

```bash
#!/bin/bash

# Download the package
apt download cros-ui-config 2>/dev/null

# Find all matching deb files
DEB_FILES=(cros-ui-config_*.deb)

# Check how many matches
if [ ${#DEB_FILES[@]} -eq 0 ] || [ ! -f "${DEB_FILES[0]}" ]; then
    echo "Error: Failed to download or find cros-ui-config package"
    exit 1
elif [ ${#DEB_FILES[@]} -gt 1 ]; then
    echo "Error: Multiple cros-ui-config packages found:"
    printf ' - %s\n' "${DEB_FILES[@]}"
    echo "Please remove old versions and try again"
    exit 1
fi

DEB_FILE="${DEB_FILES[0]}"
echo "Processing: $DEB_FILE"

# Extract, modify, and repack
ar x "$DEB_FILE" data.tar.gz
gunzip data.tar.gz
tar f data.tar --delete etc/gtk-3.0/settings.ini
gzip data.tar
ar r "$DEB_FILE" data.tar.gz
rm -rf data.tar.gz

echo "Modified: $DEB_FILE"
```

## Change User to `christopher`

```bash
#!/bin/bash
# Run as root to rename ubuntu user to christopher

set -e  # Exit on any error

OLD_USER="ubuntu"
NEW_USER="christopher"
NEW_HOME="/home/$NEW_USER"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Kill all processes owned by the user
echo "Killing processes owned by $OLD_USER..."
pkill -u $OLD_USER || true

# Rename user and move home directory
echo "Renaming user and moving home directory..."
usermod -l $NEW_USER -d $NEW_HOME -m $OLD_USER

# Rename primary group
echo "Renaming group..."
groupmod -n $NEW_USER $OLD_USER

# Update ownership (in case of any missed files)
chown -R $NEW_USER:$NEW_USER $NEW_HOME

echo "Done! User renamed from $OLD_USER to $NEW_USER"
echo "Home directory moved to $NEW_HOME"
```