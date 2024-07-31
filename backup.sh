#!/bin/bash

# Define what to back up
SOURCE_DIR="<BACK THIS UP>"
DEST_DIR="<TO THIS LOCATION>"
DATE=$(date +%Y%m%d)

# Day of the week (1-7, 1 is Monday)
WEEKDAY=$(date +%u)

# Week of the month (1-5)
WEEK_OF_MONTH=$((($(date +%-d)-1)/7+1)) 

# Ensure destination directory exists
mkdir -p "$DEST_DIR"

# Create compressed archive
tar --warning=no-file-changed -czf "$DEST_DIR/backup-$DATE.tar.gz" -C "$SOURCE_DIR" .

# Retain the last 7 daily backups
find "$DEST_DIR" -type f -name 'backup-*.tar.gz' -mtime +7 -exec rm {} \;

# Keep a weekly backup (Sunday) for the last 4 weeks
if [ "$WEEKDAY" -eq 7 ]; then
    find "$DEST_DIR" -type f -name 'weekly-*.tar.gz' -mtime +28 -exec rm {} \;
    cp "$DEST_DIR/backup-$DATE.tar.gz" "$DEST_DIR/weekly-$DATE.tar.gz"
fi

# Keep a monthly backup for the last year
if [ "$WEEK_OF_MONTH" -eq 1 ] && [ "$WEEKDAY" -eq 7 ]; then
    find "$DEST_DIR" -type f -name 'monthly-*.tar.gz' -mtime +365 -exec rm {} \;
    cp "$DEST_DIR/backup-$DATE.tar.gz" "$DEST_DIR/monthly-$DATE.tar.gz"
fi
