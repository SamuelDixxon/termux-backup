#!/bin/bash
# Description: Logs comprehensive battery status from termux-battery-status 
#              to a detailed CSV file at regular intervals.

# --- Configuration ---
LOG_FILE="$HOME/battery_status_log.txt"
INTERVAL=1200 # 20 minutes in seconds.

# --- Initial Setup & Prerequisites Check ---
if ! command -v jq &> /dev/null
then
    echo "ERROR: 'jq' is not installed. Please run 'pkg install jq' and restart the script."
    echo "$(date '+%Y-%m-%d %H:%M:%S'),PREREQUISITE_ERROR,NA,NA,NA,NA,NA,NA,NA" >> "$LOG_FILE" 2>/dev/null
    exit 1
fi

# Initializing the log file with a header if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    echo "--------------------------------------------------------------------------" >> "$LOG_FILE"
    echo "Monitor Start: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "--------------------------------------------------------------------------" >> "$LOG_FILE"
    # COMPREHENSIVE CSV Header Row, including ALL relevant JSON keys
    echo "Timestamp,Health,Status,Plugged,Percentage,Current_uA,Temperature_C,Voltage_mV,Technology" >> "$LOG_FILE"
    echo "Created new log file: $LOG_FILE"
else
    echo "Appending to existing log file: $LOG_FILE"
fi

echo "Starting comprehensive CSV battery monitor. Logging to $LOG_FILE every $((INTERVAL / 60)) minutes."

# --- Logging Function ---
log_battery_status() {
    # Get current date and time
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Get battery status JSON
    STATUS_JSON=$(termux-battery-status)
    
    if [ $? -eq 0 ]; then
        # Extract ALL fields using jq for complete data capture
        HEALTH=$(echo "$STATUS_JSON" | jq -r '.health')
        STATUS=$(echo "$STATUS_JSON" | jq -r '.status')
        PLUGGED=$(echo "$STATUS_JSON" | jq -r '.plugged')
        PERCENTAGE=$(echo "$STATUS_JSON" | jq -r '.percentage')
        CURRENT=$(echo "$STATUS_JSON" | jq -r '.current')
        TEMPERATURE=$(echo "$STATUS_JSON" | jq -r '.temperature')
        VOLTAGE=$(echo "$STATUS_JSON" | jq -r '.voltage')
        TECHNOLOGY=$(echo "$STATUS_JSON" | jq -r '.technology')

        # Create the comprehensive CSV log entry
        LOG_ENTRY="$TIMESTAMP,$HEALTH,$STATUS,$PLUGGED,$PERCENTAGE,$CURRENT,$TEMPERATURE,$VOLTAGE,$TECHNOLOGY"
        
        # Append to the log file
        echo "$LOG_ENTRY" >> "$LOG_FILE"
        
        # Confirmation message (sent to STDOUT)
        # Note: Current is negative when discharging (consuming power)
        echo "Logged: ${PERCENTAGE}% (${STATUS}) | Current: ${CURRENT} uA | Time: $TIMESTAMP"
    else
        # Log API error with NA values
        echo "$TIMESTAMP,API_ERROR,NA,NA,NA,NA,NA,NA,NA" >> "$LOG_FILE"
        # Print error message to console (STDERR)
        >&2 echo "FATAL ERROR: termux-battery-status API call failed at $TIMESTAMP."
    fi
}

# --- Main Execution Loop ---
while true; do
    log_battery_status
    
    # Wait for the defined interval before the next check
    sleep "$INTERVAL"
done