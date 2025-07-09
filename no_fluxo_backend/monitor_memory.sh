#!/bin/bash

# Memory monitoring script for start_and_monitor.py
SCRIPT_NAME="start_and_monitor.py"
LOG_FILE="memory_monitor.log"

echo "Starting memory monitoring for $SCRIPT_NAME..."
echo "Logging to $LOG_FILE"
echo "Press Ctrl+C to stop"

# Function to get memory usage
get_memory() {
    ps aux | grep "$SCRIPT_NAME" | grep -v grep | awk '{print $6/1024}'
}

# Function to get system memory
get_system_memory() {
    free | grep "Mem:" | awk '{printf "%.1f", ($3/$2)*100}'
}

# Header
echo "Timestamp,Script_Memory_MB,System_Memory_%" > "$LOG_FILE"

# Monitor loop
while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    SCRIPT_MEM=$(get_memory)
    SYSTEM_MEM=$(get_system_memory)
    
    if [ ! -z "$SCRIPT_MEM" ]; then
        echo "$TIMESTAMP,$SCRIPT_MEM,$SYSTEM_MEM" >> "$LOG_FILE"
        echo "[$TIMESTAMP] Script: ${SCRIPT_MEM} MB | System: ${SYSTEM_MEM}%"
    else
        echo "[$TIMESTAMP] Script not running"
    fi
    
    sleep 60  # Check every minute
done 